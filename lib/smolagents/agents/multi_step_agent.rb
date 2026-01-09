# frozen_string_literal: true

module Smolagents
  # Base class for multi-step reasoning agents.
  # Implements ReAct (Reasoning + Acting) loop with tool execution.
  #
  # Subclasses must implement:
  # - #step(task) - Execute one reasoning step
  # - #system_prompt - Return system prompt for the agent
  #
  # @example Creating a subclass
  #   class MyAgent < MultiStepAgent
  #     def step(task)
  #       # Implement reasoning step
  #       # Return ActionStep with observations and final answer
  #     end
  #
  #     def system_prompt
  #       "You are a helpful assistant..."
  #     end
  #   end
  class MultiStepAgent
    include Concerns::Monitorable

    attr_reader :tools, :model, :memory, :max_steps, :logger

    # Initialize agent.
    #
    # @param tools [Array<Tool>] tools available to the agent
    # @param model [Model] language model to use
    # @param max_steps [Integer] maximum reasoning steps
    # @param logger [Monitoring::AgentLogger, nil] optional logger
    def initialize(tools:, model:, max_steps: 20, logger: nil)
      @tools = tools.to_h { |t| [t.name, t] }
      @model = model
      @max_steps = max_steps
      @logger = logger || Monitoring::AgentLogger.new(output: $stderr, level: Monitoring::AgentLogger::WARN)
      @callbacks = Monitoring::CallbackRegistry.new
      @memory = AgentMemory.new(system_prompt)
    end

    # Run agent on a task.
    #
    # @param task [String] task description
    # @param stream [Boolean] whether to stream results
    # @param reset [Boolean] whether to reset memory before running
    # @param additional_prompting [String, nil] additional instructions
    # @return [RunResult] execution result
    def run(task, stream: false, reset: true, additional_prompting: nil)
      @memory.reset if reset

      if stream
        run_stream(task: task, additional_prompting: additional_prompting)
      else
        run_sync(task: task, additional_prompting: additional_prompting)
      end
    end

    # Register a callback for agent events.
    #
    # Available events:
    # - :step_start - When step begins (args: step_number)
    # - :step_complete - When step completes (args: step, monitor)
    # - :step_error - When step fails (args: step, error)
    # - :task_complete - When task finishes (args: result)
    # - :max_steps_reached - When max steps exceeded (args: step_number)
    #
    # @param event [Symbol] event name
    # @yield callback block
    def register_callback(event, &block)
      @callbacks.register(event, &block)
    end

    # Write memory steps to messages for model input.
    #
    # @param summary_mode [Boolean] whether to use succinct summaries
    # @return [Array<ChatMessage>] messages for model
    def write_memory_to_messages(summary_mode: false)
      @memory.to_messages(summary_mode: summary_mode)
    end

    # Execute one reasoning step (must be implemented by subclass).
    #
    # @param task [String] current task
    # @return [ActionStep] step result
    # @raise [NotImplementedError] if not implemented
    def step(task)
      raise NotImplementedError, "#{self.class}#step must be implemented"
    end

    # Get system prompt for agent (must be implemented by subclass).
    #
    # @return [String] system prompt
    # @raise [NotImplementedError] if not implemented
    def system_prompt
      raise NotImplementedError, "#{self.class}#system_prompt must be implemented"
    end

    private

    # Run agent synchronously.
    #
    # @param task [String] task description
    # @param additional_prompting [String, nil] additional instructions
    # @return [RunResult] execution result
    def run_sync(task:, additional_prompting: nil)
      @memory.add_task(task, additional_prompting: additional_prompting)

      step_number = 1
      total_tokens = TokenUsage.new(input_tokens: 0, output_tokens: 0)
      overall_timing = Timing.start_now

      while step_number <= @max_steps
        @logger.step_start(step_number)
        @callbacks.trigger(:step_start, step_number)

        current_step = nil
        monitor_step("step_#{step_number}") do
          current_step = step(task)
          current_step.step_number = step_number
          @memory.add_step(current_step)

          # Track tokens
          if current_step.token_usage
            total_tokens = TokenUsage.new(
              input_tokens: total_tokens.input_tokens + current_step.token_usage.input_tokens,
              output_tokens: total_tokens.output_tokens + current_step.token_usage.output_tokens
            )
          end

          current_step
        end

        # Trigger step complete callback
        @callbacks.trigger(:step_complete, current_step, step_monitors["step_#{step_number}"])
        @logger.step_complete(step_number, duration: step_monitors["step_#{step_number}"].duration)

        # Check if we're done
        if current_step.is_final_answer
          final_timing = overall_timing.stop
          result = RunResult.new(
            output: current_step.action_output,
            state: :success,
            steps: @memory.steps.dup,
            token_usage: total_tokens,
            timing: final_timing
          )
          @callbacks.trigger(:task_complete, result)
          return result
        end

        step_number += 1
      end

      # Max steps reached
      @callbacks.trigger(:max_steps_reached, step_number - 1)
      @logger.warn("Max steps reached", max_steps: @max_steps)

      final_timing = overall_timing.stop
      RunResult.new(
        output: nil,
        state: :max_steps_reached,
        steps: @memory.steps.dup,
        token_usage: total_tokens,
        timing: final_timing
      )
    rescue StandardError => e
      @logger.error("Agent error", error: e.message, backtrace: e.backtrace.first(3))
      final_timing = overall_timing.stop

      RunResult.new(
        output: nil,
        state: :error,
        steps: @memory.steps.dup,
        token_usage: total_tokens,
        timing: final_timing
      )
    end

    # Run agent with streaming.
    #
    # @param task [String] task description
    # @param additional_prompting [String, nil] additional instructions
    # @return [Enumerator] enumerator yielding steps
    def run_stream(task:, additional_prompting: nil)
      Enumerator.new do |yielder|
        @memory.add_task(task, additional_prompting: additional_prompting)

        step_number = 1
        total_tokens = TokenUsage.new(input_tokens: 0, output_tokens: 0)

        while step_number <= @max_steps
          @callbacks.trigger(:step_start, step_number)

          current_step = step(task)
          current_step.step_number = step_number
          @memory.add_step(current_step)

          # Track tokens
          if current_step.token_usage
            total_tokens = TokenUsage.new(
              input_tokens: total_tokens.input_tokens + current_step.token_usage.input_tokens,
              output_tokens: total_tokens.output_tokens + current_step.token_usage.output_tokens
            )
          end

          yielder << current_step
          @callbacks.trigger(:step_complete, current_step, nil)

          break if current_step.is_final_answer

          step_number += 1
        end

        @callbacks.trigger(:max_steps_reached, step_number - 1) if step_number > @max_steps
      end
    end
  end
end
