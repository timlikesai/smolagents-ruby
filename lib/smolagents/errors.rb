# frozen_string_literal: true

module Smolagents
  # Base class for all agent-related errors.
  # Inherits from StandardError for typical error handling.
  class AgentError < StandardError; end

  # Raised when there is an error during agent execution.
  class AgentExecutionError < AgentError; end

  # Raised when there is an error during model generation.
  # This should be raised immediately and stop execution.
  class AgentGenerationError < AgentError; end

  # Raised when the agent cannot parse model output.
  class AgentParsingError < AgentError; end

  # Raised when the agent reaches the maximum number of steps.
  class AgentMaxStepsError < AgentError; end

  # Raised when tool arguments are invalid or tool call fails.
  class AgentToolCallError < AgentExecutionError; end

  # Raised when executing a tool raises an exception.
  class AgentToolExecutionError < AgentExecutionError; end

  # Raised when the Ruby code interpreter encounters an error.
  class InterpreterError < StandardError; end

  # Special exception for final_answer detection.
  # Inherits from Exception (NOT StandardError) to avoid being caught
  # by generic rescue blocks.
  class FinalAnswerException < StandardError
    attr_reader :value

    def initialize(value)
      @value = value
      super("Final answer provided: #{value.inspect}")
    end
  end
end
