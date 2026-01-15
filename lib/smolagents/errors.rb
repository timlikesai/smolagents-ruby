require_relative "errors/dsl"

module Smolagents
  # Error classes with pattern matching support.
  # All errors inherit from AgentError and support Ruby 3.0+ pattern matching.
  #
  # @example Pattern matching on errors
  #   case error
  #   in ToolExecutionError[tool_name:, step_number:]
  #     puts "Tool #{tool_name} failed at step #{step_number}"
  #   end
  module Errors
    extend DSL

    # Base error class for all agent-related errors.
    class AgentError < StandardError
      def self.error_attrs = []
      def deconstruct_keys(_) = { message: }
    end

    # Configuration errors
    define_error :AgentConfigurationError, attrs: [:config_key]

    # Execution errors
    define_error :AgentExecutionError, attrs: [:step_number]
    define_error :ToolExecutionError, parent: :AgentExecutionError, attrs: %i[tool_name arguments]

    # Generation and parsing errors
    define_error :AgentGenerationError, attrs: %i[model_id response]
    define_error :AgentParsingError, attrs: %i[raw_output expected_format]
    define_error :AgentMaxStepsError, attrs: %i[max_steps steps_taken],
                                      default_message: ->(a) { "Agent exceeded maximum steps (#{a[:max_steps]})" }

    # MCP (Model Context Protocol) errors
    define_error :MCPError, attrs: [:server_name]
    define_error :MCPConnectionError, parent: :MCPError, attrs: [:url]

    # Code execution errors
    define_error :ExecutorError, attrs: %i[language code_snippet]
    define_error :InterpreterError, parent: :ExecutorError, attrs: [:line_number],
                                    defaults: { language: :ruby }

    # API and security errors
    define_error :ApiError, attrs: %i[status_code response_body]
    define_error :PromptInjectionError, attrs: %i[pattern_type matched_text],
                                        default_message: ->(a) { "Prompt injection detected: #{a[:pattern_type]}" }

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
  PromptInjectionError = Errors::PromptInjectionError
  FinalAnswerException = Errors::FinalAnswerException
end
