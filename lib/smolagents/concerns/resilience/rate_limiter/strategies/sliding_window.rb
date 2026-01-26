module Smolagents
  module Concerns
    module RateLimiter
      module Strategies
        # Sliding window rate limiting strategy.
        #
        # Tracks timestamps of recent requests and counts how many fall within
        # the sliding window. More accurate than fixed window but uses more memory.
        #
        # @example
        #   window = SlidingWindow.new(rate: 2.0, burst: 4)
        #   4.times { window.acquire! }  # All succeed
        #   window.allow?                #=> false
        #   sleep window.window_size     # Wait for window to slide
        #   window.allow?                #=> true
        class SlidingWindow < Base
          attr_reader :timestamps

          def initialize(rate:, burst:)
            super
            @timestamps = []
            @mutex = Mutex.new
          end

          def allow?
            @mutex.synchronize do
              prune_timestamps
              @timestamps.size < burst
            end
          end

          def acquire!
            @mutex.synchronize do
              prune_timestamps
              return false if @timestamps.size >= burst

              @timestamps << Time.now.to_f
              true
            end
          end

          def retry_after
            @mutex.synchronize do
              prune_timestamps
              return 0.0 if @timestamps.size < burst

              oldest = @timestamps.first
              (oldest + window_size) - Time.now.to_f
            end
          end

          def reset!
            @mutex.synchronize { @timestamps.clear }
          end

          private

          def prune_timestamps
            cutoff = Time.now.to_f - window_size
            @timestamps.reject! { |ts| ts < cutoff }
          end
        end
      end
    end
  end
end
