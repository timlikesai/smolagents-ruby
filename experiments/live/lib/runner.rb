# Experiment Runner
#
# Executes experiments and captures all interactions.

require "timeout"
require "securerandom"
require_relative "traced_model"

module LiveExperiments
  class Runner
    def initialize(experiment, logger:, capture_traces: true)
      @experiment = experiment
      @logger = logger
      @capture_traces = capture_traces
      @results = []
    end

    def execute
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @logger.experiment_started(@experiment.name, @experiment.settings)

      puts "\n#{"=" * 60}"
      puts "EXPERIMENT: #{@experiment.name}"
      puts "Models: #{@experiment.model_configs.keys.join(", ")}"
      puts "Tasks: #{@experiment.task_list.size}"
      puts "Iterations: #{@experiment.settings[:iterations]}"
      puts "Total runs: #{@experiment.total_runs}"
      puts "=" * 60

      @experiment.model_configs.each do |model_name, factory|
        run_model(model_name, factory)
      end

      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      @logger.experiment_completed(@experiment.name, duration)

      puts "\n#{"=" * 60}"
      puts "EXPERIMENT COMPLETE"
      puts "Duration: #{duration.round(1)}s"
      puts "Stats: #{@logger.stats}"
      puts "Logs: #{@logger.run_dir}"
      puts "=" * 60

      @results
    end

    private

    def run_model(model_name, factory)
      puts "\n--- Model: #{model_name} ---"

      model = build_model(factory)
      tools = build_tools

      @experiment.settings[:iterations].times do |iteration|
        puts "  Iteration #{iteration + 1}/#{@experiment.settings[:iterations]}"

        @experiment.task_list.each_with_index do |task, task_idx|
          run_task(model_name, model, tools, task, iteration, task_idx)
        end

        checkpoint(model_name, iteration) if should_checkpoint?(iteration)
      end
    rescue StandardError => e
      @logger.error(e, context: { model: model_name })
      puts "  ERROR: #{e.class}: #{e.message}"
    end

    def build_model(factory)
      model = factory.is_a?(Proc) ? factory.call : factory
      @capture_traces ? TracedModel.new(model) : model
    end

    def build_tools
      @experiment.tool_configs.map do |config|
        case config[:type]
        when :mock
          create_mock_tool(config)
        when :inline
          create_inline_tool(config)
        when :real
          Smolagents::Tools::Registry.get(config[:name])
        end
      end.compact
    end

    def create_mock_tool(config)
      Smolagents::Tools::InlineTool.create(
        config[:name],
        config[:description],
        **config[:inputs],
        &config[:handler]
      )
    end

    def create_inline_tool(config)
      Smolagents::Tools::InlineTool.create(
        config[:name],
        config[:description],
        **config[:inputs],
        &config[:handler]
      )
    end

    def run_task(model_name, model, tools, task, iteration, task_idx)
      task_id = "#{model_name}_#{iteration}_#{task_idx}"

      @logger.with_trace(task_id) do
        @logger.event(:task_start, {
          model: model_name,
          iteration:,
          task_idx:,
          prompt: task[:prompt],
          tags: task[:tags],
          difficulty: task[:difficulty]
        })

        print "    Task #{task_idx + 1}: "

        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          result = execute_task(model, tools, task)
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round
          passed = validate_result(result, task)

          # Drain and log LLM traces if model supports it
          log_model_traces(model, task_id)

          @logger.event(:task_complete, {
            model: model_name,
            iteration:,
            task_idx:,
            result: result.output.to_s[0..500],
            state: result.state,
            steps: result.steps.size,
            duration_ms:,
            passed:
          })

          @results << {
            model: model_name,
            task: task[:prompt][0..50],
            passed:,
            duration_ms:,
            state: result.state
          }

          puts passed ? "PASS (#{duration_ms}ms)" : "FAIL (#{duration_ms}ms)"

        rescue Timeout::Error
          log_model_traces(model, task_id) if model.respond_to?(:drain_traces)
          @logger.event(:task_timeout, { model: model_name, iteration:, task_idx: })
          puts "TIMEOUT"

        rescue StandardError => e
          log_model_traces(model, task_id) if model.respond_to?(:drain_traces)
          @logger.error(e, context: { model: model_name, task_idx:, iteration: })
          puts "ERROR: #{e.message[0..50]}"
        end
      end
    end

    def log_model_traces(model, task_id)
      return unless model.respond_to?(:drain_traces)

      traces = model.drain_traces
      traces.each do |trace|
        @logger.trace({
          task_id: task_id,
          llm_prompt: trace[:prompt],
          llm_response: trace[:response]
        })
      end
    end

    def execute_task(model, tools, task)
      agent = build_agent(model, tools)
      subscribe_to_events(agent)

      Timeout.timeout(@experiment.settings[:timeout]) do
        agent.run(task[:prompt])
      end
    end

    def build_agent(model, tools)
      builder = Smolagents.agent
                          .model { model }
                          .max_steps(@experiment.settings[:max_steps])

      tools.each { |tool| builder = builder.tools(tool) }
      builder.build
    end

    def subscribe_to_events(agent)
      agent.on(:model_generate_completed) do |event|
        @logger.trace({
          type: :llm_call,
          model_id: event.model_id,
          input_tokens: event.token_usage&.input_tokens,
          output_tokens: event.token_usage&.output_tokens,
          duration_ms: event.duration_ms
        })

        @logger.event(:llm_call, {
          input_tokens: event.token_usage&.input_tokens || 0,
          output_tokens: event.token_usage&.output_tokens || 0
        })
      end

      agent.on(:tool_execution_completed) do |event|
        @logger.trace({
          type: :tool_call,
          tool_name: event.tool_name,
          duration_ms: event.duration_ms
        })
      end

      agent.on(:error_occurred) do |event|
        @logger.event(:agent_error, {
          error_class: event.error_class,
          message: event.error_message,
          recoverable: event.recoverable
        })
      end
    end

    def validate_result(result, task)
      return false unless result.state == :success

      output = result.output.to_s

      if task[:validate]
        task[:validate].call(output)
      elsif task[:expect]
        output.downcase.include?(task[:expect].to_s.downcase)
      else
        output.length > 0
      end
    end

    def should_checkpoint?(iteration)
      (iteration + 1) % @experiment.settings[:checkpoint_every] == 0
    end

    def checkpoint(model_name, iteration)
      @logger.event(:checkpoint, {
        model: model_name,
        iteration:,
        stats: @logger.stats
      })
    end
  end
end
