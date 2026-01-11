module Smolagents
  class AgentError < StandardError; end

  class AgentExecutionError < AgentError; end

  class AgentGenerationError < AgentError; end

  class AgentParsingError < AgentError; end

  class AgentMaxStepsError < AgentError; end

  class AgentToolCallError < AgentExecutionError; end

  class AgentToolExecutionError < AgentExecutionError; end

  class InterpreterError < StandardError; end

  class FinalAnswerException < StandardError
    attr_reader :value

    def initialize(value)
      @value = value
      super("Final answer provided: #{value.inspect}")
    end
  end
end
