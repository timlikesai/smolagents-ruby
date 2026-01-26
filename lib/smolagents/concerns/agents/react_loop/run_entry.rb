module Smolagents
  module Concerns
    module ReActLoop
      # Run entry points and instrumentation.
      #
      # Provides the main `run` method that wraps execution with observability
      # and handles sync vs streaming modes.
      #
      # @see Core For the composed entry point
      # @see FiberExecution For fiber-based execution
      module RunEntry
        # Execute a task using the ReAct loop.
        #
        # @param task [String] The task/question for the agent
        # @param stream [Boolean] If true, return Enumerator<ActionStep>
        # @param reset [Boolean] If true, reset memory before running
        # @param images [Array<String>, nil] Image paths/URLs for multimodal tasks
        # @param additional_prompting [String, nil] Extra instructions for this run
        # @return [Types::RunResult] Final result (sync mode)
        # @return [Enumerator<Types::ActionStep>] Step enumerator (stream mode)
        def run(task, stream: false, reset: true, images: nil, additional_prompting: nil)
          Types::ObservabilityContext.with_context do |obs_ctx|
            instrument_run(task, obs_ctx) do
              execute_run(task, stream, reset, images, additional_prompting)
            end
          end
        end

        private

        def instrument_run(task, obs_ctx, &)
          Instrumentation.instrument(
            "smolagents.agent.run",
            task:,
            agent_class: self.class.name,
            trace_id: obs_ctx.trace_id,
            &
          )
        end

        def execute_run(task, stream, reset, images, additional_prompting)
          prepare_run(reset, images)
          if stream
            run_stream(task:, images:, additional_prompting:)
          else
            run_sync(task, images:, additional_prompting:)
          end
        end
      end
    end
  end
end
