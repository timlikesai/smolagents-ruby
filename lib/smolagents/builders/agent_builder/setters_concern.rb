module Smolagents
  module Builders
    # Simple setter methods for AgentBuilder using ValidatedSetter.
    #
    # @!method executor(value = nil, &block)
    #   Set the executor for sandboxed code execution.
    #   @param value [Executor, nil] An executor instance
    #   @yield Block returning an executor
    #   @return [AgentBuilder] New builder with executor configured
    #
    # @!method logger(value = nil, &block)
    #   Set the logger for agent output.
    #   @param value [Logger, nil] A logger instance
    #   @yield Block returning a logger
    #   @return [AgentBuilder] New builder with logger configured
    #
    # @!method authorized_imports(*imports)
    #   Set authorized imports for sandboxed code execution.
    #   @param imports [Array<String>] Import names to authorize
    #   @return [AgentBuilder] New builder with authorized imports configured
    #
    module AgentSettersConcern
      include Support::FlexibleInput

      def self.included(base)
        base.extend(Support::ValidatedSetter)

        base.validated_setters(
          executor: { key: :executor },
          logger: { key: :logger },
          authorized_imports: { key: :authorized_imports, transform: :flatten },
          max_steps: {},
          reasoning_mode: {},
          tool_disclosure: {}
        )
      end

      # Add custom instructions to the agent's system prompt.
      # Multiple calls append instructions rather than replace them.
      #
      # @param text [String, Array<String>] Custom instructions to add
      # @return [AgentBuilder] New builder with instructions added
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
      # @return [AgentBuilder] New builder with evaluation configured
      def evaluation(enabled_arg = UNSET, enabled: nil)
        check_frozen!
        resolved = resolve_boolean(enabled_arg, enabled, default: true, name: "evaluation")
        with_config(evaluation_enabled: resolved)
      end

      # Configure observation formatting for tool outputs.
      #
      # @param mode [Symbol] Observation mode (:with_summary or :structure_only)
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

      # Enable call logging for testing.
      #
      # @param enabled [Boolean] Whether to enable call logging (default: true)
      # @return [AgentBuilder] New builder with call logging configured
      def with_call_log(enabled: true)
        check_frozen!
        with_config(call_log_enabled: enabled)
      end

      # Configure logging verbosity for test visibility.
      #
      # @param level [Symbol] Logging level (:quiet, :info, :verbose, :debug)
      # @return [AgentBuilder] New builder with logging configured
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
