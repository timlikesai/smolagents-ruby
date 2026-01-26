module Smolagents
  module Concerns
    module ReActLoop
      # Fiber-based execution with bidirectional control.
      #
      # Provides `run_fiber` for interactive agent sessions where external code
      # can respond to agent requests for input, confirmation, or escalation.
      #
      # @see Core For the composed entry point
      # @see Control For control request methods
      module FiberExecution
        # Execute via Fiber with bidirectional control.
        #
        # The Fiber yields one of three types:
        # - {Types::ActionStep} - A completed step (resume with nil to continue)
        # - {Types::ControlRequests::Request} - Agent needs input (resume with Response)
        # - {Types::RunResult} - Task complete (Fiber ends)
        #
        # @param task [String] The task/question for the agent
        # @param reset [Boolean] If true, reset memory before running
        # @param images [Array<String>, nil] Image paths/URLs for multimodal tasks
        # @param additional_prompting [String, nil] Extra instructions for this run
        # @return [Fiber] Fiber that yields ActionStep, ControlRequest, or RunResult
        def run_fiber(task, reset: true, images: nil, additional_prompting: nil)
          Fiber.new { execute_fiber_body(task, reset, images, additional_prompting) }
        end

        # Delegates to FiberControl for thread-safe context checking.
        # Note: This is defined here for classes that include FiberExecution
        # but not the full Control concern.
        def fiber_context?
          Thread.current.thread_variable_get(Control::FiberControl::FIBER_CONTEXT_KEY) == true
        end

        def write_memory_to_messages(summary_mode: false) = @memory.to_messages(summary_mode:)

        private

        def execute_fiber_body(task, reset, images, additional_prompting)
          Instrumentation.instrument("smolagents.agent.run_fiber", task:, agent_class: self.class.name) do
            reset_state if reset
            @task_images = images
            fiber_loop(task:, additional_prompting:, images:)
          end
        end
      end
    end
  end
end
