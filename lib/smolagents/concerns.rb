# Reusable mixins and behaviors for agent components.
#
# Concerns are composable modules organized by domain. Include them directly.
#
# == Core Concerns
#
# - {Api} - API keys, HTTP, client patterns
# - {Resilience} - Retry, circuit breaker, rate limit
# - {Execution} - Step, code, tool execution
# - {Formatting} - Results and message formatting
#
# == Sub-modules (include directly)
#
# - {Monitorable}, {Auditable} - Observability
# - {RubySafety}, {SandboxMethods} - Code safety
# - {Json}, {Xml}, {Html} - Parsing
# - {ToolIsolation} - Resource isolation
#
# == Registry
#
# All concerns tracked via {Registry} for introspection:
#
#   Smolagents.concerns       #=> [:react_loop, :planning, ...]
#   Smolagents.concern_docs   #=> Markdown documentation
#
# @see Registry For concern metadata
module Smolagents
  module Concerns
  end
end

# Registry for tracking all concerns (load first)
require_relative "concerns/registry"

# Base concern helpers
require_relative "concerns/base_concern"

# Core infrastructure
require_relative "concerns/timing_helpers"
require_relative "concerns/resilience"
require_relative "concerns/execution"
require_relative "concerns/formatting"
require_relative "concerns/support"
require_relative "concerns/validation"

# Monitoring (sub-modules used directly, no facade)
require_relative "concerns/monitoring/monitorable"
require_relative "concerns/monitoring/auditable"

# Sandbox (sub-modules used directly, no facade)
require_relative "concerns/sandbox/ruby_safety"
require_relative "concerns/sandbox/sandbox_methods"

# Parsing (sub-modules used directly, no facade)
require_relative "concerns/parsing/json"
require_relative "concerns/parsing/xml"
require_relative "concerns/parsing/html"
require_relative "concerns/parsing/critique"

# Isolation (sub-modules used directly, no facade)
require_relative "concerns/isolation/violation_info_builder"
require_relative "concerns/isolation/thread_executor"
require_relative "concerns/isolation/fiber_executor"
require_relative "concerns/isolation/tool_isolation"

# Domain-specific groups
require_relative "concerns/api"
require_relative "concerns/agents"
require_relative "concerns/models"
require_relative "concerns/tools"

# Register all concerns (must load after all concern modules)
require_relative "concerns/registrations"
