require_relative "builders/agent_builder"
require_relative "builders/team_builder"
require_relative "builders/model_builder"

module Smolagents
  module Builders
    # Agent type to class mapping (shared across builders)
    # Using class names as strings to avoid circular dependency issues
    AGENT_TYPES = {
      code: "Smolagents::Agents::Code",
      tool_calling: "Smolagents::Agents::ToolCalling"
    }.freeze
  end
end
