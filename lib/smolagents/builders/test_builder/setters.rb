module Smolagents
  module Builders
    # Setter methods for TestBuilder.
    #
    # Provides chainable configuration methods for test parameters.
    # Each method returns a new builder instance for immutable chaining.
    #
    # @see TestBuilder The main builder class
    module TestBuilderSetters
      SETTER_CONFIG = {
        task: {}, max_steps: {}, timeout: {}, run_n_times: { key: :run_count },
        pass_threshold: {}, name: {}, capability: {},
        tools: { transform: :flatten }, metrics: { transform: :flatten }
      }.freeze

      def self.included(base)
        base.extend(Support::ValidatedSetter)
        base.validated_setters(**SETTER_CONFIG)
      end

      # Sets a validation block for the test result.
      #
      # @yield [result] Block that receives the agent's output
      # @yieldreturn [Boolean] Whether the result passes validation
      # @return [TestBuilder] New builder with updated configuration
      def expects(&block)
        check_frozen!
        with_config(validator: block)
      end

      # Sets a validator object/proc for the test result.
      #
      # @param validator [#call] Any callable that validates the result
      # @return [TestBuilder] New builder with updated configuration
      def expects_validator(validator)
        check_frozen!
        with_config(validator:)
      end
    end
  end
end
