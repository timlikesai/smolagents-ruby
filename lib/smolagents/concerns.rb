# Module containing reusable mixins and behaviors for agent components.
#
# The Concerns module provides a collection of composable mixins organized
# by domain. Each group can be included independently or composed together.
#
# == Concern Groups
#
# - {Api} - API interaction (keys, http, client patterns)
# - {Agents} - Agent behaviors (react_loop, planning, managed, async, specialized)
# - {Models} - Model behaviors (health, reliability, queue)
# - {Tools} - Tool behaviors (schema, browser, mcp)
# - {Formatting} - Output formatting (results, output, messages)
# - {Parsing} - Input parsing (json, xml, html)
# - {Monitoring} - Observability (steps, audit)
# - {Resilience} - Fault tolerance (retry, circuit breaker, rate limit, fallback)
# - {Sandbox} - Code safety (validation, methods)
# - {Execution} - Work execution (step, code, tool)
# - {Support} - Helpers (gem_loader)
#
# @example Using a concern group
#   class MyTool < Tool
#     include Smolagents::Concerns::Api
#     include Smolagents::Concerns::Formatting
#   end
#
# @example Using individual concerns
#   class MyAgent
#     include Smolagents::Concerns::ReActLoop
#     include Smolagents::Concerns::Resilience
#   end
module Smolagents
  module Concerns
  end
end

# Core infrastructure
require_relative "concerns/resilience"
require_relative "concerns/monitoring"
require_relative "concerns/sandbox"
require_relative "concerns/execution"
require_relative "concerns/parsing"
require_relative "concerns/formatting"
require_relative "concerns/support"

# Domain-specific groups
require_relative "concerns/api"
require_relative "concerns/agents"
require_relative "concerns/models"
require_relative "concerns/tools"
