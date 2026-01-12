require_relative "smolagents/version"
require_relative "smolagents/errors"

# Types (ordered by dependencies)
require_relative "smolagents/types/message_role"
require_relative "smolagents/types/data_types"
require_relative "smolagents/types/chat_message"
require_relative "smolagents/types/steps"

# Tools
require_relative "smolagents/tools/tool"
require_relative "smolagents/tools/tool_dsl"
require_relative "smolagents/tools/tool_collection"
require_relative "smolagents/tools/result"

# Utilities
require_relative "smolagents/utilities/instrumentation"
require_relative "smolagents/utilities/prompts"
require_relative "smolagents/utilities/pattern_matching"
require_relative "smolagents/utilities/agent_logger"
require_relative "smolagents/utilities/prompt_sanitizer"

# Concerns (ordered by dependencies)
require_relative "smolagents/concerns/http"
require_relative "smolagents/concerns/rate_limiter"
require_relative "smolagents/concerns/api_key"
require_relative "smolagents/concerns/json"
require_relative "smolagents/concerns/html"
require_relative "smolagents/concerns/xml"
require_relative "smolagents/concerns/results"
require_relative "smolagents/concerns/gem_loader"
require_relative "smolagents/concerns/tool_schema"
require_relative "smolagents/concerns/message_formatting"
require_relative "smolagents/concerns/monitorable"
require_relative "smolagents/concerns/streamable"
require_relative "smolagents/concerns/auditable"
require_relative "smolagents/concerns/circuit_breaker"
require_relative "smolagents/concerns/api"
require_relative "smolagents/concerns/step_execution"
require_relative "smolagents/concerns/ruby_safety"
require_relative "smolagents/concerns/react_loop"
require_relative "smolagents/concerns/planning"
require_relative "smolagents/concerns/tool_execution"
require_relative "smolagents/concerns/managed_agents"
require_relative "smolagents/concerns/code_execution"

# Configuration and registry
require_relative "smolagents/default_tools"
require_relative "smolagents/configuration"

# Executors, models, and agents
require_relative "smolagents/executors"
require_relative "smolagents/models/model"
require_relative "smolagents/agents/memory"
require_relative "smolagents/agents"
require_relative "smolagents/tools/managed_agent"

module Smolagents
  class Error < StandardError; end
end
