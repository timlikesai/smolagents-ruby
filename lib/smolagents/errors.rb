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
      # Extract error information for pattern matching.
      #
      # Allows destructuring of error objects using Ruby's pattern matching syntax.
      # Returns a hash containing the error message.
      #
      # @param keys [Array<Symbol>, nil] Keys to extract (nil for all keys)
      # @return [Hash{Symbol => Object}] Hash with :message key
      #
      # @example Pattern matching on agent errors
      #   case error
      #   in Smolagents::AgentError[message:]
      #     puts "Agent error: #{message}"
      #   end
      def deconstruct_keys(_keys)
        { message: message }
      end
    end

    # Raised when agent configuration is invalid.
    #
    # @attr_reader config_key [String, nil] The configuration key that is invalid
    #
    # @example Catching configuration errors
    #   begin
    #     agent = Smolagents::Agent.new(config: invalid_config)
    #   rescue Smolagents::AgentConfigurationError => e
    #     puts "Invalid config key: #{e.config_key}"
    #   end
    class AgentConfigurationError < AgentError
      attr_reader :config_key

      def initialize(message = nil, config_key: nil)
        @config_key = config_key
        super(message)
      end

      # Extract configuration error information for pattern matching.
      #
      # Allows destructuring to access the error message and the invalid
      # configuration key.
      #
      # @param keys [Array<Symbol>, nil] Keys to extract (nil for all keys)
      # @return [Hash{Symbol => Object}] Hash with :message and :config_key keys
      #
      # @example Pattern matching on configuration errors
      #   case error
      #   in Smolagents::AgentConfigurationError[config_key:, message:]
      #     puts "Invalid key #{config_key}: #{message}"
      #   end
      def deconstruct_keys(_keys)
        { message: message, config_key: config_key }
      end
    end

    # Raised when agent execution fails during a step.
    #
    # @attr_reader step_number [Integer, nil] The step number where execution failed
    #
    # @example Catching execution errors
    #   begin
    #     result = agent.run("task")
    #   rescue Smolagents::AgentExecutionError => e
    #     puts "Failed at step #{e.step_number}"
    #   end
    class AgentExecutionError < AgentError
      attr_reader :step_number

      def initialize(message = nil, step_number: nil)
        @step_number = step_number
        super(message)
      end

      # Extract execution error information for pattern matching.
      #
      # Allows destructuring to access the error message and the step number
      # where the error occurred.
      #
      # @param keys [Array<Symbol>, nil] Keys to extract (nil for all keys)
      # @return [Hash{Symbol => Object}] Hash with :message and :step_number keys
      #
      # @example Pattern matching on execution errors
      #   case error
      #   in Smolagents::AgentExecutionError[step_number:, message:]
      #     puts "Step #{step_number} failed: #{message}"
      #   end
      def deconstruct_keys(_keys)
        { message: message, step_number: step_number }
      end
    end

    # Raised when the model fails to generate a valid response.
    #
    # @attr_reader model_id [String, nil] The model identifier
    # @attr_reader response [Object, nil] The raw response from the model
    #
    # @example Catching generation errors
    #   begin
    #     response = model.generate(prompt)
    #   rescue Smolagents::AgentGenerationError => e
    #     puts "Model #{e.model_id} failed to generate"
    #   end
    class AgentGenerationError < AgentError
      attr_reader :model_id, :response

      def initialize(message = nil, model_id: nil, response: nil)
        @model_id = model_id
        @response = response
        super(message)
      end

      # Extract generation error information for pattern matching.
      #
      # Allows destructuring to access the error message, model identifier,
      # and the raw response that caused the failure.
      #
      # @param keys [Array<Symbol>, nil] Keys to extract (nil for all keys)
      # @return [Hash{Symbol => Object}] Hash with :message, :model_id, and :response keys
      #
      # @example Pattern matching on generation errors
      #   case error
      #   in Smolagents::AgentGenerationError[model_id:, response:]
      #     puts "Model #{model_id} response: #{response}"
      #   end
      def deconstruct_keys(_keys)
        { message: message, model_id: model_id, response: response }
      end
    end

    # Raised when the agent's output cannot be parsed.
    #
    # @attr_reader raw_output [String, nil] The unparseable output
    # @attr_reader expected_format [String, nil] The expected format description
    #
    # @example Catching parsing errors
    #   begin
    #     result = agent.parse_response(response)
    #   rescue Smolagents::AgentParsingError => e
    #     puts "Cannot parse: #{e.raw_output}"
    #   end
    class AgentParsingError < AgentError
      attr_reader :raw_output, :expected_format

      def initialize(message = nil, raw_output: nil, expected_format: nil)
        @raw_output = raw_output
        @expected_format = expected_format
        super(message)
      end

      # Extract parsing error information for pattern matching.
      #
      # Allows destructuring to access the error message, the raw unparseable
      # output, and the expected format specification.
      #
      # @param keys [Array<Symbol>, nil] Keys to extract (nil for all keys)
      # @return [Hash{Symbol => Object}] Hash with :message, :raw_output, and :expected_format keys
      #
      # @example Pattern matching on parsing errors
      #   case error
      #   in Smolagents::AgentParsingError[raw_output:, expected_format:]
      #     puts "Got: #{raw_output}"
      #     puts "Expected: #{expected_format}"
      #   end
      def deconstruct_keys(_keys)
        { message: message, raw_output: raw_output, expected_format: expected_format }
      end
    end

    # Raised when the agent exceeds maximum allowed steps.
    #
    # @attr_reader max_steps [Integer, nil] The maximum allowed steps
    # @attr_reader steps_taken [Integer, nil] The number of steps taken
    #
    # @example Catching max steps errors
    #   begin
    #     result = agent.run("complex task")
    #   rescue Smolagents::AgentMaxStepsError => e
    #     puts "Max steps: #{e.max_steps}, Taken: #{e.steps_taken}"
    #   end
    class AgentMaxStepsError < AgentError
      attr_reader :max_steps, :steps_taken

      def initialize(message = nil, max_steps: nil, steps_taken: nil)
        @max_steps = max_steps
        @steps_taken = steps_taken
        super(message || "Agent exceeded maximum steps (#{max_steps})")
      end

      # Extract max steps error information for pattern matching.
      #
      # Allows destructuring to access the error message, maximum allowed steps,
      # and the number of steps the agent actually took.
      #
      # @param keys [Array<Symbol>, nil] Keys to extract (nil for all keys)
      # @return [Hash{Symbol => Object}] Hash with :message, :max_steps, and :steps_taken keys
      #
      # @example Pattern matching on max steps errors
      #   case error
      #   in Smolagents::AgentMaxStepsError[max_steps:, steps_taken:]
      #     puts "Agent took #{steps_taken}/#{max_steps} steps"
      #   end
      def deconstruct_keys(_keys)
        { message: message, max_steps: max_steps, steps_taken: steps_taken }
      end
    end

    # Raised when a tool execution fails.
    #
    # @attr_reader tool_name [String, nil] The name of the failed tool
    # @attr_reader arguments [Hash, nil] The arguments passed to the tool
    #
    # @example Catching tool execution errors
    #   begin
    #     result = tool.execute(**args)
    #   rescue Smolagents::ToolExecutionError => e
    #     puts "Tool #{e.tool_name} failed at step #{e.step_number}"
    #   end
    class ToolExecutionError < AgentExecutionError
      attr_reader :tool_name, :arguments

      def initialize(message = nil, tool_name: nil, arguments: nil, step_number: nil)
        @tool_name = tool_name
        @arguments = arguments
        super(message, step_number: step_number)
      end

      # Extract tool execution error information for pattern matching.
      #
      # Allows destructuring to access the error message, tool name, arguments
      # passed to the tool, and the step number where the failure occurred.
      #
      # @param keys [Array<Symbol>, nil] Keys to extract (nil for all keys)
      # @return [Hash{Symbol => Object}] Hash with :message, :tool_name, :arguments, and :step_number keys
      #
      # @example Pattern matching on tool execution errors
      #   case error
      #   in Smolagents::ToolExecutionError[tool_name:, step_number:]
      #     puts "Tool #{tool_name} failed at step #{step_number}"
      #   end
      def deconstruct_keys(_keys)
        { message: message, tool_name: tool_name, arguments: arguments, step_number: step_number }
      end
    end

    # @deprecated Use {ToolExecutionError} instead
    AgentToolCallError = ToolExecutionError
    # @deprecated Use {ToolExecutionError} instead
    AgentToolExecutionError = ToolExecutionError

    # Base error class for MCP (Model Context Protocol) related errors.
    #
    # @attr_reader server_name [String, nil] The MCP server name
    #
    # @example Catching MCP errors
    #   begin
    #     server = MCPServer.connect(url)
    #   rescue Smolagents::MCPError => e
    #     puts "MCP error from #{e.server_name}"
    #   end
    class MCPError < AgentError
      attr_reader :server_name

      def initialize(message = nil, server_name: nil)
        @server_name = server_name
        super(message)
      end

      # Extract MCP error information for pattern matching.
      #
      # Allows destructuring to access the error message and the MCP server name.
      #
      # @param keys [Array<Symbol>, nil] Keys to extract (nil for all keys)
      # @return [Hash{Symbol => Object}] Hash with :message and :server_name keys
      #
      # @example Pattern matching on MCP errors
      #   case error
      #   in Smolagents::MCPError[server_name:, message:]
      #     puts "Server #{server_name} error: #{message}"
      #   end
      def deconstruct_keys(_keys)
        { message: message, server_name: server_name }
      end
    end

    # Raised when connection to an MCP server fails.
    #
    # @attr_reader url [String, nil] The URL that failed to connect
    #
    # @example Catching MCP connection errors
    #   begin
    #     server = MCPServer.connect("http://invalid.url")
    #   rescue Smolagents::MCPConnectionError => e
    #     puts "Cannot connect to #{e.url}"
    #   end
    class MCPConnectionError < MCPError
      attr_reader :url

      def initialize(message = nil, server_name: nil, url: nil)
        @url = url
        super(message, server_name: server_name)
      end

      # Extract MCP connection error information for pattern matching.
      #
      # Allows destructuring to access the error message, MCP server name,
      # and the URL that failed to connect.
      #
      # @param keys [Array<Symbol>, nil] Keys to extract (nil for all keys)
      # @return [Hash{Symbol => Object}] Hash with :message, :server_name, and :url keys
      #
      # @example Pattern matching on MCP connection errors
      #   case error
      #   in Smolagents::MCPConnectionError[url:, server_name:]
      #     puts "Failed to connect to #{server_name} at #{url}"
      #   end
      def deconstruct_keys(_keys)
        { message: message, server_name: server_name, url: url }
      end
    end

    # Base error class for code executor errors.
    #
    # @attr_reader language [Symbol, nil] The programming language
    # @attr_reader code_snippet [String, nil] The code that caused the error
    #
    # @example Catching executor errors
    #   begin
    #     executor.execute(code, language: :ruby)
    #   rescue Smolagents::ExecutorError => e
    #     puts "Executor error in #{e.language}: #{e.code_snippet}"
    #   end
    class ExecutorError < AgentError
      attr_reader :language, :code_snippet

      def initialize(message = nil, language: nil, code_snippet: nil)
        @language = language
        @code_snippet = code_snippet
        super(message)
      end

      # Extract executor error information for pattern matching.
      #
      # Allows destructuring to access the error message, programming language,
      # and the code snippet that caused the error.
      #
      # @param keys [Array<Symbol>, nil] Keys to extract (nil for all keys)
      # @return [Hash{Symbol => Object}] Hash with :message, :language, and :code_snippet keys
      #
      # @example Pattern matching on executor errors
      #   case error
      #   in Smolagents::ExecutorError[language:, code_snippet:]
      #     puts "Error in #{language}: #{code_snippet}"
      #   end
      def deconstruct_keys(_keys)
        { message: message, language: language, code_snippet: code_snippet }
      end
    end

    # Raised when the code interpreter encounters an error.
    #
    # @attr_reader line_number [Integer, nil] The line number of the error
    #
    # @example Catching interpreter errors
    #   begin
    #     interpreter.execute(code)
    #   rescue Smolagents::InterpreterError => e
    #     puts "Error at line #{e.line_number}: #{e.message}"
    #   end
    class InterpreterError < ExecutorError
      attr_reader :line_number

      def initialize(message = nil, language: :ruby, code_snippet: nil, line_number: nil)
        @line_number = line_number
        super(message, language: language, code_snippet: code_snippet)
      end

      # Extract interpreter error information for pattern matching.
      #
      # Allows destructuring to access the error message, programming language,
      # code snippet, and the line number where the error occurred.
      #
      # @param keys [Array<Symbol>, nil] Keys to extract (nil for all keys)
      # @return [Hash{Symbol => Object}] Hash with :message, :language, :code_snippet, and :line_number keys
      #
      # @example Pattern matching on interpreter errors
      #   case error
      #   in Smolagents::InterpreterError[line_number:, message:]
      #     puts "Interpreter error at line #{line_number}"
      #   end
      def deconstruct_keys(_keys)
        { message: message, language: language, code_snippet: code_snippet, line_number: line_number }
      end
    end

    # Raised when an API call fails.
    #
    # @attr_reader status_code [Integer, nil] The HTTP status code
    # @attr_reader response_body [String, nil] The response body
    #
    # @example Catching API errors
    #   begin
    #     response = api.call(endpoint)
    #   rescue Smolagents::ApiError => e
    #     puts "API error #{e.status_code}: #{e.response_body}"
    #   end
    class ApiError < AgentError
      attr_reader :status_code, :response_body

      def initialize(message = nil, status_code: nil, response_body: nil)
        @status_code = status_code
        @response_body = response_body
        super(message)
      end

      # Extract API error information for pattern matching.
      #
      # Allows destructuring to access the error message, HTTP status code,
      # and the response body from the failed API call.
      #
      # @param keys [Array<Symbol>, nil] Keys to extract (nil for all keys)
      # @return [Hash{Symbol => Object}] Hash with :message, :status_code, and :response_body keys
      #
      # @example Pattern matching on API errors
      #   case error
      #   in Smolagents::ApiError[status_code: 404]
      #     puts "Resource not found"
      #   in Smolagents::ApiError[status_code: 500.., response_body:]
      #     puts "Server error: #{response_body}"
      #   end
      def deconstruct_keys(_keys)
        { message: message, status_code: status_code, response_body: response_body }
      end
    end

    # Error raised when prompt injection is detected and blocking is enabled.
    #
    # @attr_reader pattern_type [String, nil] Type of suspicious pattern detected
    # @attr_reader matched_text [String, nil] The text that matched the pattern
    #
    # @example Catching prompt injection errors
    #   begin
    #     agent.run(user_input)
    #   rescue Smolagents::PromptInjectionError => e
    #     puts "Blocked: #{e.pattern_type} pattern"
    #   end
    class PromptInjectionError < AgentError
      attr_reader :pattern_type, :matched_text

      def initialize(message = nil, pattern_type: nil, matched_text: nil)
        @pattern_type = pattern_type
        @matched_text = matched_text
        super(message || "Prompt injection detected: #{pattern_type}")
      end

      # Extract prompt injection error information for pattern matching.
      #
      # Allows destructuring to access the error message, the pattern type that
      # was detected, and the text that matched the suspicious pattern.
      #
      # @param keys [Array<Symbol>, nil] Keys to extract (nil for all keys)
      # @return [Hash{Symbol => Object}] Hash with :message, :pattern_type, and :matched_text keys
      #
      # @example Pattern matching on prompt injection errors
      #   case error
      #   in Smolagents::PromptInjectionError[pattern_type:, matched_text:]
      #     puts "Blocked #{pattern_type}: #{matched_text}"
      #   end
      def deconstruct_keys(_keys)
        { message: message, pattern_type: pattern_type, matched_text: matched_text }
      end
    end

    # Exception raised to signal a final answer from the agent.
    # This is not an error but a control flow mechanism for early termination.
    #
    # @attr_reader value [Object] The final answer value
    #
    # @example Using final answer exception for control flow
    #   raise Smolagents::FinalAnswerException.new("The answer is 42")
    class FinalAnswerException < StandardError
      attr_reader :value

      def initialize(value)
        @value = value
        # Use safe_inspect to redact potential API keys from error messages
        super("Final answer: #{SecretRedactor.safe_inspect(value)}")
      end

      # Extract final answer exception information for pattern matching.
      #
      # Allows destructuring to access the final answer value and error message.
      # This is primarily used for control flow rather than error handling.
      #
      # @param keys [Array<Symbol>, nil] Keys to extract (nil for all keys)
      # @return [Hash{Symbol => Object}] Hash with :value and :message keys
      #
      # @example Pattern matching on final answer exception
      #   case exception
      #   in Smolagents::FinalAnswerException[value:]
      #     puts "Final answer: #{value}"
      #   end
      def deconstruct_keys(_keys)
        { value: value, message: message }
      end
    end
  end

  # Re-export error classes at Smolagents module level for convenience.
  # This allows code to use either Smolagents::AgentError or Smolagents::Errors::AgentError.

  # Base error class for all agent-related errors.
  # @see Errors::AgentError
  AgentError = Errors::AgentError

  # Raised when agent configuration is invalid.
  # @see Errors::AgentConfigurationError
  AgentConfigurationError = Errors::AgentConfigurationError

  # Raised when agent execution fails during a step.
  # @see Errors::AgentExecutionError
  AgentExecutionError = Errors::AgentExecutionError

  # Raised when the model fails to generate a valid response.
  # @see Errors::AgentGenerationError
  AgentGenerationError = Errors::AgentGenerationError

  # Raised when the agent's output cannot be parsed.
  # @see Errors::AgentParsingError
  AgentParsingError = Errors::AgentParsingError

  # Raised when the agent exceeds maximum allowed steps.
  # @see Errors::AgentMaxStepsError
  AgentMaxStepsError = Errors::AgentMaxStepsError

  # Raised when a tool execution fails.
  # @see Errors::ToolExecutionError
  ToolExecutionError = Errors::ToolExecutionError

  # @deprecated Use {ToolExecutionError} instead
  # @see Errors::AgentToolCallError
  AgentToolCallError = Errors::AgentToolCallError

  # @deprecated Use {ToolExecutionError} instead
  # @see Errors::AgentToolExecutionError
  AgentToolExecutionError = Errors::AgentToolExecutionError

  # Base error class for MCP (Model Context Protocol) related errors.
  # @see Errors::MCPError
  MCPError = Errors::MCPError

  # Raised when connection to an MCP server fails.
  # @see Errors::MCPConnectionError
  MCPConnectionError = Errors::MCPConnectionError

  # Base error class for code executor errors.
  # @see Errors::ExecutorError
  ExecutorError = Errors::ExecutorError

  # Raised when the code interpreter encounters an error.
  # @see Errors::InterpreterError
  InterpreterError = Errors::InterpreterError

  # Raised when an API call fails.
  # @see Errors::ApiError
  ApiError = Errors::ApiError

  # Error raised when prompt injection is detected and blocking is enabled.
  # @see Errors::PromptInjectionError
  PromptInjectionError = Errors::PromptInjectionError

  # Exception raised to signal a final answer from the agent.
  # @see Errors::FinalAnswerException
  FinalAnswerException = Errors::FinalAnswerException
end
