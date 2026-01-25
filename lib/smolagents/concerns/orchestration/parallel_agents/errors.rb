module Smolagents
  module Concerns
    module Orchestration
      module ParallelAgents
        # Raised when parallel agent execution fails.
        #
        # Contains all errors from failed agents for inspection.
        class ParallelExecutionError < StandardError
          attr_reader :errors

          # @param errors [Array<StandardError, String>] Errors from failed agents
          def initialize(errors)
            @errors = errors
            super(build_message)
          end

          # @return [Integer] Number of failed agents
          def failure_count = errors.size

          private

          def build_message
            if errors.size == 1
              "Parallel execution failed: #{errors.first}"
            else
              "Parallel execution failed with #{errors.size} errors: #{error_summary}"
            end
          end

          def error_summary
            errors.map { |e| e.is_a?(Exception) ? e.message : e.to_s }.join("; ")
          end
        end
      end
    end
  end
end
