module Smolagents
  module Concerns
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
    end
  end
end
