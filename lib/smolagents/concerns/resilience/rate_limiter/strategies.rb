require_relative "strategies/base"
require_relative "strategies/token_bucket"
require_relative "strategies/sliding_window"
require_relative "strategies/fixed_window"

module Smolagents
  module Concerns
    module RateLimiter
      # Factory for rate limiting strategy implementations.
      #
      # Creates the appropriate strategy instance based on policy configuration.
      # Each strategy implements the same interface: allow?, acquire!, retry_after, reset!
      #
      # @example Creating a strategy from policy
      #   strategy = Strategies.for_policy(policy)
      #   strategy.acquire!  # true if allowed
      #
      # @example Creating a strategy by name
      #   bucket = Strategies.create(:token_bucket, rate: 10.0, burst: 5)
      #   bucket.allow?  #=> true
      module Strategies
        REGISTRY = {
          token_bucket: ->(rate:, burst:) { TokenBucket.new(rate:, burst:) },
          sliding_window: ->(rate:, burst:) { SlidingWindow.new(rate:, burst:) },
          fixed_window: ->(rate:, burst:) { FixedWindow.new(rate:, burst:) }
        }.freeze

        def self.for_policy(policy)
          return nil unless policy.enabled?

          factory = REGISTRY[policy.strategy]
          raise ArgumentError, "Unknown strategy: #{policy.strategy}" unless factory

          factory.call(rate: policy.requests_per_second, burst: policy.burst_size)
        end

        def self.create(name, rate:, burst:)
          factory = REGISTRY[name]
          raise ArgumentError, "Unknown strategy: #{name}" unless factory

          factory.call(rate:, burst:)
        end
      end
    end
  end
end
