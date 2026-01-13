module Smolagents
  module Concerns
    # Event-driven ReAct (Reason + Act) loop for agents.
    #
    # The loop operates purely through events:
    # - StepCompleted emitted after each step
    # - TaskCompleted emitted when task finishes
    # - ErrorOccurred emitted on failures
    #
    # Include Events::Consumer to subscribe to these events.
    #
    module ReActLoop
      def self.included(base)
        base.include(Events::Emitter) unless base < Events::Emitter
        base.include(Events::Consumer) unless base < Events::Consumer
        base.attr_reader :tools, :model, :memory, :max_steps, :logger, :state
      end

      # Initialize agent state and memory with tools, model, and configuration.
      #
      # Called during agent initialization to set up the internal state needed
      # for the ReAct loop. Initializes memory, loads tools, configures planning,
      # and sets up managed agent orchestration.
      #
      # @param tools [Array<Tool>] Tools available to the agent
      # @param model [Model] Language model for generation
      # @param max_steps [Integer, nil] Maximum steps before stopping (nil = use config default)
      # @param planning_interval [Integer, nil] Steps between planning updates (nil = no planning)
      # @param planning_templates [Hash, nil] Custom planning prompt templates
      # @param managed_agents [Array<Agent>, nil] Sub-agents for orchestration
      # @param custom_instructions [String, nil] Custom system instructions (nil = use config default)
      # @param logger [Logger, nil] Logger instance (nil = use default)
      # @return [void]
      #
      # @example Basic setup
      #   agent.setup_agent(
      #     tools: [search_tool, calculator_tool],
      #     model: my_model,
      #     max_steps: 10
      #   )
      #
      # @example With custom instructions and planning
      #   agent.setup_agent(
      #     tools: [search_tool],
      #     model: my_model,
      #     custom_instructions: "Be concise in responses",
      #     planning_interval: 2
      #   )
      def setup_agent(tools:, model:, max_steps: nil, planning_interval: nil, planning_templates: nil, managed_agents: nil, custom_instructions: nil, logger: nil, **_opts)
        config = Smolagents.configuration
        @model = model
        @max_steps = max_steps || config.max_steps
        @logger = logger || AgentLogger.new(output: $stderr, level: AgentLogger::WARN)
        @state = {}
        @custom_instructions = PromptSanitizer.sanitize(custom_instructions || config.custom_instructions, logger: @logger)

        # Initialize planning concern (sets @plan_context, @planning_interval, @planning_templates)
        initialize_planning(planning_interval:, planning_templates:)

        setup_managed_agents(managed_agents)
        @tools = tools_with_managed_agents(tools)
        @memory = AgentMemory.new(system_prompt)
      end

      # Execute a task with the agent.
      #
      # Runs the ReAct loop (Reason + Act), executing steps until the task
      # completes or max_steps is reached. Can return results synchronously
      # or as a stream of steps.
      #
      # Emits TaskCompleted and StepCompleted events at each stage.
      #
      # @param task [String] The task/question for the agent to solve
      # @param stream [Boolean] If true, return Enumerator of steps (false = wait for result)
      # @param reset [Boolean] If true, clear memory and state before running (default: true)
      # @param images [Array<String>, nil] Base64-encoded images to include in context
      # @param additional_prompting [String, nil] Extra instructions for this task
      # @return [RunResult] Final result with output, state, steps, and token usage (if sync)
      # @return [Enumerator<ActionStep>] Step stream yielding each action step (if stream: true)
      #
      # @example Synchronous execution
      #   result = agent.run("What is the capital of France?")
      #   puts result.output  # => "The capital of France is Paris"
      #   puts result.steps.length  # => 2
      #
      # @example Streaming execution
      #   agent.run("Find recent news", stream: true).each do |step|
      #     puts "Step #{step.step_number}: #{step.observations}"
      #   end
      #
      # @example With images
      #   result = agent.run("Describe this image", images: [base64_image])
      #
      # @example Without resetting memory (continue from previous run)
      #   result = agent.run("Now find the population", reset: false)
      def run(task, stream: false, reset: true, images: nil, additional_prompting: nil)
        Instrumentation.instrument("smolagents.agent.run", task: task, agent_class: self.class.name) do
          reset_state if reset
          @task_images = images
          stream ? run_stream(task:, additional_prompting:, images:) : run_sync(task:, additional_prompting:, images:)
        end
      end

      # Convert agent memory to messages format for the model.
      #
      # Serializes the current memory (task, steps, observations) into
      # the message format expected by the language model.
      #
      # @param summary_mode [Boolean] If true, compress history into summaries (default: false)
      # @return [Array<Hash>] Array of message hashes with :role and :content keys
      #
      # @example Getting messages for next generation step
      #   messages = agent.write_memory_to_messages
      #   # => [
      #   #   { role: "system", content: "You are a helpful agent..." },
      #   #   { role: "user", content: "Find the weather..." },
      #   #   { role: "assistant", content: "I'll search for weather..." },
      #   #   ...
      #   # ]
      #
      # @example Using summary mode for long conversations
      #   messages = agent.write_memory_to_messages(summary_mode: true)
      #   # Messages beyond recent history are compressed
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
            current_step = step(task, step_number:)
            @memory.add_step(current_step)
            emit_step_completed_event(current_step)

            yielder << current_step

            if current_step.is_final_answer
              emit_task_completed_event(:success, current_step.action_output, step_number)
              break
            end

            step_number += 1
          end

          emit_task_completed_event(:max_steps_reached, nil, step_number - 1) if step_number > @max_steps
        end
      end

      def prepare_task(task, additional_prompting: nil, images: nil)
        @memory.add_task(task, additional_prompting:, task_images: images)
      end

      def execute_step_with_monitoring(task, context)
        @logger.step_start(context.step_number)
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

        emit_step_completed_event(current_step)
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
        @logger.warn("Max steps reached", max_steps: @max_steps) if outcome == :max_steps_reached
        cleanup_resources
        build_result(outcome, output, finished)
      end

      def finalize_error(error, context)
        @logger.error("Agent error", error: error.message, backtrace: error.backtrace.first(3))
        cleanup_resources
        build_result(:error, nil, context.finish)
      end

      def cleanup_resources
        # Close HTTP connections to prevent hanging
        @model.close_connections if @model.respond_to?(:close_connections)
      end

      def build_result(outcome, output, context)
        steps_completed = outcome == :success ? context.step_number : context.steps_completed
        emit_task_completed_event(outcome, output, steps_completed)
        RunResult.new(output:, state: outcome, steps: @memory.steps.dup, token_usage: context.total_tokens, timing: context.timing)
      end

      def execute_planning_step_if_needed(_task, _current_step, _step_number); end

      def emit_step_completed_event(current_step)
        return unless emitting?

        outcome = if current_step.is_final_answer
                    :final_answer
                  elsif current_step.respond_to?(:error) && current_step.error
                    :error
                  else
                    :success
                  end

        emit_event(
          Events::StepCompleted.create(
            step_number: current_step.step_number,
            outcome:,
            observations: current_step.observations
          )
        )
      end

      def emit_task_completed_event(outcome, output, steps_taken)
        return unless emitting?

        emit_event(
          Events::TaskCompleted.create(
            outcome:,
            output:,
            steps_taken:
          )
        )
      end
    end
  end
end
