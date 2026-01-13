module Smolagents
  # Error classes for the Smolagents library.
  #
  # All errors inherit from {Errors::AgentError}, which itself inherits from
  # StandardError. This module provides structured error information through
  # pattern matching via #deconstruct_keys.
  #
  # @example Catching agent errors
  #   begin
  #     agent.run("task")
  #   rescue Smolagents::AgentError => e
  #     puts "Agent failed: #{e.message}"
  #   end
  #
  # @example Pattern matching on errors
  #   case error
  #   in Smolagents::Errors::ToolExecutionError[tool_name:, step_number:]
  #     puts "Tool #{tool_name} failed at step #{step_number}"
  #   in Smolagents::Errors::AgentMaxStepsError[max_steps:, steps_taken:]
  #     puts "Agent took #{steps_taken}/#{max_steps} steps"
  #   end
  #
  # @note All error classes are also re-exported at the Smolagents module level
  #   for convenience (e.g., Smolagents::AgentError works the same as
  #   Smolagents::Errors::AgentError).
  module Errors
    # Base error class for all agent-related errors.
    # Supports pattern matching via #deconstruct_keys.
    class AgentError < StandardError
      def deconstruct_keys(_keys)
        { message: message }
      end
    end

    # Raised when agent execution fails during a step.
    # @attr_reader step_number [Integer, nil] The step number where execution failed
    class AgentExecutionError < AgentError
      attr_reader :step_number

      def initialize(message = nil, step_number: nil)
        @step_number = step_number
        super(message)
      end

      def deconstruct_keys(_keys)
        { message: message, step_number: step_number }
      end
    end

    # Raised when the model fails to generate a valid response.
    # @attr_reader model_id [String, nil] The model identifier
    # @attr_reader response [Object, nil] The raw response from the model
    class AgentGenerationError < AgentError
      attr_reader :model_id, :response

      def initialize(message = nil, model_id: nil, response: nil)
        @model_id = model_id
        @response = response
        super(message)
      end

      def deconstruct_keys(_keys)
        { message: message, model_id: model_id, response: response }
      end
    end

    # Raised when the agent's output cannot be parsed.
    # @attr_reader raw_output [String, nil] The unparseable output
    # @attr_reader expected_format [String, nil] The expected format description
    class AgentParsingError < AgentError
      attr_reader :raw_output, :expected_format

      def initialize(message = nil, raw_output: nil, expected_format: nil)
        @raw_output = raw_output
        @expected_format = expected_format
        super(message)
      end

      def deconstruct_keys(_keys)
        { message: message, raw_output: raw_output, expected_format: expected_format }
      end
    end

    # Raised when the agent exceeds maximum allowed steps.
    # @attr_reader max_steps [Integer, nil] The maximum allowed steps
    # @attr_reader steps_taken [Integer, nil] The number of steps taken
    class AgentMaxStepsError < AgentError
      attr_reader :max_steps, :steps_taken

      def initialize(message = nil, max_steps: nil, steps_taken: nil)
        @max_steps = max_steps
        @steps_taken = steps_taken
        super(message || "Agent exceeded maximum steps (#{max_steps})")
      end

      def deconstruct_keys(_keys)
        { message: message, max_steps: max_steps, steps_taken: steps_taken }
      end
    end

    # Raised when a tool execution fails.
    # @attr_reader tool_name [String, nil] The name of the failed tool
    # @attr_reader arguments [Hash, nil] The arguments passed to the tool
    class ToolExecutionError < AgentExecutionError
      attr_reader :tool_name, :arguments

      def initialize(message = nil, tool_name: nil, arguments: nil, step_number: nil)
        @tool_name = tool_name
        @arguments = arguments
        super(message, step_number: step_number)
      end

      def deconstruct_keys(_keys)
        { message: message, tool_name: tool_name, arguments: arguments, step_number: step_number }
      end
    end

    # @deprecated Use {ToolExecutionError} instead
    AgentToolCallError = ToolExecutionError
    # @deprecated Use {ToolExecutionError} instead
    AgentToolExecutionError = ToolExecutionError

    # Base error class for MCP (Model Context Protocol) related errors.
    # @attr_reader server_name [String, nil] The MCP server name
    class MCPError < AgentError
      attr_reader :server_name

      def initialize(message = nil, server_name: nil)
        @server_name = server_name
        super(message)
      end

      def deconstruct_keys(_keys)
        { message: message, server_name: server_name }
      end
    end

    # Raised when connection to an MCP server fails.
    # @attr_reader url [String, nil] The URL that failed to connect
    class MCPConnectionError < MCPError
      attr_reader :url

      def initialize(message = nil, server_name: nil, url: nil)
        @url = url
        super(message, server_name: server_name)
      end

      def deconstruct_keys(_keys)
        { message: message, server_name: server_name, url: url }
      end
    end

    # Base error class for code executor errors.
    # @attr_reader language [Symbol, nil] The programming language
    # @attr_reader code_snippet [String, nil] The code that caused the error
    class ExecutorError < AgentError
      attr_reader :language, :code_snippet

      def initialize(message = nil, language: nil, code_snippet: nil)
        @language = language
        @code_snippet = code_snippet
        super(message)
      end

      def deconstruct_keys(_keys)
        { message: message, language: language, code_snippet: code_snippet }
      end
    end

    # Raised when the code interpreter encounters an error.
    # @attr_reader line_number [Integer, nil] The line number of the error
    class InterpreterError < ExecutorError
      attr_reader :line_number

      def initialize(message = nil, language: :ruby, code_snippet: nil, line_number: nil)
        @line_number = line_number
        super(message, language: language, code_snippet: code_snippet)
      end

      def deconstruct_keys(_keys)
        { message: message, language: language, code_snippet: code_snippet, line_number: line_number }
      end
    end

    # Raised when an API call fails.
    # @attr_reader status_code [Integer, nil] The HTTP status code
    # @attr_reader response_body [String, nil] The response body
    class ApiError < AgentError
      attr_reader :status_code, :response_body

      def initialize(message = nil, status_code: nil, response_body: nil)
        @status_code = status_code
        @response_body = response_body
        super(message)
      end

      def deconstruct_keys(_keys)
        { message: message, status_code: status_code, response_body: response_body }
      end
    end

    # Error raised when prompt injection is detected and blocking is enabled.
    # @attr_reader pattern_type [String, nil] Type of suspicious pattern detected
    # @attr_reader matched_text [String, nil] The text that matched the pattern
    class PromptInjectionError < AgentError
      attr_reader :pattern_type, :matched_text

      def initialize(message = nil, pattern_type: nil, matched_text: nil)
        @pattern_type = pattern_type
        @matched_text = matched_text
        super(message || "Prompt injection detected: #{pattern_type}")
      end

      def deconstruct_keys(_keys)
        { message: message, pattern_type: pattern_type, matched_text: matched_text }
      end
    end

    # Exception raised to signal a final answer from the agent.
    # This is not an error but a control flow mechanism.
    # @attr_reader value [Object] The final answer value
    class FinalAnswerException < StandardError
      attr_reader :value

      def initialize(value)
        @value = value
        # Use safe_inspect to redact potential API keys from error messages
        super("Final answer: #{SecretRedactor.safe_inspect(value)}")
      end

      def deconstruct_keys(_keys)
        { value: value, message: message }
      end
    end
  end

  # Re-export error classes at Smolagents module level for convenience.
  # This allows code to use either Smolagents::AgentError or Smolagents::Errors::AgentError.
  AgentError = Errors::AgentError
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
