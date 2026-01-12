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
          reset_state if reset
          @task_images = images
          stream ? run_stream(task:, additional_prompting:, images:) : run_sync(task:, additional_prompting:, images:)
        end
      end

      def register_callback(event, callable = nil, &)
        validate_callback_event!(event)
        super
      end

      def write_memory_to_messages(summary_mode: false) = @memory.to_messages(summary_mode:)

      private

      def reset_state
        @memory.reset
        @state = {}
      end

      def run_sync(task:, additional_prompting: nil, images: nil)
        prepare_task(task, additional_prompting:, images:)
        context = RunContext.start

        until context.exceeded?(@max_steps)
          current_step, context = execute_step_with_monitoring(task, context)
          return finalize(:success, current_step.action_output, context) if current_step.is_final_answer

          context = after_step(task, current_step, context)
        end

        finalize(:max_steps_reached, nil, context)
      rescue StandardError => e
        finalize_error(e, context)
      end

      def run_stream(task:, additional_prompting: nil, images: nil)
        Enumerator.new do |yielder|
          prepare_task(task, additional_prompting:, images:)
          step_number = 1

          while step_number <= @max_steps
            trigger_callbacks(:step_start, step_number:)
            current_step = step(task, step_number:)
            @memory.add_step(current_step)

            yielder << current_step
            trigger_callbacks(:step_complete, step: current_step, monitor: nil)
            break if current_step.is_final_answer

            step_number += 1
          end

          trigger_callbacks(:max_steps_reached, step_count: step_number - 1) if step_number > @max_steps
        end
      end

      def prepare_task(task, additional_prompting: nil, images: nil)
        @memory.add_task(task, additional_prompting:, task_images: images)
      end

      def execute_step_with_monitoring(task, context)
        @logger.step_start(context.step_number)
        trigger_callbacks(:step_start, step_number: context.step_number)

        current_step = monitor_and_instrument_step(task, context)
        @logger.step_complete(context.step_number, duration: step_monitors["step_#{context.step_number}"].duration)

        [current_step, context.add_tokens(current_step.token_usage)]
      end

      def monitor_and_instrument_step(task, context)
        current_step = nil
        monitor_step("step_#{context.step_number}") do
          Instrumentation.instrument("smolagents.agent.step", step_number: context.step_number, agent_class: self.class.name) do
            current_step = step(task, step_number: context.step_number)
            @memory.add_step(current_step)
            current_step
          end
        end
        trigger_callbacks(:step_complete, step: current_step, monitor: step_monitors["step_#{context.step_number}"])
        current_step
      end

      def after_step(task, current_step, context)
        execute_planning_step_if_needed(task, current_step, context.step_number) do |usage|
          context = context.add_tokens(usage)
        end
        context.advance
      end

      def finalize(outcome, output, context)
        finished = context.finish
        trigger_callbacks(:max_steps_reached, step_count: finished.steps_completed) if outcome == :max_steps_reached
        @logger.warn("Max steps reached", max_steps: @max_steps) if outcome == :max_steps_reached
        build_result(outcome, output, finished)
      end

      def finalize_error(error, context)
        @logger.error("Agent error", error: error.message, backtrace: error.backtrace.first(3))
        build_result(:error, nil, context.finish)
      end

      def build_result(outcome, output, context)
        RunResult.new(output:, state: outcome, steps: @memory.steps.dup, token_usage: context.total_tokens, timing: context.timing).tap do |result|
          trigger_callbacks(:task_complete, result:) if outcome == :success
        end
      end

      def execute_planning_step_if_needed(_task, _current_step, _step_number); end
    end
  end
end
