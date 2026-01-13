module Smolagents
  module Concerns
    # Adds timing measurement capabilities to any class.
    #
    # Provides a consistent way to measure execution time using
    # Process.clock_gettime(Process::CLOCK_MONOTONIC) for accurate,
    # monotonic timing that isn't affected by system clock changes.
    #
    # @example Basic timing
    #   class MyService
    #     include Concerns::Measurable
    #
    #     def expensive_operation
    #       result, duration = measure_time { do_work }
    #       puts "Completed in #{duration}s"
    #       result
    #     end
    #   end
    #
    # @example With milliseconds
    #   result, duration_ms = measure_time(unit: :milliseconds) { api_call }
    #   log("API call took #{duration_ms}ms")
    #
    # @example Using TimingResult for structured data
    #   timing = measure_timed { complex_operation }
    #   puts timing.duration_ms  # 1234.56
    #   puts timing.success?     # true
    #
    module Measurable
      # Timing result with value, duration, and metadata (immutable Data class)
      TimingResult = Data.define(:value, :duration, :unit, :error) do
        def success? = error.nil?
        def failed? = !success?

        def duration_ms
          case unit
          when :milliseconds then duration
          when :seconds then duration * 1000
          end
        end

        def duration_s
          case unit
          when :seconds then duration
          when :milliseconds then duration / 1000.0
          end
        end

        def to_h
          { value:, duration:, unit:, error: error&.message, success: success? }
        end
      end

      # Measures execution time of a block.
      #
      # @param unit [Symbol] Time unit (:seconds or :milliseconds)
      # @yield Block to measure
      # @return [Array(Object, Float)] Result and duration
      #
      # @example
      #   result, duration = measure_time { expensive_work }
      #   result, duration_ms = measure_time(unit: :milliseconds) { api_call }
      def measure_time(unit: :seconds)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        duration = unit == :milliseconds ? (elapsed * 1000).round(2) : elapsed

        [result, duration]
      end

      # Measures execution time and returns a TimingResult.
      #
      # Captures both successful results and exceptions, allowing
      # callers to inspect timing even when operations fail.
      #
      # @param unit [Symbol] Time unit (:seconds or :milliseconds)
      # @yield Block to measure
      # @return [TimingResult] Structured result with timing data
      #
      # @example
      #   timing = measure_timed { api_call }
      #   if timing.success?
      #     process(timing.value)
      #   else
      #     handle_error(timing.error)
      #   end
      def measure_timed(unit: :seconds)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          result = yield
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
          duration = unit == :milliseconds ? (elapsed * 1000).round(2) : elapsed

          TimingResult.new(value: result, duration:, unit:, error: nil)
        rescue StandardError => e
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
          duration = unit == :milliseconds ? (elapsed * 1000).round(2) : elapsed

          TimingResult.new(value: nil, duration:, unit:, error: e)
        end
      end
    end
  end
end
