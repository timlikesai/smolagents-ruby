module Smolagents
  module Concerns
    # Observation building for code execution results.
    #
    # Combines execution logs and output into formatted observations
    # for the model to process.
    #
    # @see CodeExecution For the main execution flow
    module ObservationBuilder
      # Default character limit for output truncation.
      # Can be overridden by setting @observation_limit in the including class.
      DEFAULT_OBSERVATION_LIMIT = 5000

      private

      # Build observations from both stdout and return value.
      # The model needs to see tool return values to make decisions.
      def build_observations(action_step, output, logs, code, final_answer)
        parts = []
        parts << logs unless logs.nil? || logs.empty?

        # Only include output if it's meaningful (not nil, not final_answer, not noise)
        parts << format_output(output) unless final_answer || output.nil? || iterator_noise?(output)

        combined = parts.join("\n")

        # Route through observation router if available (opt-in via concern)
        combined = route_observations(combined, action_step) if respond_to?(:route_observations, true)

        with_code_hints(action_step, combined, code, final_answer)
      end

      # Detect outputs that are just iterator return values (noise).
      # Range/Enumerator return values from iterators confuse models.
      def iterator_noise?(output)
        output.is_a?(Range) || output.is_a?(Enumerator)
      end

      # Format the execution output for observation.
      # Shows truncation warning with character counts so models know data was lost.
      def format_output(output)
        str = ruby_literal(output)
        return nil if str.empty?

        limit = observation_limit
        return str unless str.length > limit

        "#{str[0, limit]}\n[TRUNCATED: showing #{limit} of #{str.length} characters]"
      end

      # Produce Ruby literal notation for Hash/Array so models recognize the data.
      def ruby_literal(output)
        case output
        when Hash, Array then output.inspect
        else output.to_s
        end
      end

      # Returns the observation character limit.
      # Override @observation_limit to customize per-agent.
      def observation_limit
        @observation_limit || DEFAULT_OBSERVATION_LIMIT
      end
    end
  end
end
