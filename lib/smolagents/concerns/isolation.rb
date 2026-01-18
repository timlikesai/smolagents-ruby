require_relative "isolation/violation_info_builder"
require_relative "isolation/thread_executor"
require_relative "isolation/fiber_executor"
require_relative "isolation/tool_isolation"

module Smolagents
  module Concerns
    # Resource isolation for sandboxed tool execution.
    #
    # The Isolation module provides concerns for executing tool calls within
    # resource-bounded environments. It enforces timeouts, memory limits,
    # and output size constraints while emitting events for observability.
    #
    # == Components
    #
    # - {ToolIsolation} - Main concern for isolated tool execution
    #
    # == Callback Pattern
    #
    # Following the pattern established by {ToolRetry}, isolation uses
    # caller-controlled callbacks for handling timeouts and violations.
    # This enables integration with event loops, Fibers, or synchronous
    # execution without coupling to a specific concurrency model.
    #
    # == Events Emitted
    #
    # - {Events::ToolIsolationStarted} - When isolation begins
    # - {Events::ToolIsolationCompleted} - When isolation ends (success/failure)
    # - {Events::ResourceViolation} - When a resource limit is exceeded
    #
    # @example Basic usage
    #   class MyTool
    #     include Concerns::Isolation::ToolIsolation
    #
    #     def execute(query:)
    #       with_tool_isolation(tool_name: "my_tool") do
    #         expensive_operation(query)
    #       end
    #     end
    #   end
    #
    # @example With custom limits and callbacks
    #   limits = Types::Isolation::ResourceLimits.new(
    #     timeout_seconds: 30.0,
    #     max_memory_bytes: 100 * 1024 * 1024,
    #     max_output_bytes: 100 * 1024
    #   )
    #
    #   with_tool_isolation(
    #     tool_name: "heavy_compute",
    #     limits: limits,
    #     on_timeout: ->(info) { logger.warn("Timeout: #{info}") },
    #     on_violation: ->(info) { logger.warn("Violation: #{info}") }
    #   ) { heavy_computation }
    #
    # @see Types::Isolation For isolation type definitions
    # @see ToolRetry For the callback pattern reference
    module Isolation
      include ToolIsolation
    end
  end
end
