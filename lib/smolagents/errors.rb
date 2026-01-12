module Smolagents
  class AgentError < StandardError
    def deconstruct_keys(keys)
      { message: message }
    end
  end

  class AgentExecutionError < AgentError
    attr_reader :step_number

    def initialize(message = nil, step_number: nil)
      @step_number = step_number
      super(message)
    end

    def deconstruct_keys(keys)
      { message: message, step_number: step_number }
    end
  end

  class AgentGenerationError < AgentError
    attr_reader :model_id, :response

    def initialize(message = nil, model_id: nil, response: nil)
      @model_id = model_id
      @response = response
      super(message)
    end

    def deconstruct_keys(keys)
      { message: message, model_id: model_id, response: response }
    end
  end

  class AgentParsingError < AgentError
    attr_reader :raw_output, :expected_format

    def initialize(message = nil, raw_output: nil, expected_format: nil)
      @raw_output = raw_output
      @expected_format = expected_format
      super(message)
    end

    def deconstruct_keys(keys)
      { message: message, raw_output: raw_output, expected_format: expected_format }
    end
  end

  class AgentMaxStepsError < AgentError
    attr_reader :max_steps, :steps_taken

    def initialize(message = nil, max_steps: nil, steps_taken: nil)
      @max_steps = max_steps
      @steps_taken = steps_taken
      super(message || "Agent exceeded maximum steps (#{max_steps})")
    end

    def deconstruct_keys(keys)
      { message: message, max_steps: max_steps, steps_taken: steps_taken }
    end
  end

  class ToolExecutionError < AgentExecutionError
    attr_reader :tool_name, :arguments

    def initialize(message = nil, tool_name: nil, arguments: nil, step_number: nil)
      @tool_name = tool_name
      @arguments = arguments
      super(message, step_number: step_number)
    end

    def deconstruct_keys(keys)
      { message: message, tool_name: tool_name, arguments: arguments, step_number: step_number }
    end
  end

  AgentToolCallError = ToolExecutionError
  AgentToolExecutionError = ToolExecutionError

  class MCPError < AgentError
    attr_reader :server_name

    def initialize(message = nil, server_name: nil)
      @server_name = server_name
      super(message)
    end

    def deconstruct_keys(keys)
      { message: message, server_name: server_name }
    end
  end

  class MCPConnectionError < MCPError
    attr_reader :url

    def initialize(message = nil, server_name: nil, url: nil)
      @url = url
      super(message, server_name: server_name)
    end

    def deconstruct_keys(keys)
      { message: message, server_name: server_name, url: url }
    end
  end

  class ExecutorError < AgentError
    attr_reader :language, :code_snippet

    def initialize(message = nil, language: nil, code_snippet: nil)
      @language = language
      @code_snippet = code_snippet
      super(message)
    end

    def deconstruct_keys(keys)
      { message: message, language: language, code_snippet: code_snippet }
    end
  end

  class InterpreterError < ExecutorError
    attr_reader :line_number

    def initialize(message = nil, language: :ruby, code_snippet: nil, line_number: nil)
      @line_number = line_number
      super(message, language: language, code_snippet: code_snippet)
    end

    def deconstruct_keys(keys)
      { message: message, language: language, code_snippet: code_snippet, line_number: line_number }
    end
  end

  class ApiError < AgentError
    attr_reader :status_code, :response_body

    def initialize(message = nil, status_code: nil, response_body: nil)
      @status_code = status_code
      @response_body = response_body
      super(message)
    end

    def deconstruct_keys(keys)
      { message: message, status_code: status_code, response_body: response_body }
    end
  end

  class FinalAnswerException < StandardError
    attr_reader :value

    def initialize(value)
      @value = value
      super("Final answer: #{value.inspect}")
    end

    def deconstruct_keys(keys)
      { value: value, message: message }
    end
  end
end
