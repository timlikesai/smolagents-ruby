require_relative "isolation/fiber_executor"
require_relative "isolation/thread_executor"
require_relative "isolation/tool_isolation"
require_relative "isolation/violation_info_builder"

module Smolagents
  module Concerns
    # Execution isolation concerns for running code and tools safely.
    #
    # Provides fiber and thread-based execution strategies with resource
    # monitoring and violation detection.
    #
    # == Sub-Modules
    #
    #   FiberExecutor
    #       Execute code in fiber context with yielding support
    #
    #   ThreadExecutor
    #       Execute code in thread context with timeout support
    #
    #   ToolIsolation
    #       Run tool execution in isolated context
    #
    #   ViolationInfoBuilder
    #       Build structured information about resource violations
    #
    # @see FiberExecutor For fiber-based execution
    # @see ThreadExecutor For thread-based execution
    # @see ToolIsolation For isolated tool execution
    module Isolation
    end
  end
end
