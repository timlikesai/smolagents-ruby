module Smolagents
  module Agents
    class Agent
      # Execution methods for Agent.
      #
      # Provides run, run_fiber, and step methods that delegate to AgentRuntime.
      # Supports synchronous, streaming, and fiber-based execution modes.
      #
      # @api private
      module Execution
        # Runs the agent on a task.
        #
        # @param task [String] The task to accomplish
        # @param stream [Boolean] If true, returns Enumerator yielding ActionStep objects
        # @param reset [Boolean] If true, resets memory before running (default: true)
        # @param images [Array<String>, nil] Image paths/URLs for multimodal tasks
        # @param additional_prompting [String, nil] Extra instructions appended to task
        #
        # @return [Types::RunResult] When stream is false, the final result
        # @return [Enumerator<Types::ActionStep>] When stream is true, step enumerator
        def run(task, stream: false, reset: true, images: nil, additional_prompting: nil)
          @runtime.run(task, stream:, reset:, images:, additional_prompting:)
        end

        # Fiber-based execution with bidirectional control.
        #
        # Returns a Fiber that yields control back to the caller at each step
        # and when user input or confirmation is needed.
        #
        # @param task [String] The task to accomplish
        # @param reset [Boolean] If true, resets memory before running (default: true)
        # @param images [Array<String>, nil] Image paths/URLs for multimodal tasks
        # @param additional_prompting [String, nil] Extra instructions appended to task
        #
        # @return [Fiber] Fiber that yields ActionStep, ControlRequest, or RunResult
        def run_fiber(task, reset: true, images: nil, additional_prompting: nil)
          @runtime.run_fiber(task, reset:, images:, additional_prompting:)
        end

        # Executes a single step in the ReAct loop.
        #
        # @param task [String] The current task (for context)
        # @param step_number [Integer] Current step number (0-indexed)
        #
        # @return [Types::ActionStep] The completed action step with observations
        def step(task, step_number: 0)
          @runtime.step(task, step_number:)
        end
      end
    end
  end
end
