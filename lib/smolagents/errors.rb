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

  # Re-export at module level for convenience
  AgentError = Errors::AgentError
  AgentConfigurationError = Errors::AgentConfigurationError
  AgentExecutionError = Errors::AgentExecutionError
  AgentGenerationError = Errors::AgentGenerationError
  AgentParsingError = Errors::AgentParsingError
  AgentMaxStepsError = Errors::AgentMaxStepsError
  ToolExecutionError = Errors::ToolExecutionError
  AgentToolCallError = Errors::AgentToolCallError
  AgentToolExecutionError = Errors::AgentToolExecutionError
  MCPError = Errors::MCPError
  MCPConnectionError = Errors::MCPConnectionError
  ExecutorError = Errors::ExecutorError
  InterpreterError = Errors::InterpreterError
  ApiError = Errors::ApiError
  HttpError = Errors::HttpError
  RateLimitError = Errors::RateLimitError
  ServiceUnavailableError = Errors::ServiceUnavailableError
  PromptInjectionError = Errors::PromptInjectionError
  ControlFlowError = Errors::ControlFlowError
  EnvironmentError = Errors::EnvironmentError
  SpawnError = Errors::SpawnError
  FinalAnswerException = Errors::FinalAnswerException
end
