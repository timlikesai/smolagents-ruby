module Smolagents
  module Builders
    # Simple setter methods for AgentBuilder using ValidatedSetter.
    #
    # @!method executor(value = nil, &block)
    #   Set the executor for sandboxed code execution.
    #   @param value [Executor, nil] An executor instance
    #   @yield Block returning an executor
    #   @return [AgentBuilder] New builder with executor configured
    #   @example Using an executor instance
    #     builder.executor(LocalRubyExecutor.new)
    #   @example Using a block
    #     builder.executor { LocalRubyExecutor.new(timeout: 30) }
    #
    # @!method logger(value = nil, &block)
    #   Set the logger for agent output.
    #   @param value [Logger, nil] A logger instance
    #   @yield Block returning a logger
    #   @return [AgentBuilder] New builder with logger configured
    #   @example Using a logger instance
    #     builder.logger(Logger.new($stdout))
    #   @example Using a block
    #     builder.logger { Logger.new("agent.log") }
    #
    # @!method authorized_imports(*imports)
    #   Set authorized imports for sandboxed code execution.
    #   Multiple values are flattened into a single array.
    #   @param imports [Array<String>] Import names to authorize
    #   @return [AgentBuilder] New builder with authorized imports configured
    #   @example Single import
    #     builder.authorized_imports("json")
    #   @example Multiple imports
    #     builder.authorized_imports("json", "csv", "net/http")
    #   @example Array of imports
    #     builder.authorized_imports(["json", "csv"])
    #
    module AgentSettersConcern
      include Support::FlexibleInput

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
      #
      # @param text [String, Array<String>] Custom instructions to add
      # @return [AgentBuilder] New builder with instructions added
      #
      # @example Single string
      #   builder.instructions("Be concise")
      #
      # @example Array of strings
      #   builder.instructions(["Be concise", "Focus on accuracy"])
      def instructions(text)
        check_frozen!
        normalized = normalize_to_string(text)
        validate!(:instructions, normalized)
        current = configuration[:custom_instructions]
        merged = current ? "#{current}\n\n#{normalized}" : normalized
        with_config(custom_instructions: merged)
      end

      # Configure the structured evaluation phase for metacognition.
      # Evaluation is ENABLED BY DEFAULT.
      #
      # @overload evaluation
      #   Enable evaluation (default)
      #
      # @overload evaluation(enabled)
      #   Toggle evaluation on/off with boolean
      #   @param enabled [Boolean]
      #
      # @overload evaluation(enabled:)
      #   Toggle evaluation with keyword
      #   @param enabled [Boolean]
      #
      # @return [AgentBuilder] New builder with evaluation configured
      #
      # @example Enable (default)
      #   builder.evaluation
      #
      # @example Disable with positional
      #   builder.evaluation(false)
      #
      # @example Disable with keyword
      #   builder.evaluation(enabled: false)
      def evaluation(enabled_arg = UNSET, enabled: nil)
        check_frozen!
        resolved = resolve_boolean(enabled_arg, enabled, default: true, name: "evaluation")
        with_config(evaluation_enabled: resolved)
      end

      # Configure observation formatting for tool outputs.
      #
      # @param mode [Symbol] Observation mode:
      #   - +:with_summary+ (default) - Structure + LLM summary
      #   - +:structure_only+ - Structure only, no LLM call (faster)
      # @yield Block that returns a model for summarization (optional)
      # @return [AgentBuilder] New builder with observation mode configured
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
