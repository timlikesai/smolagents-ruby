module Smolagents
  module Concerns
    # Monotonic timing helpers for consistent duration measurement.
    #
    # Provides monotonic clock utilities for measuring elapsed time without
    # being affected by system clock changes. Used across concerns for
    # consistent timing behavior.
    #
    # @!group Concern Dependency Graph
    #
    # == Dependency Matrix
    #
    #   | Concern       | Depends On         | Depended By        | Auto-Includes |
    #   |---------------|--------------------|--------------------|---------------|
    #   | TimingHelpers | Process (stdlib)   | StepExecution,     | -             |
    #   |               |                    | Monitorable,       |               |
    #   |               |                    | Auditable          |               |
    #
    # == Methods Provided
    #
    #   TimingHelpers
    #       +-- monotonic_now - Get current monotonic time
    #       +-- elapsed_since(start) - Calculate elapsed seconds
    #       +-- elapsed_ms(start) - Calculate elapsed milliseconds
    #       +-- with_timing(&block) - Execute and return duration
    #       +-- with_timed_result(&block) - Execute and return [result, duration]
    #
    # == No Instance Variables
    #
    # This is a stateless utility module.
    #
    # == Thread Safety
    #
    # All methods are thread-safe as they use CLOCK_MONOTONIC.
    #
    # @!endgroup
    #
    # @example Measuring duration with block
    #   duration = with_timing do
    #     perform_operation
    #   end
    #   puts "Operation took #{duration}s"
    #
    # @example Manual timing
    #   start = monotonic_now
    #   perform_operation
    #   elapsed = elapsed_since(start)
    #
    # @see Types::Timing For immutable timing data type
    module TimingHelpers
      # Get current monotonic clock time.
      #
      # Uses CLOCK_MONOTONIC for consistent duration measurement unaffected
      # by system clock changes.
      #
      # @return [Float] Current monotonic time in seconds
      # @example
      #   start = monotonic_now
      #   # ... work ...
      #   elapsed = monotonic_now - start
      def monotonic_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # Calculate elapsed time in seconds since start.
      #
      # @param start [Float] Start time from monotonic_now
      # @return [Float] Elapsed seconds
      # @example
      #   start = monotonic_now
      #   sleep(0.1)
      #   elapsed_since(start)  # => ~0.1
      def elapsed_since(start) = monotonic_now - start

      # Calculate elapsed time in milliseconds since start.
      #
      # @param start [Float] Start time from monotonic_now
      # @param precision [Integer] Decimal places to round to (default: 2)
      # @return [Float] Elapsed milliseconds
      # @example
      #   start = monotonic_now
      #   sleep(0.1)
      #   elapsed_ms(start)  # => ~100.0
      def elapsed_ms(start, precision: 2) = ((monotonic_now - start) * 1000).round(precision)

      # Execute block and return duration in seconds.
      #
      # @yield Block to time
      # @return [Float] Duration in seconds
      # @example
      #   duration = with_timing { expensive_operation }
      def with_timing
        start = monotonic_now
        yield
        elapsed_since(start)
      end

      # Execute block and return both result and duration.
      #
      # @yield Block to time
      # @return [Array(Object, Float)] [result, duration_in_seconds]
      # @example
      #   result, duration = with_timed_result { compute_value }
      def with_timed_result
        start = monotonic_now
        result = yield
        [result, elapsed_since(start)]
      end
    end
  end
end
