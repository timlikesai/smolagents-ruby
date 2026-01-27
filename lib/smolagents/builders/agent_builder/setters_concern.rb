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

      # Configure reasoning mode for token-efficient prompting.
      #
      # Chain of Draft (CoD) elicits minimal reasoning (5-10 words per step)
      # achieving 80%+ token reduction with comparable accuracy.
      #
      # @param mode [Symbol] Reasoning mode:
      #   - +:chain_of_thought+ (default) - Verbose step-by-step reasoning
      #   - +:chain_of_draft+ - Minimal drafts (5-10 words per step)
      #   - +:direct+ - No reasoning, just answers
      # @return [AgentBuilder] New builder with reasoning mode configured
      #
      # @example Default verbose reasoning
      #   builder.reasoning_mode(:chain_of_thought)
      #
      # @example Token-efficient minimal reasoning
      #   builder.reasoning_mode(:chain_of_draft)
      #
      # @example Direct answers only
      #   builder.reasoning_mode(:direct)
      def reasoning_mode(mode)
        check_frozen!

        valid_modes = %i[chain_of_thought chain_of_draft direct]
        unless valid_modes.include?(mode)
          raise ArgumentError,
                "Invalid reasoning mode: #{mode.inspect}. Use: #{valid_modes.join(", ")}"
        end

        with_config(reasoning_mode: mode)
      end

      # Configure tool disclosure mode for context efficiency.
      #
      # Progressive mode shows condensed tool summaries (~20 tokens each)
      # instead of full schemas (~100-200 tokens each). Models can use
      # help(:tool_name) to get full details on demand.
      #
      # @param mode [Symbol] Tool disclosure mode:
      #   - +:full+ (default) - Full tool schemas with examples upfront
      #   - +:progressive+ - Condensed summaries, details on demand
      # @return [AgentBuilder] New builder with tool disclosure configured
      #
      # @example Full disclosure (default)
      #   builder.tool_disclosure(:full)
      #
      # @example Progressive disclosure for small models
      #   builder.tool_disclosure(:progressive)
      def tool_disclosure(mode)
        check_frozen!

        valid_modes = %i[full progressive]
        unless valid_modes.include?(mode)
          raise ArgumentError,
                "Invalid tool disclosure mode: #{mode.inspect}. Use: #{valid_modes.join(", ")}"
        end

        with_config(tool_disclosure: mode)
      end

      # Enable call logging for testing.
      #
      # When enabled, the agent records all tool calls, model calls, and
      # step execution for test assertions. Access the log via agent.call_log.
      #
      # @param enabled [Boolean] Whether to enable call logging (default: true)
      # @return [AgentBuilder] New builder with call logging configured
      #
      # @example Enable call logging
      #   agent = Smolagents.agent
      #     .model { mock }
      #     .with_call_log
      #     .build
      #   agent.run("task")
      #   agent.call_log.include?(tool: :search)
      def with_call_log(enabled: true)
        check_frozen!
        with_config(call_log_enabled: enabled)
      end

      # Configure logging verbosity for test visibility.
      #
      # Controls how much detail is logged during agent execution.
      # Useful for debugging tests and understanding agent behavior.
      #
      # @param level [Symbol] Logging level:
      #   - +:quiet+ - Minimal output (default)
      #   - +:info+ - Step and tool calls
      #   - +:verbose+ - Full detail including prompts
      #   - +:debug+ - Everything including internal state
      # @return [AgentBuilder] New builder with logging configured
      #
      # @example Verbose logging for debugging
      #   agent = Smolagents.agent
      #     .model { mock }
      #     .logging(:verbose)
      #     .build
      def logging(level = :info)
        check_frozen!
        validate_logging_level!(level)
        logger = logger_for_level(level)
        with_config(logger:, logging_level: level)
      end

      private

      VALID_LOGGING_LEVELS = %i[quiet info verbose debug].freeze

      def validate_logging_level!(level)
        return if VALID_LOGGING_LEVELS.include?(level)

        raise ArgumentError, "Invalid logging level: #{level.inspect}. Use: #{VALID_LOGGING_LEVELS.join(", ")}"
      end

      def logger_for_level(level)
        case level
        when :quiet then Smolagents::Logging::NullLogger.instance
        when :info then build_test_logger(:info)
        when :verbose then build_test_logger(:info, verbose: true)
        when :debug then build_test_logger(:debug, verbose: true)
        end
      end

      def build_test_logger(level, verbose: false)
        return Smolagents::Logging::NullLogger.instance unless defined?(Smolagents::Testing::TestLogger)

        Smolagents::Testing::TestLogger.new(level:, verbose:)
      end
    end
  end
end
