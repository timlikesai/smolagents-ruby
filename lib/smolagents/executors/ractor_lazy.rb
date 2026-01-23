# Fiber-based lazy execution for Ractor with automatic tool batching.
#
# Tool calls return futures immediately. When results are accessed,
# all pending futures are batched and yielded for parallel execution.
#
# @example Inside Ractor
#   @a = search(query: "ruby")   # Returns future instantly
#   @b = search(query: "python") # Returns future instantly
#   @a.first                     # Triggers batch - both resolve in parallel
#
# Architecture:
#   - ToolFuture: Lazy proxy that yields on access (BasicObject subclass)
#   - Context: Builds sandboxed execution environment with lazy tools
#   - FutureResolution: Helpers for detecting and unwrapping futures
#   - BatchHandling: Wave-based resolution for dependent futures
#   - FiberExecutor: Runs code in Fiber, handles batch yields
#
require_relative "ractor_lazy/tool_future"
require_relative "ractor_lazy/context"
require_relative "ractor_lazy/future_resolution"
require_relative "ractor_lazy/batch_handling"
require_relative "ractor_lazy/fiber_executor"
