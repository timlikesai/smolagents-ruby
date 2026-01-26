# Isolation types for sandboxed tool execution.
#
# The Isolation module provides types for managing resource-constrained
# execution of tools in sandboxed environments. It includes:
#
# - {ResourceLimits} - Configuration for execution boundaries
# - {ResourceMetrics} - Captured resource usage during execution
# - {IsolationResult} - Complete execution result with status and metrics
#
# @example Complete isolation workflow
#   limits = Smolagents::Types::Isolation::ResourceLimits.default
#
#   # Execute tool with limits...
#   start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
#   result = execute_sandboxed(tool, limits)
#   duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).to_i
#
#   metrics = Smolagents::Types::Isolation::ResourceMetrics.new(
#     duration_ms:,
#     memory_bytes: 1024,
#     output_bytes: result.bytesize
#   )
#
#   if metrics.within_limits?(limits)
#     Smolagents::Types::Isolation::IsolationResult.success(value: result, metrics:)
#   else
#     Smolagents::Types::Isolation::IsolationResult.violation(metrics:, error: LimitExceeded.new)
#   end
#
# @see Types::Isolation::ResourceLimits
# @see Types::Isolation::ResourceMetrics
# @see Types::Isolation::IsolationResult
module Smolagents
  module Types
    module Isolation
    end
  end
end

require_relative "isolation/resource_limits"
require_relative "isolation/resource_metrics"
require_relative "isolation/isolation_result"
