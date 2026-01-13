# Module containing reusable mixins and behaviors for agent components.
#
# The Concerns module provides a collection of mixins that encapsulate
# cross-cutting concerns: HTTP access, rate limiting, API key handling,
# result formatting, tool schema management, monitoring, auditing, resilience
# patterns, step execution, code execution, and browser automation.
#
# Each concern is a module that can be included in agent classes to add
# specific capabilities without mixing concerns in the agent implementation.
#
# == Available Concerns
#
# - {Http} - HTTP client functionality and request handling
# - {RateLimiter} - Request rate limiting and throttling
# - {ApiKey} - API key management and validation
# - {Json} - JSON parsing and generation
# - {Html} - HTML parsing and extraction
# - {Xml} - XML parsing and extraction
# - {Results} - Result formatting and transformation
# - {GemLoader} - Dynamic gem loading
# - {ToolSchema} - Tool schema validation and generation
# - {MessageFormatting} - Chat message formatting
# - {Monitorable} - Monitoring and metrics collection
# - {Auditable} - Audit logging
# - {CircuitBreaker} - Fault tolerance via circuit breaker pattern
# - {Retryable} - Automatic retry logic with backoff
# - {Resilience} - Combined resilience patterns
# - {Api} - API client base functionality
# - {StepExecution} - Agent step execution
# - {RubySafety} - Ruby code safety validation
# - {SandboxMethods} - Sandbox method injection
# - {ReactLoop} - ReAct loop implementation
# - {Planning} - Agent planning
# - {ToolExecution} - Tool invocation
# - {AsyncTools} - Asynchronous tool support
# - {ManagedAgents} - Sub-agent management
# - {CodeExecution} - Code execution coordination
# - {Mcp} - Model Context Protocol support
# - {Browser} - Browser automation
# - {Specialized} - Specialized agent behaviors
# - {ModelHealth} - Model health monitoring
# - {ModelReliability} - Model reliability management
# - {RequestQueue} - Request queuing
#
# @example Using a mixin
#   class MyAgent
#     include Smolagents::Concerns::Retryable
#     include Smolagents::Concerns::Auditable
#   end
#
# @example With the :Http concern
#   class ApiClient
#     include Smolagents::Concerns::Http
#   end
#   client = ApiClient.new
#   response = client.get("https://api.example.com/data")
#
# @see Concerns::Http For HTTP client functionality
# @see Concerns::Retryable For automatic retry logic
# @see Concerns::Auditable For audit logging
# @see Concerns::CircuitBreaker For fault tolerance
module Smolagents
  module Concerns
  end
end

require_relative "concerns/http"
require_relative "concerns/rate_limiter"
require_relative "concerns/api_key"
require_relative "concerns/json"
require_relative "concerns/html"
require_relative "concerns/xml"
require_relative "concerns/results"
require_relative "concerns/gem_loader"
require_relative "concerns/tool_schema"
require_relative "concerns/message_formatting"
require_relative "concerns/monitorable"
require_relative "concerns/auditable"
require_relative "concerns/circuit_breaker"
require_relative "concerns/retryable"
require_relative "concerns/resilience"
require_relative "concerns/api"
require_relative "concerns/step_execution"
require_relative "concerns/ruby_safety"
require_relative "concerns/sandbox_methods"
require_relative "concerns/react_loop"
require_relative "concerns/planning"
require_relative "concerns/tool_execution"
require_relative "concerns/async_tools"
require_relative "concerns/managed_agents"
require_relative "concerns/code_execution"
require_relative "concerns/mcp"
require_relative "concerns/browser"
require_relative "concerns/specialized"
require_relative "concerns/model_health"
require_relative "concerns/model_reliability"
require_relative "concerns/request_queue"
