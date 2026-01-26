module Smolagents
  module Types
    module Isolation
      # Metrics captured during isolated tool execution.
      #
      # Tracks actual resource consumption during execution for monitoring,
      # logging, and limit enforcement. Compare against ResourceLimits to
      # detect violations.
      #
      # @example Checking limit compliance
      #   limits = ResourceLimits.default
      #   metrics = ResourceMetrics.new(
      #     duration_ms: 1500,
      #     memory_bytes: 10_000_000,
      #     output_bytes: 1024
      #   )
      #   metrics.within_limits?(limits)  # => true
      #
      # @example Creating from timing
      #   start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      #   # ... execution ...
      #   duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).to_i
      #   metrics = ResourceMetrics.new(duration_ms:, memory_bytes: 0, output_bytes: result.bytesize)
      #
      # @see ResourceLimits For limit definitions
      # @see IsolationResult For complete execution results
      ResourceMetrics = Data.define(:duration_ms, :memory_bytes, :output_bytes) do
        include TypeSupport::Deconstructable

        # Creates metrics representing zero resource usage.
        #
        # @return [ResourceMetrics] Empty metrics
        def self.zero
          new(duration_ms: 0, memory_bytes: 0, output_bytes: 0)
        end

        # Creates metrics with only duration.
        #
        # @param duration [Integer] Duration in milliseconds
        # @return [ResourceMetrics] Metrics with duration, zero memory/output
        def self.with_duration(duration)
          new(duration_ms: duration, memory_bytes: 0, output_bytes: 0)
        end

        # Checks if all metrics are within specified limits.
        #
        # @param limits [ResourceLimits] Limits to compare against
        # @return [Boolean] True if all metrics within limits
        def within_limits?(limits)
          duration_within?(limits) && memory_within?(limits) && output_within?(limits)
        end

        # Checks if duration is within timeout limit.
        #
        # @param limits [ResourceLimits] Limits to compare against
        # @return [Boolean] True if duration within timeout
        def duration_within?(limits) = duration_ms <= (limits.timeout_seconds * 1000)

        # Checks if memory usage is within limit.
        #
        # @param limits [ResourceLimits] Limits to compare against
        # @return [Boolean] True if memory within limit
        def memory_within?(limits) = memory_bytes <= limits.max_memory_bytes

        # Checks if output size is within limit.
        #
        # @param limits [ResourceLimits] Limits to compare against
        # @return [Boolean] True if output within limit
        def output_within?(limits) = output_bytes <= limits.max_output_bytes

        # Returns duration in seconds.
        #
        # @return [Float] Duration in seconds
        def duration_seconds = duration_ms / 1000.0

        # Converts to hash for serialization.
        #
        # @return [Hash] Hash with all metric fields
        def to_h = { duration_ms:, memory_bytes:, output_bytes: }
      end
    end
  end
end
