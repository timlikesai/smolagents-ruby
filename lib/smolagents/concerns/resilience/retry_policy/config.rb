module Smolagents
  module Concerns
    # Retry policy configuration and defaults.
    #
    # Provides factory methods for creating pre-configured retry policies
    # with sensible defaults for different use cases.
    #
    # @example Accessing defaults
    #   RetryPolicyConfig::DEFAULTS[:max_attempts]
    #   #=> 3
    module RetryPolicyConfig
      # Default retry configuration values
      DEFAULTS = {
        max_attempts: 3,
        base_interval: 1.0,
        max_interval: 30.0,
        backoff: :exponential,
        jitter: 0.5
      }.freeze

      # Aggressive retry configuration for critical operations
      AGGRESSIVE = {
        max_attempts: 5,
        base_interval: 0.5,
        max_interval: 15.0,
        backoff: :exponential,
        jitter: 0.3
      }.freeze

      # Conservative retry configuration for expensive operations
      CONSERVATIVE = {
        max_attempts: 2,
        base_interval: 2.0,
        max_interval: 60.0,
        backoff: :exponential,
        jitter: 1.0
      }.freeze

      class << self
        # Documents methods provided by this module.
        # @return [Hash<Symbol, String>] Method name to description mapping
        def provided_methods
          {
            DEFAULTS: "Default retry configuration values",
            AGGRESSIVE: "Aggressive retry configuration for critical operations",
            CONSERVATIVE: "Conservative retry configuration for expensive operations"
          }
        end
      end
    end
  end
end
