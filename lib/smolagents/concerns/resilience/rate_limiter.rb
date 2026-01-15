module Smolagents
  module Concerns
    # Event-driven rate limiting for tools that call external APIs.
    #
    # Uses a non-blocking pattern: checks if a request is allowed, and if not,
    # raises RateLimitExceeded with retry_after information. Callers can handle
    # this via callbacks, request queues, or other event-driven mechanisms.
    #
    # @example Declarative rate limiting with DSL
    #   class MyApiTool < Tool
    #     include Concerns::RateLimiter
    #
    #     # Allow 1 request per second
    #     rate_limit 1.0
    #
    #     def execute(query:)
    #       enforce_rate_limit!  # Raises RateLimitExceeded if too soon
    #       # ... make API call
    #     end
    #   end
    #
    # @example Handling rate limits with callbacks
    #   tool.on_rate_limited do |retry_after|
    #     scheduler.schedule_after(retry_after) { tool.call(query:) }
    #   end
    #
    # @example Check before calling (non-raising)
    #   if tool.rate_limit_ok?
    #     tool.call(query:)
    #   else
    #     queue.push(-> { tool.call(query:) }, delay: tool.retry_after)
    #   end
    #
    # @see SearchTool Which automatically configures rate limiting
    # @see RequestQueue For queuing rate-limited requests
    module RateLimiter
      # Raised when rate limit would be exceeded.
      # Contains retry_after to enable event-driven scheduling.
      class RateLimitExceeded < StandardError
        attr_reader :retry_after, :tool_name

        def initialize(retry_after:, tool_name: nil)
          @retry_after = retry_after
          @tool_name = tool_name
          super("Rate limit exceeded. Retry after #{retry_after.round(3)}s")
        end
      end

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
        # Configures how many requests per second are allowed.
        # Instances initialized without explicit rate_limit use this default.
        #
        # @param limit [Float] Requests per second (e.g., 1.0 for 1 req/sec, 0.5 for 1 per 2 seconds)
        # @return [Float] The rate limit
        #
        # @example Configuring for a search tool
        #   class MyApiTool < Tool
        #     include Concerns::RateLimiter
        #     rate_limit 2.0  # 2 requests per second
        #   end
        #
        # @example Slow API with 1 request per 10 seconds
        #   class SlowApiTool < Tool
        #     include Concerns::RateLimiter
        #     rate_limit 0.1  # 1 request per 10 seconds
        #   end
        def rate_limit(limit)
          @default_rate_limit = limit
        end
      end

      # Initialize rate limiting from class default.
      def initialize(**)
        super
        setup_rate_limiter(self.class.default_rate_limit)
        @rate_limit_callbacks = []
      end

      # Configure rate limiting for this instance.
      # @param rate_limit [Float, nil] Requests per second (nil to disable)
      def setup_rate_limiter(rate_limit)
        @rate_limit = rate_limit
        @min_interval = rate_limit ? 1.0 / rate_limit : 0.0
        @last_request_time = 0.0
      end

      # Register callback for rate limit events.
      # @yield [retry_after] Called when rate limit is exceeded
      # @return [self] For chaining
      def on_rate_limited(&block)
        @rate_limit_callbacks << block
        self
      end

      # Check if a request is allowed without raising.
      # @return [Boolean] true if request can proceed
      def rate_limit_ok?
        return true unless @rate_limit

        elapsed = Time.now.to_f - @last_request_time
        elapsed >= @min_interval
      end

      # Get time until next request is allowed.
      # @return [Float] Seconds to wait (0.0 if ready now)
      def retry_after
        return 0.0 unless @rate_limit

        elapsed = Time.now.to_f - @last_request_time
        remaining = @min_interval - elapsed
        remaining.positive? ? remaining : 0.0
      end

      # Enforce rate limit (non-blocking).
      # Raises RateLimitExceeded if called too soon, allowing event-driven handling.
      # @raise [RateLimitExceeded] If rate limit would be exceeded
      # @return [void]
      def enforce_rate_limit!
        return mark_request! unless @rate_limit && (wait_time = time_until_allowed).positive?

        notify_rate_limited(wait_time)
        raise RateLimitExceeded.new(retry_after: wait_time, tool_name: rate_limit_tool_name)
      end

      def time_until_allowed
        [@min_interval - (Time.now.to_f - @last_request_time), 0].max
      end

      def rate_limit_tool_name = respond_to?(:name) ? name : self.class.name

      # Mark that a request was made (for manual tracking).
      # @return [void]
      def mark_request!
        @last_request_time = Time.now.to_f
      end

      # Create a rate limit event for the Events system.
      # Use this for event-driven rate limit handling instead of exceptions.
      #
      # @param original_request [Object, nil] The original request to retry
      # @return [Events::RateLimitHit] Event for scheduling
      #
      # @example Event-driven rate limit handling
      #   unless tool.rate_limit_ok?
      #     event = tool.rate_limit_event(original_request: request)
      #     event_queue.push(event, priority: :scheduled)
      #     return [:rate_limited, event]
      #   end
      #
      def rate_limit_event(original_request: nil)
        Events::RateLimitHit.create(
          tool_name: respond_to?(:name) ? name : self.class.name,
          retry_after:,
          original_request:
        )
      end

      # Execute block with rate limit check, returning event-based result.
      # This is the preferred event-driven alternative to enforce_rate_limit!.
      #
      # @yield Block to execute if rate limit allows
      # @return [Array] [:success, result] or [:rate_limited, event]
      #
      # @example
      #   case with_rate_limit { api_call }
      #   in [:success, result] then handle_result(result)
      #   in [:rate_limited, event] then schedule_retry(event)
      #   end
      #
      def with_rate_limit(original_request: nil)
        unless rate_limit_ok?
          event = rate_limit_event(original_request:)
          notify_rate_limited(event.retry_after)
          return [:rate_limited, event]
        end

        mark_request!
        [:success, yield]
      end

      private

      def notify_rate_limited(retry_after)
        @rate_limit_callbacks&.each { |cb| cb.call(retry_after) }
      end
    end
  end
end
