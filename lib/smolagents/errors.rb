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
  end
end

# Load after AgentError is defined
require_relative "errors/discovery_error"
require_relative "errors/tool_error"

module Smolagents
  module Errors
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

    # Tool definition errors (raised at tool class definition time, not runtime)
    define_error :ToolConfigurationError, fields: %i[tool_name config_key],
                                          default_message: ->(a) { tool_config_message(a) }

    def self.tool_config_message(attrs)
      tool_name = attrs[:tool_name] ? "Tool '#{attrs[:tool_name]}'" : "Tool"
      config_key = attrs[:config_key] ? " (#{attrs[:config_key]})" : ""
      "#{tool_name} configuration error#{config_key}"
    end

    # API and security errors
    define_error :ApiError, fields: %i[status_code response_body]
    define_error :HttpError, parent: :ApiError, fields: %i[url method]
    define_error :RateLimitError, parent: :HttpError, fields: [:retry_after],
                                  default_message: ->(_) { "Rate limited. Retry later." }
    define_error :ServiceUnavailableError, parent: :HttpError,
                                           default_message: ->(_) { "Service temporarily unavailable." }
    define_error :PromptInjectionError, fields: %i[pattern_type matched_text],
                                        default_message: ->(a) { "Prompt injection detected: #{a[:pattern_type]}" }
    define_error :ArgumentValidationError, fields: %i[tool_name failures],
                                           default_message: ->(a) { "Argument validation failed for #{a[:tool_name]}" }

    # Control flow errors
    define_error :ControlFlowError, fields: %i[request_type context],
                                    defaults: { context: {} }

    # Environment errors
    define_error :EnvironmentError, fields: [:capability]
    define_error :SpawnError, fields: %i[agent_name reason]

    # Timeout errors
    define_error :TimeoutError, fields: %i[operation duration],
                                default_message: ->(a) { timeout_message(a) }

    def self.timeout_message(attrs)
      duration_suffix = attrs[:duration] ? " after #{attrs[:duration]}s" : ""
      "#{attrs[:operation] || "Operation"} timed out#{duration_suffix}"
    end

    # Control flow exception for final answers (not an error).
    class FinalAnswerException < StandardError
      attr_reader :value

      def initialize(value)
        @value = value
        # Delay SecretRedactor lookup to avoid load order issues
        message = if defined?(Security::SecretRedactor)
                    Security::SecretRedactor.safe_inspect(value)
                  else
                    value.inspect
                  end
        super("Final answer: #{message}")
      end

      def deconstruct_keys(_) = { value:, message: }
    end
  end

  # Re-export at module level for convenience.
  # @api private
  EXPORTED_ERRORS = %i[
    AgentError AgentConfigurationError AgentExecutionError AgentGenerationError
    AgentParsingError AgentMaxStepsError ToolExecutionError ToolConfigurationError
    MCPError MCPConnectionError ExecutorError InterpreterError ApiError HttpError
    RateLimitError ServiceUnavailableError PromptInjectionError
    ArgumentValidationError ControlFlowError EnvironmentError SpawnError
    TimeoutError ToolError FinalAnswerException DiscoveryError
  ].freeze

  EXPORTED_ERRORS.each { |name| const_set(name, Errors.const_get(name)) }
end
