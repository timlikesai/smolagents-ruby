module Smolagents
  module Builders
    # Simple setter methods for AgentBuilder using ValidatedSetter.
    module AgentSettersConcern
      def self.included(base)
        base.extend(Support::ValidatedSetter)

        base.validated_setters(
          executor: { key: :executor },
          logger: { key: :logger },
          authorized_imports: { key: :authorized_imports, transform: :flatten }
        )
      end

      # Set the maximum number of steps the agent can take.
      # @param count [Integer] Maximum steps (1-Config::MAX_STEPS_LIMIT)
      # @return [AgentBuilder] New builder with max_steps configured
      def max_steps(count)
        check_frozen!
        validate!(:max_steps, count)
        with_config(max_steps: count)
      end

      # Add custom instructions to the agent's system prompt.
      # Multiple calls append instructions rather than replace them.
      # @param text [String] Custom instructions to add
      # @return [AgentBuilder] New builder with instructions added
      def instructions(text)
        check_frozen!
        validate!(:instructions, text)
        current = configuration[:custom_instructions]
        merged = current ? "#{current}\n\n#{text}" : text
        with_config(custom_instructions: merged)
      end

      # Configure the structured evaluation phase for metacognition.
      # Evaluation is ENABLED BY DEFAULT.
      # @param enabled [Boolean] Whether evaluation is enabled (default: true)
      # @return [AgentBuilder] New builder with evaluation configured
      def evaluation(enabled: true)
        check_frozen!
        with_config(evaluation_enabled: enabled)
      end
    end
  end
end
