module Smolagents
  module Concerns
    module RateLimiter
      # Callback registration for rate limit events.
      module Callbacks
        def self.included(base)
          base.prepend(Initializer)
        end

        # Prepended to ensure callbacks array is initialized.
        module Initializer
          def initialize(**)
            super
            @rate_limit_callbacks = []
          end
        end

        # Register callback for rate limit events.
        # @yield [retry_after] Called when rate limit is exceeded
        # @return [self] For chaining
        def on_rate_limited(&block)
          @rate_limit_callbacks << block
          self
        end

        private

        def notify_rate_limited(retry_after)
          @rate_limit_callbacks&.each { |cb| cb.call(retry_after) }
        end
      end
    end
  end
end
