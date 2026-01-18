module Smolagents
  module CLI
    module Commands
      # Result display helpers for CLI output.
      #
      # Handles formatting and displaying agent execution results with appropriate
      # color coding and timing information.
      module Display
        # Displays an agent execution result.
        #
        # Routes to success or failure display based on result state.
        #
        # @param result [RunResult] The agent execution result
        # @return [void]
        def display_result(result)
          result.success? ? display_success(result) : display_failure(result)
        end

        private

        def display_success(result)
          say "\nResult:", :green
          say result.output
          say "\n(#{result.steps.size} steps, #{result.timing.duration.round(2)}s)", :cyan
        end

        def display_failure(result)
          say "\nAgent did not complete successfully: #{result.state}", :red
          return unless result.steps.any?

          say "Last observation: #{result.steps.last&.observations&.slice(0, 200)}...", :yellow
        end
      end
    end
  end
end
