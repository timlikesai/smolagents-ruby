module Smolagents
  module Types
    module OutcomeComponents
      # Factory methods for creating ExecutionOutcome instances.
      #
      # Provides semantic constructors for each outcome state, ensuring consistent
      # field population and sensible defaults.
      #
      # @example
      #   class MyOutcome < Data.define(:state, :value, :error, :duration, :metadata)
      #     extend OutcomeComponents::Builders
      #   end
      module Builders
        # Creates a success outcome.
        #
        # @param value [Object] The successful result value
        # @param duration [Float] Execution time in seconds (default 0.0)
        # @param metadata [Hash] Additional domain-specific context
        # @return [ExecutionOutcome] Success outcome
        def success(value, duration: 0.0, metadata: {})
          new(state: :success, value:, error: nil, duration:, metadata:)
        end

        # Creates a final answer outcome.
        #
        # @param value [Object] The final answer value
        # @param duration [Float] Execution time in seconds (default 0.0)
        # @param metadata [Hash] Additional domain-specific context
        # @return [ExecutionOutcome] Final answer outcome
        def final_answer(value, duration: 0.0, metadata: {})
          new(state: :final_answer, value:, error: nil, duration:, metadata:)
        end

        # Creates an error outcome.
        #
        # @param error [StandardError] The error that occurred
        # @param duration [Float] Execution time in seconds (default 0.0)
        # @param metadata [Hash] Additional domain-specific context
        # @return [ExecutionOutcome] Error outcome
        def error(error, duration: 0.0, metadata: {})
          new(state: :error, value: nil, error:, duration:, metadata:)
        end

        # Creates a max steps outcome.
        #
        # @param steps_taken [Integer] Number of steps executed before limit
        # @param duration [Float] Total execution time in seconds (default 0.0)
        # @param metadata [Hash] Additional domain-specific context
        # @return [ExecutionOutcome] Max steps outcome
        def max_steps(steps_taken:, duration: 0.0, metadata: {})
          new(
            state: :max_steps_reached,
            value: nil,
            error: nil,
            duration:,
            metadata: metadata.merge(steps_taken:)
          )
        end

        # Creates a timeout outcome.
        #
        # @param duration [Float] Time before timeout in seconds
        # @param metadata [Hash] Additional domain-specific context
        # @return [ExecutionOutcome] Timeout outcome
        def timeout(duration: 0.0, metadata: {})
          new(state: :timeout, value: nil, error: nil, duration:, metadata:)
        end
      end
    end
  end
end
