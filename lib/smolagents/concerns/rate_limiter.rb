module Smolagents
  module Concerns
    # Rate limiting for tools that call external APIs.
    #
    # Provides declarative rate limiting via a class-level DSL and
    # instance methods for enforcement. Useful for avoiding API
    # rate limits and being a good API citizen.
    #
    # @example Declarative rate limiting with DSL
    #   class MyApiTool < Tool
    #     include Concerns::RateLimiter
    #
    #     # Allow 1 request per second
    #     rate_limit 1.0
    #
    #     def execute(query:)
    #       enforce_rate_limit!
    #       # ... make API call
    #     end
    #   end
    #
    # @example Custom rate limiting in SearchTool DSL
    #   class SlowApiTool < SearchTool
    #     configure do
    #       name "slow_api"
    #       rate_limit 0.5  # 1 request per 2 seconds
    #       # ...
    #     end
    #   end
    #
    # @example Manual rate limiter setup
    #   class DynamicTool < Tool
    #     include Concerns::RateLimiter
    #
    #     def initialize(requests_per_second: 2.0, **)
    #       super()
    #       setup_rate_limiter(requests_per_second)
    #     end
    #   end
    #
    # @see SearchTool Which automatically configures rate limiting
    # @see DuckDuckGoSearchTool Example with 1 req/sec rate limit
    # @see BraveSearchTool Example with API rate limit
    module RateLimiter
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # @return [Float, nil] The configured default rate limit
        attr_reader :default_rate_limit

        # Set the default rate limit for all instances.
        # @param limit [Float] Requests per second (e.g., 1.0 for 1 req/sec)
        def rate_limit(limit)
          @default_rate_limit = limit
        end
      end

      # Initialize rate limiting from class default.
      # Called automatically when including this concern.
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

      # Enforce rate limit by sleeping if necessary.
      # Call this before each external request.
      # @return [void]
      def enforce_rate_limit!
        return unless @rate_limit

        elapsed = Time.now.to_f - @last_request_time
        sleep(@min_interval - elapsed) if elapsed < @min_interval
        @last_request_time = Time.now.to_f
      end
    end
  end
end
