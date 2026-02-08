# frozen_string_literal: true

module Smolagents
  module Routing
    # Evaluates models for tool routing capability.
    #
    # Tests models against a standard set of tool-calling scenarios
    # and records accuracy, latency, and failure modes.
    #
    # @example Evaluating all available models
    #   evaluator = ModelEvaluator.new(base_url: "http://localhost:1234/v1")
    #   results = evaluator.evaluate_all
    #   evaluator.print_report(results)
    #
    class ModelEvaluator
      # Test case for evaluation.
      TestCase = Data.define(:name, :task, :expected_tool, :expected_args_keys) do
        def matches?(tool_call)
          return false unless tool_call
          return false unless tool_call.name == expected_tool

          expected_args_keys.all? { |k| tool_call.arguments.key?(k.to_s) }
        end
      end

      # Result of a single test.
      TestResult = Data.define(:test_case, :model_id, :success, :tool_call, :latency_ms, :error) do
        def passed? = success
        def failed? = !success
      end

      # Aggregate results for a model.
      ModelResult = Data.define(:model_id, :test_results, :total_latency_ms) do
        def pass_count = test_results.count(&:passed?)
        def fail_count = test_results.count(&:failed?)
        def accuracy = test_results.empty? ? 0.0 : pass_count.to_f / test_results.size
        def avg_latency_ms = test_results.empty? ? 0.0 : total_latency_ms / test_results.size
        def error_types = test_results.select(&:error).map(&:error).map(&:class).uniq
      end

      # Standard test cases covering common patterns.
      STANDARD_TEST_CASES = [
        TestCase.new(
          name: "simple_search",
          task: "Search for Ruby programming tutorials",
          expected_tool: "search",
          expected_args_keys: [:query]
        ),
        TestCase.new(
          name: "calculation",
          task: "Calculate 42 times 7",
          expected_tool: "calculate",
          expected_args_keys: [:expression]
        ),
        TestCase.new(
          name: "weather_lookup",
          task: "What's the weather in Tokyo?",
          expected_tool: "get_weather",
          expected_args_keys: [:location]
        ),
        TestCase.new(
          name: "file_read",
          task: "Read the contents of config.yml",
          expected_tool: "read_file",
          expected_args_keys: [:path]
        ),
        TestCase.new(
          name: "web_fetch",
          task: "Fetch the homepage of example.com",
          expected_tool: "fetch_url",
          expected_args_keys: [:url]
        ),
        TestCase.new(
          name: "no_tool_needed",
          task: "What is 2 + 2?",
          expected_tool: nil, # Should NOT call a tool for trivial math
          expected_args_keys: []
        )
      ].freeze

      # Standard tools for testing.
      STANDARD_TOOLS = [
        { name: "search", description: "Search the web", params: { query: "string" } },
        { name: "calculate", description: "Calculate math expression", params: { expression: "string" } },
        { name: "get_weather", description: "Get weather for location", params: { location: "string" } },
        { name: "read_file", description: "Read file contents", params: { path: "string" } },
        { name: "fetch_url", description: "Fetch URL contents", params: { url: "string" } }
      ].freeze

      attr_reader :base_url, :timeout

      def initialize(base_url: "http://localhost:1234/v1", timeout: 30)
        @base_url = base_url
        @timeout = timeout
      end

      # Lists available models.
      def available_models
        uri = URI("#{base_url}/models")
        response = Net::HTTP.get(uri)
        JSON.parse(response)["data"].map { |m| m["id"] }
      rescue StandardError => e
        puts "Error listing models: #{e.message}"
        []
      end

      # Evaluates a single model.
      def evaluate_model(model_id, test_cases: STANDARD_TEST_CASES)
        results = []
        total_latency = 0.0

        test_cases.each do |test_case|
          result = run_test(model_id, test_case)
          results << result
          total_latency += result.latency_ms
        end

        ModelResult.new(model_id:, test_results: results, total_latency_ms: total_latency)
      end

      # Evaluates all available models.
      def evaluate_all(filter: nil, test_cases: STANDARD_TEST_CASES)
        models = available_models
        models = models.select { |m| m.match?(filter) } if filter

        models.map do |model_id|
          puts "Evaluating: #{model_id}..."
          evaluate_model(model_id, test_cases:)
        end
      end

      # Prints a formatted report.
      def print_report(results)
        puts "\n#{'=' * 80}"
        puts "MODEL EVALUATION REPORT"
        puts "=" * 80

        results.sort_by { |r| -r.accuracy }.each do |result|
          puts "\n#{result.model_id}"
          puts "-" * result.model_id.length
          puts "  Accuracy:    #{(result.accuracy * 100).round(1)}% (#{result.pass_count}/#{result.test_results.size})"
          puts "  Avg Latency: #{result.avg_latency_ms.round(1)}ms"
          puts "  Errors:      #{result.error_types.join(', ')}" if result.error_types.any?

          result.test_results.select(&:failed?).each do |tr|
            puts "    FAIL: #{tr.test_case.name}"
            puts "      Expected: #{tr.test_case.expected_tool}"
            puts "      Got: #{tr.tool_call&.name || 'nil'}"
          end
        end

        puts "\n#{'=' * 80}"
        puts "SUMMARY"
        puts "=" * 80

        best = results.max_by(&:accuracy)
        fastest = results.min_by(&:avg_latency_ms)

        puts "Best accuracy:  #{best.model_id} (#{(best.accuracy * 100).round(1)}%)" if best
        puts "Fastest:        #{fastest.model_id} (#{fastest.avg_latency_ms.round(1)}ms)" if fastest
      end

      private

      def run_test(model_id, test_case)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        tool_call = nil
        error = nil

        begin
          response = call_model(model_id, test_case.task)
          tool_call = extract_tool_call(response)
        rescue StandardError => e
          error = e
        end

        latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        success = test_case.matches?(tool_call)

        # Special case: if no tool expected and none returned, that's success
        success = tool_call.nil? if test_case.expected_tool.nil? && error.nil?

        TestResult.new(
          test_case:,
          model_id:,
          success:,
          tool_call:,
          latency_ms:,
          error:
        )
      end

      def call_model(model_id, task)
        uri = URI("#{base_url}/chat/completions")
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"

        request.body = JSON.generate({
          model: model_id,
          messages: [
            { role: "system", content: "You are a helpful assistant." },
            { role: "user", content: task }
          ],
          tools: build_tools,
          tool_choice: "auto",
          max_tokens: 150,
          temperature: 0.1
        })

        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = @timeout
        response = http.request(request)

        JSON.parse(response.body)
      end

      def extract_tool_call(response)
        tool_calls = response.dig("choices", 0, "message", "tool_calls")
        return nil unless tool_calls&.any?

        call = tool_calls.first
        Types::ToolCall.new(
          name: call.dig("function", "name"),
          arguments: JSON.parse(call.dig("function", "arguments") || "{}"),
          id: call["id"]
        )
      rescue JSON::ParserError
        nil
      end

      def build_tools
        STANDARD_TOOLS.map do |tool|
          {
            type: "function",
            function: {
              name: tool[:name],
              description: tool[:description],
              parameters: {
                type: "object",
                properties: tool[:params].transform_values { |t| { type: t } },
                required: tool[:params].keys.map(&:to_s)
              }
            }
          }
        end
      end
    end
  end
end
