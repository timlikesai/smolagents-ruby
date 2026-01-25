# Fiber-based lazy execution for Ractor sandboxed code.
#
# This module provides the INNER execution model for agent-generated Ruby code
# running inside Ractor isolation. It's distinct from the OUTER orchestration
# system in Executors::ToolFuture/FutureBatch/BatchYield.
#
# == Two Future Systems
#
# The codebase has two "future" implementations serving different layers:
#
# 1. Executors::ToolFuture (outer) - Orchestrator-level batching:
#    - TrackedToolProxy creates these for real tool calls
#    - Uses thread-local FutureBatch for batch tracking
#    - Yields BatchYield objects when resolution needed
#
# 2. RactorLazy::ToolFuture (inner) - Sandboxed code execution:
#    - Agent code inside Ractor gets these from tool calls
#    - Uses instance @batch arrays (Ractor-safe, no thread-local)
#    - Fiber.yield({type: :batch, futures:}) for resolution
#    - Has ES6 Promise combinators (Future.all, race, any, all_settled)
#
# @example Inside Ractor sandbox
#   @a = search(query: "ruby")   # Returns RactorLazy::ToolFuture instantly
#   @b = search(query: "python") # Returns RactorLazy::ToolFuture instantly
#   @a.first                     # Triggers Fiber.yield - both resolve in parallel
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
