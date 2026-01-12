# frozen_string_literal: true

module Smolagents
  class AgentError < StandardError; end
  class AgentExecutionError < AgentError; end
  class AgentGenerationError < AgentError; end
  class AgentParsingError < AgentError; end
  class AgentMaxStepsError < AgentError; end
  class AgentToolCallError < AgentExecutionError; end
  class AgentToolExecutionError < AgentExecutionError; end
end
