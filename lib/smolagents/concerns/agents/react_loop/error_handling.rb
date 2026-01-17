module Smolagents
  module Concerns
    module ReActLoop
      # Error recovery patterns for the ReAct loop.
      #
      # Handles errors that occur during step execution:
      # - Logs error details with backtrace
      # - Cleans up resources
      # - Builds error result
      #
      # @see Execution For the main loop
      # @see Completion For successful finalization
      module ErrorHandling
        private

        def finalize_error(error, ctx, memory:)
          @logger.error("Agent error", error: error.message, backtrace: error.backtrace.first(3))
          cleanup_resources
          build_result(:error, nil, ctx.finish, memory:)
        end
      end
    end
  end
end
