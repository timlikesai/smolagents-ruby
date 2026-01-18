require_relative "errors/dsl"

module Smolagents
  # Error classes with pattern matching support.
  # All errors inherit from AgentError and support Ruby 3.0+ pattern matching.
  #
  # @example Pattern matching on errors
  #   error = Smolagents::Errors::ToolExecutionError.new("failed", tool_name: "search", step_number: 1)
  #   case error
  #   in Smolagents::Errors::ToolExecutionError[tool_name:, step_number:]
  #     "Tool #{tool_name} failed at step #{step_number}"
  #   end  #=> "Tool search failed at step 1"
  module Errors
    extend DSL

    # Base error class for all agent-related errors.
    class AgentError < StandardError
      def self.error_fields = []
      def deconstruct_keys(_) = { message: }
    end

    # Configuration errors
    define_error :AgentConfigurationError, fields: [:config_key]

    # Execution errors
    define_error :AgentExecutionError, fields: [:step_number]
    define_error :ToolExecutionError, parent: :AgentExecutionError, fields: %i[tool_name arguments]

    # Generation and parsing errors
    define_error :AgentGenerationError, fields: %i[model_id response]
    define_error :AgentParsingError, fields: %i[raw_output expected_format]
    define_error :AgentMaxStepsError, fields: %i[max_steps steps_taken],
                                      default_message: ->(a) { "Agent exceeded maximum steps (#{a[:max_steps]})" }

    # MCP (Model Context Protocol) errors
    define_error :MCPError, fields: [:server_name]
    define_error :MCPConnectionError, parent: :MCPError, fields: [:url]

    # Code execution errors
    define_error :ExecutorError, fields: %i[language code_snippet]
    define_error :InterpreterError, parent: :ExecutorError, fields: [:line_number],
                                    defaults: { language: :ruby }

    # API and security errors
    define_error :ApiError, fields: %i[status_code response_body]
    define_error :HttpError, parent: :ApiError, fields: %i[url method]
    define_error :RateLimitError, parent: :HttpError, fields: [:retry_after],
                                  default_message: ->(_) { "Rate limited. Retry later." }
    define_error :ServiceUnavailableError, parent: :HttpError,
                                           default_message: ->(_) { "Service temporarily unavailable." }
    define_error :PromptInjectionError, fields: %i[pattern_type matched_text],
                                        default_message: ->(a) { "Prompt injection detected: #{a[:pattern_type]}" }

    # Control flow errors
    define_error :ControlFlowError, fields: %i[request_type context],
                                    defaults: { context: {} }

    # Environment errors
    define_error :EnvironmentError, fields: [:capability]
    define_error :SpawnError, fields: %i[agent_name reason]

    # Structured tool errors with actionable feedback.
    # Research shows agents treat generic errors as "retry signals" instead of
    # parsing them for solutions. ToolError provides structured, actionable feedback.
    #
    # @example Creating a structured tool error
    #   raise ToolError.new(
    #     code: :invalid_format,
    #     message: "Expression must be a string",
    #     suggestion: "Pass the calculation as a quoted string",
    #     example: 'calculate(expression: "8 * 5")'
    #   )
    #
    # @example Pattern matching on tool errors
    #   case error
    #   in ToolError[code: :invalid_format, suggestion:]
    #     "Fix: #{suggestion}"
    #   end
    ToolError = Data.define(:code, :message, :suggestion, :example) do
      # Formats the error as an actionable observation for the agent.
      # @return [String] Formatted error message with fix and example
      def to_observation
        parts = ["Error [#{code}]: #{message}"]
        parts << "Fix: #{suggestion}" if suggestion
        parts << "Example: #{example}" if example
        parts.join("\n")
      end

      # Converts to string for use with raise.
      # @return [String] The formatted observation
      def to_s = to_observation

      # Creates a ToolError and raises it as an AgentToolCallError.
      # @param code [Symbol] Error code for categorization
      # @param message [String] Human-readable error description
      # @param suggestion [String, nil] How to fix the error
      # @param example [String, nil] Correct usage example
      # @raise [ToolExecutionError] Always raises with the formatted message
      def self.raise!(code:, message:, suggestion: nil, example: nil, tool_name: nil)
        error = new(code:, message:, suggestion:, example:)
        raise ToolExecutionError.new(error.to_observation, tool_name:)
      end

      # Predefined error factories for common cases
      class << self
        # Creates an invalid_format error for type mismatches.
        def invalid_format(expected:, got:, suggestion: nil, example: nil)
          new(
            code: :invalid_format,
            message: "Expected #{expected}, got #{got}",
            suggestion: suggestion || "Ensure the argument is of type #{expected}",
            example:
          )
        end

        # Creates a missing_argument error.
        def missing_argument(name:, suggestion: nil, example: nil)
          new(
            code: :missing_argument,
            message: "Required argument '#{name}' is missing",
            suggestion: suggestion || "Provide the '#{name}' argument",
            example:
          )
        end

        # Creates an invalid_value error for validation failures.
        def invalid_value(name:, value:, reason:, suggestion: nil, example: nil)
          new(
            code: :invalid_value,
            message: "Invalid value '#{value}' for '#{name}': #{reason}",
            suggestion:,
            example:
          )
        end

        # Creates a not_found error for missing resources.
        def not_found(resource:, identifier:, suggestion: nil)
          new(
            code: :not_found,
            message: "#{resource} '#{identifier}' not found",
            suggestion: suggestion || "Check the #{resource.downcase} name or ID",
            example: nil
          )
        end

        # Creates a rate_limited error for throttling.
        def rate_limited(retry_after: nil)
          new(
            code: :rate_limited,
            message: "Request rate limited#{", retry after #{retry_after}s" if retry_after}",
            suggestion: "Wait before retrying or use a different approach",
            example: nil
          )
        end

        # Creates a timeout error.
        def timeout(operation:, duration:)
          new(
            code: :timeout,
            message: "#{operation} timed out after #{duration}s",
            suggestion: "Try a simpler request or increase timeout",
            example: nil
          )
        end
      end
    end

    # Deprecated aliases
    AgentToolCallError = ToolExecutionError
    AgentToolExecutionError = ToolExecutionError

    # Control flow exception for final answers (not an error).
    class FinalAnswerException < StandardError
      attr_reader :value

      def initialize(value)
        @value = value
        super("Final answer: #{SecretRedactor.safe_inspect(value)}")
      end

      def deconstruct_keys(_) = { value:, message: }
    end
  end

  # Re-export at module level for convenience.
  # @api private
  EXPORTED_ERRORS = %i[
    AgentError AgentConfigurationError AgentExecutionError AgentGenerationError
    AgentParsingError AgentMaxStepsError ToolExecutionError AgentToolCallError
    AgentToolExecutionError MCPError MCPConnectionError ExecutorError
    InterpreterError ApiError HttpError RateLimitError ServiceUnavailableError
    PromptInjectionError ControlFlowError EnvironmentError SpawnError
    ToolError FinalAnswerException
  ].freeze

  EXPORTED_ERRORS.each { |name| const_set(name, Errors.const_get(name)) }
end
