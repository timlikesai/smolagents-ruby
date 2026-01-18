module Smolagents
  module Concerns
    module RateLimiter
      # Class-level rate limit configuration DSL.
      #
      # @example
      #   class MyTool < Tool
      #     include Concerns::RateLimiter
      #     rate_limit 2.0  # 2 requests per second
      #   end
      module Configuration
        def self.included(base)
          base.extend(ClassMethods)
        end

        # Class-level rate limit configuration
        module ClassMethods
          # Get the configured default rate limit for this class.
          # @return [Float, nil] Requests per second, or nil if not configured
          attr_reader :default_rate_limit

          # Set the default rate limit for all instances of this tool class.
          #
          # @param limit [Float] Requests per second (e.g., 1.0 for 1 req/sec)
          # @return [Float] The rate limit
          def rate_limit(limit)
            @default_rate_limit = limit
          end
        end

        # Initialize rate limiting from class default.
        def initialize(**)
          super
          setup_rate_limiter(self.class.default_rate_limit)
        end

        # Configure rate limiting for this instance.
        # @param rate_limit [Float, nil] Requests per second (nil to disable)
        def setup_rate_limiter(rate_limit)
          @rate_limit = rate_limit
          @min_interval = rate_limit ? 1.0 / rate_limit : 0.0
          @last_request_time = 0.0
        end
      end
    end
  end
end
