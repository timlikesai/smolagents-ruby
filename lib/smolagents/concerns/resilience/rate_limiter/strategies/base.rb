module Smolagents
  module Concerns
    module RateLimiter
      module Strategies
        # Base class for rate limiting strategies.
        #
        # All strategies implement the same interface:
        # - +allow?+ - Check if request would be allowed (non-mutating)
        # - +acquire!+ - Attempt to acquire permission (mutating)
        # - +retry_after+ - Seconds until next request allowed
        # - +reset!+ - Reset strategy state
        #
        # @abstract Subclass and implement {#allow?}, {#acquire!}, {#retry_after}, {#reset!}
        class Base
          attr_reader :rate, :burst

          def initialize(rate:, burst:)
            @rate = rate
            @burst = burst
          end

          def allow?
            raise NotImplementedError, "#{self.class} must implement #allow?"
          end

          def acquire!
            raise NotImplementedError, "#{self.class} must implement #acquire!"
          end

          def retry_after
            raise NotImplementedError, "#{self.class} must implement #retry_after"
          end

          def reset!
            raise NotImplementedError, "#{self.class} must implement #reset!"
          end

          def window_size = burst.to_f / rate
        end
      end
    end
  end
end
