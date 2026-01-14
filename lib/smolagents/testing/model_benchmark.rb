module Smolagents
  module Testing
    # Tiered benchmark suite for evaluating model compatibility.
    #
    # Levels:
    #   1. Basic Response - Can the model respond at all?
    #   2. Format Compliance - Can it generate proper Ruby code blocks?
    #   3. Tool Calling - Can it call a single tool correctly?
    #   4. Multi-Step - Can it complete a 2-3 step task?
    #   5. Complex Reasoning - Can it handle multi-tool reasoning?
    #   6. Vision - Can it process images? (VLM only)
    #
    # @example Run full benchmark
    #   benchmark = ModelBenchmark.new(base_url: "http://localhost:1234/v1")
    #   summary = benchmark.run("gpt-oss-20b")
    #   puts summary.report
    #
    # @example Run with multiple attempts per test
    #   summary = benchmark.run("gpt-oss-20b", runs: 3)
    #
    # @example Run specific levels
    #   results = benchmark.run("gpt-oss-20b", levels: 1..3)
    #
    # rubocop:disable Metrics/ClassLength -- Benchmark class is cohesive
    class ModelBenchmark
      attr_reader :base_url, :logger, :registry

      def initialize(base_url: "http://localhost:1234/v1", logger: nil, registry: nil)
        @base_url = base_url
        @logger = logger || default_logger
        @registry = registry || load_registry
      end

      # Run full benchmark on a single model with optional retries.
      #
      # Progressively tests model through 6 capability levels:
      # 1. Basic Response - Can respond at all?
      # 2. Format Compliance - Ruby code blocks?
      # 3. Tool Calling - Single tool call?
      # 4. Multi-Step - Complete 2-3 step tasks?
      # 5. Complex Reasoning - Multi-tool reasoning?
      # 6. Vision - Process images (VLM only)?
      #
      # Tests fail fast at each level - if a test fails, higher levels are not attempted.
      #
      # @param model_id [String] Model ID to test
      # @param levels [Range] Test levels to run (default 1..5)
      # @param timeout [Integer] Timeout per test in seconds (default 60)
      # @param runs [Integer] Number of runs per test for reliability (default 1, use 3+ for confidence)
      # @param pass_threshold [Float] Fraction of runs that must pass (default 0.5)
      # @return [BenchmarkSummary] Aggregated results for the model
      #
      # @example Single run benchmark
      #   benchmark = ModelBenchmark.new
      #   summary = benchmark.run("gpt-oss-20b")
      #   puts summary.report
      #
      # @example Multiple runs for reliability
      #   summary = benchmark.run("gpt-oss-20b", runs: 3, pass_threshold: 0.67)
      #   # Each test runs 3 times; must pass 2+ times to count as success
      #
      # @example Specific level range
      #   summary = benchmark.run("gpt-oss-20b", levels: 1..3)
      def run(model_id, levels: 1..5, timeout: 60, runs: 1, pass_threshold: 0.5)
        results = []
        capabilities = @registry[model_id]

        levels.each do |level|
          tests = tests_for_level(level)
          tests.each do |test|
            result = run_test_with_retries(model_id, test, timeout:, runs:, pass_threshold:)
            results << result
            log_result(result)

            # Stop on first failure at this level (fail fast)
            break unless result.passed?
          end

          # Don't continue to higher levels if this level failed
          break unless results.last&.passed?
        end

        BenchmarkSummary.from_results(model_id, results, capabilities:)
      end

      # Run a single test multiple times and aggregate results.
      def run_test_with_retries(model_id, test, timeout:, runs:, pass_threshold:)
        return run_test(model_id, test, timeout:) if runs == 1

        attempts = []
        runs.times do |i|
          @logger.debug("  Run #{i + 1}/#{runs} for #{test[:name]}...")
          attempts << run_test(model_id, test, timeout:)
        end

        aggregate_results(model_id, test, attempts, pass_threshold)
      end

      # Aggregate multiple test attempts into a single result.
      def aggregate_results(model_id, test, attempts, pass_threshold)
        stats = compute_attempt_stats(attempts, pass_threshold)
        build_aggregate_result(model_id, test, stats)
      end

      def compute_attempt_stats(attempts, pass_threshold)
        passed_count = attempts.count(&:passed?)
        pass_rate = passed_count.to_f / attempts.size
        passed = pass_rate >= pass_threshold
        representative = passed ? attempts.select(&:passed?).min_by(&:duration) : attempts.max_by(&:duration)

        { passed:, passed_count:, pass_rate:, representative:,
          tokens: attempts.filter_map(&:tokens).sum(TokenUsage.zero),
          avg_duration: attempts.sum(&:duration) / attempts.size,
          metadata: { runs: attempts.size, passed_runs: passed_count, pass_rate: pass_rate.round(3),
                      durations: attempts.map { |a| a.duration.round(3) } },
          errors: attempts.reject(&:passed?).map(&:error).uniq.join("; ") }
      end

      def build_aggregate_result(model_id, test, stats)
        common = { model_id:, test_name: test[:name], level: test[:level], duration: stats[:avg_duration],
                   tokens: stats[:tokens], steps: stats[:representative].steps, metadata: stats[:metadata] }
        return BenchmarkResult.success(**common) if stats[:passed]

        BenchmarkResult.failure(**common, error: "#{stats[:passed_count]}/#{stats[:metadata][:runs]} passed: #{stats[:errors]}")
      end

      # Run benchmark on all models in a registry.
      #
      # Automatically adjusts test levels based on model capabilities
      # (e.g., vision models run level 6, non-vision models run up to level 5).
      # Respects model's vision capability when determining max test level.
      #
      # @param registry [ModelRegistry] Registry of models to test (default: internal registry)
      # @param levels [Range] Test levels to run (default 1..5)
      # @return [Hash{String => BenchmarkSummary}] Hash mapping model IDs to their summaries
      #
      # @example Benchmark all models
      #   registry = ModelRegistry.from_lm_studio
      #   benchmark = ModelBenchmark.new
      #   summaries = benchmark.run_all_models(registry)
      #
      #   summaries.each do |id, summary|
      #     puts "#{id}: #{summary.level_badge}"
      #   end
      #
      # @example Use internal registry
      #   benchmark = ModelBenchmark.new(base_url: "http://localhost:1234/v1")
      #   summaries = benchmark.run_all_models
      def run_all_models(registry = @registry, levels: 1..5)
        summaries = {}

        registry.each do |caps|
          max_level = caps.vision? ? 6 : 5
          actual_levels = levels.to_a & (1..max_level).to_a

          @logger.info("Benchmarking #{caps.model_id}...")
          summaries[caps.model_id] = run(caps.model_id, levels: actual_levels)
        end

        summaries
      end

      private

      def tests_for_level(level)
        case level
        when 1 then [level1_basic_response]
        when 2 then [level2_code_format]
        when 3 then [level3_tool_call]
        when 4 then [level4_multi_step]
        when 5 then [level5_reasoning]
        when 6 then [level6_vision]
        else []
        end
      end

      # Level 1: Can the model respond at all?
      def level1_basic_response
        {
          name: "basic_response",
          level: 1,
          type: :chat,
          prompt: "What is 2 + 2? Reply with just the number.",
          validator: ->(response) { response.to_s.include?("4") }
        }
      end

      # Level 2: Can it generate proper Ruby code blocks?
      def level2_code_format
        {
          name: "code_format",
          level: 2,
          type: :chat,
          prompt: <<~PROMPT,
            Write Ruby code that prints "hello world".
            Put your code in a ```ruby code block.
          PROMPT
          validator: lambda { |response|
            # More lenient - accept various code block formats
            text = response.to_s
            has_code_block = text.match?(/```(?:ruby)?\s*\n/i) || text.match?(/<code>/i)
            has_hello_world = text.match?(/puts.*hello.*world/im) || text.match?(/print.*hello.*world/im)
            has_code_block && has_hello_world
          }
        }
      end

      # Level 3: Can it call a single tool correctly?
      def level3_tool_call
        {
          name: "single_tool_call",
          level: 3,
          type: :agent,
          task: "Calculate 15 * 7 using the calculate tool, then return the result with final_answer.",
          tools: [:calculator],
          max_steps: 5,
          validator: lambda { |result|
            result.success? && result.output.to_s.include?("105")
          }
        }
      end

      # Level 4: Can it complete a multi-step task?
      def level4_multi_step
        {
          name: "multi_step_task",
          level: 4,
          type: :agent,
          task: <<~TASK.strip,
            Solve this step by step:
            1. First, calculate 25 * 4 using the calculate tool
            2. Then, subtract 50 from that result using the calculate tool
            3. Return the final number with final_answer
          TASK
          tools: [:calculator],
          max_steps: 8,
          validator: lambda { |result|
            # 25*4=100, 100-50=50
            result.success? && result.output.to_s.include?("50")
          }
        }
      end

      # Level 5: Can it handle complex multi-tool reasoning?
      def level5_reasoning
        {
          name: "complex_reasoning",
          level: 5,
          type: :agent,
          task: <<~TASK.strip,
            Ruby 3.0 was released in 2020. If Ruby releases a new major version every 3 years,
            calculate when Ruby 4.0 will release (3.0 in 2020, so 4.0 = 2020 + 3 years = ?).
            Use the calculate tool to compute 2020 + 3, then return the year with final_answer.
          TASK
          tools: [:calculator],
          max_steps: 6,
          validator: lambda { |result|
            # Should arrive at 2023 (2020 + 3)
            result.success? && result.output.to_s.include?("2023")
          }
        }
      end

      # Level 6: Vision (for VLMs)
      def level6_vision
        {
          name: "vision_test",
          level: 6,
          type: :vision,
          prompt: "What color is the Ruby logo? Describe what you see.",
          image_url: "https://www.ruby-lang.org/images/header-ruby-logo.png",
          validator: lambda { |response|
            response.to_s.downcase.include?("red")
          }
        }
      end

      def run_test(model_id, test, timeout:)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        case test[:type]
        when :chat
          run_chat_test(model_id, test, timeout:)
        when :agent
          run_agent_test(model_id, test, timeout:)
        when :vision
          run_vision_test(model_id, test, timeout:)
        end
      rescue StandardError => e
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        BenchmarkResult.failure(
          model_id:,
          test_name: test[:name],
          level: test[:level],
          duration:,
          error: "#{e.class}: #{e.message}"
        )
      end

      def run_chat_test(model_id, test, timeout:)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        model = build_model(model_id, timeout:)
        response = model.generate([
                                    Types::ChatMessage.user(test[:prompt])
                                  ])

        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        passed = test[:validator].call(response.content)

        if passed
          BenchmarkResult.success(
            model_id:,
            test_name: test[:name],
            level: test[:level],
            duration:,
            tokens: response.token_usage
          )
        else
          BenchmarkResult.failure(
            model_id:,
            test_name: test[:name],
            level: test[:level],
            duration:,
            error: "Validation failed",
            tokens: response.token_usage
          )
        end
      end

      def run_agent_test(model_id, test, timeout:)
        model = build_model(model_id, timeout:)
        agent = Agents::Code.new(model:, tools: build_tools(test[:tools]), max_steps: test[:max_steps])

        timed_run(model_id, test) do
          result = agent.run(test[:task])
          error = result.max_steps? ? "Max steps reached" : "Validation failed"
          { passed: test[:validator].call(result), tokens: result.token_usage, steps: result.step_count, error: }
        end
      end

      def run_vision_test(model_id, test, timeout:)
        model = build_model(model_id, timeout:)
        message = Types::ChatMessage.user(test[:prompt], images: [test[:image_url]])

        timed_run(model_id, test) do
          response = model.generate([message])
          { passed: test[:validator].call(response.content), tokens: response.token_usage, error: "Validation failed" }
        end
      end

      def timed_run(model_id, test)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        outcome = yield
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        build_test_result(model_id, test, duration, outcome)
      end

      def build_test_result(model_id, test, duration, outcome)
        common = { model_id:, test_name: test[:name], level: test[:level], duration:, tokens: outcome[:tokens], steps: outcome[:steps] }
        outcome[:passed] ? BenchmarkResult.success(**common) : BenchmarkResult.failure(**common, error: outcome[:error])
      end

      def build_model(model_id, timeout:)
        Models::OpenAIModel.new(
          model_id:,
          api_base: @base_url,
          api_key: "not-needed",
          timeout:
        )
      end

      def build_tools(tool_symbols)
        tool_symbols.map do |sym|
          case sym
          when :calculator
            calculator_tool
          when :search
            search_tool
          else
            raise ArgumentError, "Unknown tool: #{sym}"
          end
        end
      end

      def calculator_tool
        @calculator_tool ||= Tools.define_tool(
          "calculate",
          description: "Evaluate a mathematical expression. Example: calculate(expression: '2 + 2')",
          inputs: {
            "expression" => { "type" => "string", "description" => "Math expression to evaluate" }
          },
          output_type: "number"
          # rubocop:disable Security/Eval -- Safe: only used for benchmarking with known inputs
        ) { |expression:| eval(expression).to_f }
        # rubocop:enable Security/Eval
      end

      def search_tool
        @search_tool ||= Tools::SearxngSearchTool.new(
          instance_url: ENV.fetch("SEARXNG_URL", "https://searxng.reverse-bull.ts.net")
        )
      end

      def log_result(result)
        status = result.passed? ? "PASS" : "FAIL"
        @logger.info("[#{status}] #{result.test_name} (#{result.duration.round(2)}s)")
      end

      def default_logger
        require "logger"
        Logger.new($stdout, level: Logger::INFO, progname: "benchmark")
      end

      def load_registry
        base = @base_url.sub(%r{/v1/?$}, "")
        ModelRegistry.from_lm_studio(base)
      rescue StandardError
        ModelRegistry.new({})
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
