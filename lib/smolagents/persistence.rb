# Agent persistence and serialization.
#
# The Persistence module provides comprehensive serialization and storage
# functionality for agents, tools, and models. It enables saving and loading
# agent state, configuration, and metadata in a structured directory format.
#
# == Available Components
#
# - {Errors} - Persistence-specific exceptions
# - {Serialization} - JSON serialization utilities
# - {ModelManifest} - Model metadata and versioning
# - {ToolManifest} - Tool definitions and schemas
# - {AgentManifest} - Agent configuration and state
# - {DirectoryFormat} - File structure and organization
# - {Serializable} - Mixin for serializable objects
#
# == Directory Structure
#
# Agent persistence uses a hierarchical format:
#
#   agent/
#   ├── agent.json       # Agent configuration and state
#   ├── models/
#   │   └── model.json   # Model metadata
#   ├── tools/
#   │   ├── tool1.json
#   │   ├── tool2.json
#   │   └── ...
#   └── metadata.json    # Overall agent metadata
#
# == Usage
#
# @example Saving an agent
#   manifest = Smolagents::Persistence::AgentManifest.from_agent(agent)
#   manifest.save("./agents/my_agent")
#
# @example Loading an agent
#   manifest = Smolagents::Persistence::AgentManifest.load("./agents/my_agent")
#   agent = manifest.to_agent
#
# == Design
#
# - **Structured format**: JSON with clear schema for each component
# - **Metadata tracking**: Versions, timestamps, dependencies
# - **Roundtrip support**: Save and restore agent state
# - **Validation**: Schema validation on load
#
# @see Persistence::AgentManifest For agent serialization
# @see Persistence::ModelManifest For model metadata
# @see Persistence::ToolManifest For tool definitions
# @see Persistence::DirectoryFormat For file organization
module Smolagents
  module Persistence
  end
end

require_relative "persistence/errors"
require_relative "persistence/serialization"
require_relative "persistence/model_manifest"
require_relative "persistence/tool_manifest"
require_relative "persistence/agent_manifest"
require_relative "persistence/directory_format"
require_relative "persistence/serializable"
