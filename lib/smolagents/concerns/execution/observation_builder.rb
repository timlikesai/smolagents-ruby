module Smolagents
  module Concerns
    # Observation building for code execution results.
    #
    # Combines execution logs and output into formatted observations
    # for the model to process.
    #
    # @see CodeExecution For the main execution flow
    module ObservationBuilder
      private

      # Build observations from both stdout and return value.
      # The model needs to see tool return values to make decisions.
      def build_observations(action_step, output, logs, code, is_final_answer)
        parts = []
        parts << logs unless logs.nil? || logs.empty?

        # Only include output if it's meaningful (not nil, not final_answer, not noise)
        parts << format_output(output) unless is_final_answer || output.nil? || iterator_noise?(output)

        combined = parts.join("\n")

        # Route through observation router if available (opt-in via concern)
        combined = route_observations(combined, action_step) if respond_to?(:route_observations, true)

        with_code_hints(action_step, combined, code, is_final_answer)
      end

      # Detect outputs that are just iterator return values (noise).
      # Range/Enumerator return values from iterators confuse models.
      def iterator_noise?(output)
        output.is_a?(Range) || output.is_a?(Enumerator)
      end

      # Format the execution output for observation.
      def format_output(output)
        str = output.to_s
        return nil if str.empty?

        str.length > 5000 ? "#{str[0, 5000]}...[truncated]" : str
      end
    end
  end
end
