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

    # @return [Array<Symbol>] Valid rate limiting strategies: token_bucket, sliding_window, fixed_window
    RATE_LIMIT_STRATEGIES = %i[token_bucket sliding_window fixed_window].freeze
    # @return [Array<Symbol>] Valid rate limiting scopes: tool, global, request
    RATE_LIMIT_SCOPES = %i[tool global request].freeze

    RateLimitPolicy = Data.define(:requests_per_second, :burst_size, :strategy, :scope) do
      # Returns default rate limiting policy (1 req/s, 3 burst, token bucket, tool-scoped).
      #
      # @return [RateLimitPolicy]
      def self.default
        new(requests_per_second: 1.0, burst_size: 3, strategy: :token_bucket, scope: :tool)
      end

      # Returns strict rate limiting policy (0.5 req/s, 1 burst, fixed window, tool-scoped).
      #
      # @return [RateLimitPolicy]
      def self.strict
        new(requests_per_second: 0.5, burst_size: 1, strategy: :fixed_window, scope: :tool)
      end

      # Returns permissive rate limiting policy (10 req/s, 20 burst, token bucket, global-scoped).
      #
      # @return [RateLimitPolicy]
      def self.permissive
        new(requests_per_second: 10.0, burst_size: 20, strategy: :token_bucket, scope: :global)
      end

      # Returns unlimited policy (rate limiting disabled).
      #
      # @return [RateLimitPolicy]
      def self.unlimited
        new(requests_per_second: nil, burst_size: nil, strategy: nil, scope: nil)
      end

      # Checks if rate limiting is enabled.
      #
      # @return [Boolean] True if requests_per_second is set
      def enabled? = !requests_per_second.nil?

      # @return [Boolean] True if strategy is token_bucket
      def token_bucket? = strategy == :token_bucket
      # @return [Boolean] True if strategy is sliding_window
      def sliding_window? = strategy == :sliding_window
      # @return [Boolean] True if strategy is fixed_window
      def fixed_window? = strategy == :fixed_window

      # @return [Boolean] True if scope is tool
      def tool_scoped? = scope == :tool
      # @return [Boolean] True if scope is global
      def global_scoped? = scope == :global
      # @return [Boolean] True if scope is request
      def request_scoped? = scope == :request

      # Returns minimum interval between requests in seconds.
      #
      # @return [Float] Minimum interval (0.0 if unlimited)
      def min_interval
        return 0.0 unless enabled?

        1.0 / requests_per_second
      end

      # Creates a new policy with overridden fields.
      #
      # @param overrides [Hash] Field overrides
      # @return [RateLimitPolicy]
      def merge(overrides = {})
        with(**overrides)
      end

      # Validates policy configuration.
      #
      # @return [RateLimitPolicy] Self if valid
      # @raise [ArgumentError] If requests_per_second, burst_size, strategy, or scope invalid
      def validate!
        return self unless enabled?

        validate_requests_per_second!
        validate_burst_size!
        validate_strategy!
        validate_scope!
        self
      end

      # @return [Hash] Pattern matching keys
      def deconstruct_keys(_) = { requests_per_second:, burst_size:, strategy:, scope: }

      private

      # Validates requests_per_second is positive.
      #
      # @raise [ArgumentError] If not positive number
      def validate_requests_per_second!
        return if requests_per_second.nil?
        return if requests_per_second.is_a?(Numeric) && requests_per_second.positive?

        raise ArgumentError, "requests_per_second must be positive"
      end

      # Validates burst_size is positive integer.
      #
      # @raise [ArgumentError] If not positive integer
      def validate_burst_size!
        return if burst_size.nil?
        return if burst_size.is_a?(Integer) && burst_size.positive?

        raise ArgumentError, "burst_size must be a positive integer"
      end

      # Validates strategy is in allowed list.
      #
      # @raise [ArgumentError] If not in RATE_LIMIT_STRATEGIES
      def validate_strategy!
        return if strategy.nil?
        return if RATE_LIMIT_STRATEGIES.include?(strategy)

        raise ArgumentError, "strategy must be one of: #{RATE_LIMIT_STRATEGIES.join(", ")}"
      end

      # Validates scope is in allowed list.
      #
      # @raise [ArgumentError] If not in RATE_LIMIT_SCOPES
      def validate_scope!
        return if scope.nil?
        return if RATE_LIMIT_SCOPES.include?(scope)

        raise ArgumentError, "scope must be one of: #{RATE_LIMIT_SCOPES.join(", ")}"
      end
    end
  end
end
