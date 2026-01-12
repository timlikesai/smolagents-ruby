require_relative "smolagents/version"
require_relative "smolagents/errors/agent"
require_relative "smolagents/errors/interpreter"
require_relative "smolagents/errors/final_answer"

# Types (ordered by dependencies)
require_relative "smolagents/types/message_role"
require_relative "smolagents/types/data_types"
require_relative "smolagents/types/chat_message"
require_relative "smolagents/types/steps"

# Tools (base classes)
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

# Configuration
require_relative "smolagents/configuration"

# Executors
require_relative "smolagents/executors/executor"
require_relative "smolagents/executors/ruby"
require_relative "smolagents/executors/docker"

# Models
require_relative "smolagents/models/model"

# Agents
require_relative "smolagents/agents/memory"
require_relative "smolagents/agents/agent"
require_relative "smolagents/agents/code"
require_relative "smolagents/agents/tool_calling"
require_relative "smolagents/agents/researcher"
require_relative "smolagents/agents/calculator"
require_relative "smolagents/agents/transcriber"
require_relative "smolagents/agents/data_analyst"
require_relative "smolagents/agents/assistant"
require_relative "smolagents/agents/fact_checker"
require_relative "smolagents/agents/web_scraper"

# Tools (registry + built-ins, after executors for RubyInterpreterTool)
require_relative "smolagents/tools/registry"
require_relative "smolagents/tools/managed_agent"

module Smolagents
  class Error < StandardError; end
end
