module Smolagents
  module Security
    # Immutable policy defining rate limiting behavior.
    #
    # RateLimitPolicy specifies how requests should be throttled, including
    # the rate, burst capacity, strategy, and scope. Policies are immutable
    # and can be merged to create derived configurations.
    #
    # @example Default rate limiting
    #   policy = RateLimitPolicy.default
    #   policy.requests_per_second  #=> 1.0
    #   policy.enabled?             #=> true
    #
    # @example Strict rate limiting
    #   policy = RateLimitPolicy.strict
    #   policy.requests_per_second  #=> 0.5
    #   policy.strategy             #=> :fixed_window
    #
    # @example Unlimited (disabled)
    #   policy = RateLimitPolicy.unlimited
    #   policy.enabled?  #=> false
    #
    # @see Concerns::RateLimiter For enforcement in tools
    # @see Concerns::RateLimiter::Strategies For strategy implementations

    # Valid rate limiting strategies
    RATE_LIMIT_STRATEGIES = %i[token_bucket sliding_window fixed_window].freeze
    # Valid rate limiting scopes
    RATE_LIMIT_SCOPES = %i[tool global request].freeze

    RateLimitPolicy = Data.define(:requests_per_second, :burst_size, :strategy, :scope) do
      def self.default
        new(requests_per_second: 1.0, burst_size: 3, strategy: :token_bucket, scope: :tool)
      end

      def self.strict
        new(requests_per_second: 0.5, burst_size: 1, strategy: :fixed_window, scope: :tool)
      end

      def self.permissive
        new(requests_per_second: 10.0, burst_size: 20, strategy: :token_bucket, scope: :global)
      end

      def self.unlimited
        new(requests_per_second: nil, burst_size: nil, strategy: nil, scope: nil)
      end

      def enabled? = !requests_per_second.nil?

      def token_bucket? = strategy == :token_bucket
      def sliding_window? = strategy == :sliding_window
      def fixed_window? = strategy == :fixed_window

      def tool_scoped? = scope == :tool
      def global_scoped? = scope == :global
      def request_scoped? = scope == :request

      def min_interval
        return 0.0 unless enabled?

        1.0 / requests_per_second
      end

      def merge(overrides = {})
        with(**overrides)
      end

      def validate!
        return self unless enabled?

        validate_requests_per_second!
        validate_burst_size!
        validate_strategy!
        validate_scope!
        self
      end

      def deconstruct_keys(_) = { requests_per_second:, burst_size:, strategy:, scope: }

      private

      def validate_requests_per_second!
        return if requests_per_second.nil?
        return if requests_per_second.is_a?(Numeric) && requests_per_second.positive?

        raise ArgumentError, "requests_per_second must be positive"
      end

      def validate_burst_size!
        return if burst_size.nil?
        return if burst_size.is_a?(Integer) && burst_size.positive?

        raise ArgumentError, "burst_size must be a positive integer"
      end

      def validate_strategy!
        return if strategy.nil?
        return if RATE_LIMIT_STRATEGIES.include?(strategy)

        raise ArgumentError, "strategy must be one of: #{RATE_LIMIT_STRATEGIES.join(", ")}"
      end

      def validate_scope!
        return if scope.nil?
        return if RATE_LIMIT_SCOPES.include?(scope)

        raise ArgumentError, "scope must be one of: #{RATE_LIMIT_SCOPES.join(", ")}"
      end
    end
  end
end
