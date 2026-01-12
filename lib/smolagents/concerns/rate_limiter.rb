module Smolagents
  module Concerns
    module RateLimiter
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        attr_reader :default_rate_limit

        def rate_limit(limit)
          @default_rate_limit = limit
        end
      end

      def initialize(**)
        super
        setup_rate_limiter(self.class.default_rate_limit)
      end

      def setup_rate_limiter(rate_limit)
        @rate_limit = rate_limit
        @min_interval = rate_limit ? 1.0 / rate_limit : 0.0
        @last_request_time = 0.0
      end

      def enforce_rate_limit!
        return unless @rate_limit

        elapsed = Time.now.to_f - @last_request_time
        sleep(@min_interval - elapsed) if elapsed < @min_interval
        @last_request_time = Time.now.to_f
      end
    end
  end
end
