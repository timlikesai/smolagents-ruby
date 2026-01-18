module Smolagents
  module Concerns
    module RateLimiter
      module Strategies
        # Token bucket rate limiting strategy.
        #
        # Tokens are added at a fixed rate up to a maximum burst capacity.
        # Each request consumes one token. Allows bursting while maintaining
        # average rate over time.
        #
        # @example
        #   bucket = TokenBucket.new(rate: 10.0, burst: 5)
        #   5.times { bucket.acquire! }  # All succeed (uses burst)
        #   bucket.allow?                #=> false (bucket empty)
        #   sleep 0.1                    # Wait for 1 token to refill
        #   bucket.allow?                #=> true
        class TokenBucket < Base
          attr_reader :tokens

          def initialize(rate:, burst:)
            super
            @tokens = burst.to_f
            @last_refill = Time.now.to_f
            @mutex = Mutex.new
          end

          def allow?
            @mutex.synchronize do
              refill_tokens
              @tokens >= 1.0
            end
          end

          def acquire!
            @mutex.synchronize do
              refill_tokens
              return false if @tokens < 1.0

              @tokens -= 1.0
              true
            end
          end

          def retry_after
            @mutex.synchronize do
              refill_tokens
              return 0.0 if @tokens >= 1.0

              (1.0 - @tokens) / rate
            end
          end

          def reset!
            @mutex.synchronize do
              @tokens = burst.to_f
              @last_refill = Time.now.to_f
            end
          end

          private

          def refill_tokens
            now = Time.now.to_f
            elapsed = now - @last_refill
            @tokens = [burst.to_f, @tokens + (elapsed * rate)].min
            @last_refill = now
          end
        end
      end
    end
  end
end
