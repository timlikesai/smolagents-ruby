module Smolagents
  module Concerns
    module RateLimiter
      module Strategies
        # Fixed window rate limiting strategy.
        #
        # Counts requests within fixed time windows. Simple and efficient but
        # can allow burst of 2x limit at window boundaries.
        #
        # @example
        #   window = FixedWindow.new(rate: 2.0, burst: 4)
        #   4.times { window.acquire! }  # All succeed
        #   window.allow?                #=> false
        #   # Wait for window to expire...
        #   window.allow?                #=> true (new window)
        class FixedWindow < Base
          attr_reader :count

          def initialize(rate:, burst:)
            super
            @count = 0
            @window_start = Time.now.to_f
            @mutex = Mutex.new
          end

          def allow?
            @mutex.synchronize do
              maybe_reset_window
              @count < burst
            end
          end

          def acquire!
            @mutex.synchronize do
              maybe_reset_window
              return false if @count >= burst

              @count += 1
              true
            end
          end

          def retry_after
            @mutex.synchronize do
              maybe_reset_window
              return 0.0 if @count < burst

              (@window_start + window_size) - Time.now.to_f
            end
          end

          def reset!
            @mutex.synchronize do
              @count = 0
              @window_start = Time.now.to_f
            end
          end

          private

          def maybe_reset_window
            now = Time.now.to_f
            return unless now >= @window_start + window_size

            @count = 0
            @window_start = now
          end
        end
      end
    end
  end
end
