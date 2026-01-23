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

      # Configure observation formatting for tool outputs.
      #
      # Observations always include data structure info (type, keys, access patterns)
      # to help the agent write correct code. Optionally adds LLM summaries.
      #
      # @param mode [Symbol] Observation mode:
      #   - +:with_summary+ (default) - Structure + LLM summary
      #   - +:structure_only+ - Structure only, no LLM call (faster)
      # @yield Block that returns a model for summarization (optional)
      # @return [AgentBuilder] New builder with observation mode configured
      #
      # @example Default (structure + summary using agent's model)
      #   agent.observe(:with_summary)
      #
      # @example Structure only (faster, no extra LLM call)
      #   agent.observe(:structure_only)
      #
      # @example Summary using a fast model
      #   agent.observe(:with_summary) { OpenAIModel.lm_studio("lfm-1.2b") }
      def observe(mode = :with_summary, &block)
        check_frozen!

        case mode
        when :structure_only, :with_summary
          summarizer = block&.call
          with_config(observe_mode: mode, summarizer_model: summarizer)
        else
          raise ArgumentError, "Invalid observe mode: #{mode.inspect}. Use :with_summary or :structure_only"
        end
      end
    end
  end
end
