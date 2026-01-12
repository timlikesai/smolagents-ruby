module Smolagents
  module Concerns
    module ReActLoop
      def self.included(base)
        base.include(Callbackable)
        base.attr_reader :tools, :model, :memory, :max_steps, :logger, :state
        base.allowed_callbacks :step_start, :step_complete, :task_complete, :max_steps_reached,
                               :on_step_complete, :on_step_error, :on_tokens_tracked
      end

      def setup_agent(tools:, model:, max_steps: nil, planning_interval: nil, managed_agents: nil, custom_instructions: nil, logger: nil, **_opts)
        config = Smolagents.configuration
        @model = model
        @max_steps = max_steps || config.max_steps
        @logger = logger || AgentLogger.new(output: $stderr, level: AgentLogger::WARN)
        @state = {}
        @planning_interval = planning_interval
        @current_plan = nil
        @custom_instructions = PromptSanitizer.sanitize(custom_instructions || config.custom_instructions, logger: @logger)

        setup_managed_agents(managed_agents)
        @tools = tools_with_managed_agents(tools)
        @memory = AgentMemory.new(system_prompt)
      end

      def run(task, stream: false, reset: true, images: nil, additional_prompting: nil)
        Instrumentation.instrument("smolagents.agent.run", task: task, agent_class: self.class.name) do
          if reset
            @memory.reset
            @state = {}
          end
          @task_images = images
          if stream
            run_stream(task: task, additional_prompting: additional_prompting,
                       images: images)
          else
            run_sync(task: task, additional_prompting: additional_prompting, images: images)
          end
        end
      end

      def register_callback(event, callable = nil, &)
        validate_callback_event!(event)
        super
      end

      def write_memory_to_messages(summary_mode: false) = @memory.to_messages(summary_mode: summary_mode)

      private

      def run_sync(task:, additional_prompting: nil, images: nil)
        @memory.add_task(task, additional_prompting: additional_prompting, task_images: images)
        run_context = initialize_run_context

        while run_context[:step_number] <= @max_steps
          result = execute_agent_step(task, run_context)
          return result if result
        end

        handle_max_steps_reached(run_context)
      rescue StandardError => e
        handle_run_error(e, run_context)
      end

      def initialize_run_context
        { step_number: 1, total_tokens: TokenUsage.new(input_tokens: 0, output_tokens: 0), timing: Timing.start_now }
      end

      def execute_agent_step(task, context)
        step_number = context[:step_number]
        @logger.step_start(step_number)
        trigger_callbacks(:step_start, step_number: step_number)

        current_step = execute_monitored_step(task, step_number, context)
        log_step_completion(step_number)

        if current_step.is_final_answer
          build_run_result(current_step.action_output, :success, context[:total_tokens], context[:timing].stop)
        else
          execute_planning_step_if_needed(task, current_step, step_number) { |usage| context[:total_tokens] = accumulate_tokens(context[:total_tokens], usage) }
          context[:step_number] += 1
          nil
        end
      end

      def execute_monitored_step(task, step_number, context)
        current_step = nil
        monitor_step("step_#{step_number}") do
          Instrumentation.instrument("smolagents.agent.step", step_number: step_number, agent_class: self.class.name) do
            current_step = step(task, step_number: step_number)
            @memory.add_step(current_step)
            context[:total_tokens] = accumulate_tokens(context[:total_tokens], current_step.token_usage)
            current_step
          end
        end
        trigger_callbacks(:step_complete, step: current_step, monitor: step_monitors["step_#{step_number}"])
        current_step
      end

      def log_step_completion(step_number)
        @logger.step_complete(step_number, duration: step_monitors["step_#{step_number}"].duration)
      end

      def handle_max_steps_reached(context)
        trigger_callbacks(:max_steps_reached, step_count: context[:step_number] - 1)
        @logger.warn("Max steps reached", max_steps: @max_steps)
        build_run_result(nil, :max_steps_reached, context[:total_tokens], context[:timing].stop)
      end

      def handle_run_error(err, context)
        @logger.error("Agent error", error: err.message, backtrace: err.backtrace.first(3))
        build_run_result(nil, :error, context[:total_tokens], context[:timing].stop)
      end

      def run_stream(task:, additional_prompting: nil, images: nil)
        Enumerator.new do |yielder|
          @memory.add_task(task, additional_prompting: additional_prompting, task_images: images)
          step_number = 1

          while step_number <= @max_steps
            trigger_callbacks(:step_start, step_number: step_number)
            current_step = step(task, step_number: step_number)
            @memory.add_step(current_step)

            yielder << current_step
            trigger_callbacks(:step_complete, step: current_step, monitor: nil)
            break if current_step.is_final_answer

            step_number += 1
          end

          trigger_callbacks(:max_steps_reached, step_count: step_number - 1) if step_number > @max_steps
        end
      end

      def accumulate_tokens(total, usage)
        usage ? TokenUsage.new(input_tokens: total.input_tokens + usage.input_tokens, output_tokens: total.output_tokens + usage.output_tokens) : total
      end

      def build_run_result(output, state, tokens, timing)
        RunResult.new(output: output, state: state, steps: @memory.steps.dup, token_usage: tokens, timing: timing).tap do |result|
          trigger_callbacks(:task_complete, result: result) if state == :success
        end
      end

      def execute_planning_step_if_needed(_task, _current_step, _step_number); end
    end
  end
end
