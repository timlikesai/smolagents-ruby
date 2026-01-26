module Smolagents
  module Concerns
    module Reliability
      # Retry configuration for model reliability.
      #
      # Provides methods to configure retry behavior including max attempts,
      # backoff strategy, and retryable error types.
      #
      # @example Configure retry
      #   model.with_retry(max_attempts: 5, backoff: :exponential)
      module Configuration
        def self.included(base)
          base.extend(ClassMethods) unless base.singleton_class.include?(ClassMethods)
        end

        module ClassMethods
          # Set or get the default retry policy for this model class.
          #
          # @param policy [RetryPolicy, nil] Policy to set (or nil to get current)
          # @return [RetryPolicy] Current or default policy
          def default_retry_policy(policy = nil)
            @default_retry_policy = policy if policy
            @default_retry_policy || Types::RetryPolicy.default
          end
        end

        # Configure retry behavior or execute a block with retry.
        #
        # This method handles two distinct use cases:
        # 1. Configuration: When called without a block, configures retry policy
        # 2. Execution: When called with a block and policy:, executes with retry
        #
        # @overload with_retry(max_attempts:, base_interval:, max_interval:, backoff:, jitter:, on:)
        #   Configure retry behavior. Returns self for chaining.
        #   @param max_attempts [Integer, nil] Total attempts before giving up
        #   @param base_interval [Float, nil] Base delay between retries (seconds)
        #   @param max_interval [Float, nil] Maximum delay cap (seconds)
        #   @param backoff [Symbol, nil] Backoff strategy (:exponential, :linear, :constant)
        #   @param jitter [Float, nil] Random jitter factor (0.0-1.0)
        #   @param on [Array<Class>, nil] Error classes to retry
        #   @return [self] For chaining
        #
        # @overload with_retry(policy:, &block)
        #   Execute a block with retry using the given policy.
        #   @param policy [RetryPolicy] Retry policy to use
        #   @yield Block to execute with retry
        #   @return [Object] Result of the block
        def with_retry(policy: nil, max_attempts: nil, base_interval: nil, max_interval: nil,
                       backoff: nil, jitter: nil, on: nil, &block)
          # Execution mode: when block and policy provided, delegate to Retryable
          return Concerns::Retryable.instance_method(:with_retry).bind_call(self, policy:, &block) if block && policy

          # Configuration mode: update retry policy settings
          opts = { max_attempts:, base_interval:, max_interval:, backoff:, jitter:, retryable_errors: on }.compact
          base_opts = (@retry_policy || default_policy).to_h
          @retry_policy = Types::RetryPolicy.new(**base_opts, **opts)
          self
        end

        # Reset all reliability configuration.
        #
        # Clears retry policy, fallback chain, health routing, and handlers.
        #
        # @return [self] For chaining
        def reset_reliability
          @retry_policy = nil
          clear_fallbacks
          clear_health_routing
          clear_handlers
          self
        end

        # Get current reliability configuration as a Hash.
        #
        # @return [Hash] Configuration including retry_policy, fallback_count, etc.
        def reliability_config
          {
            retry_policy: @retry_policy || Types::RetryPolicy.default,
            fallback_count:,
            prefer_healthy: prefer_healthy?,
            health_cache_duration:
          }
        end

        private

        def default_policy
          self.class.respond_to?(:default_retry_policy) ? self.class.default_retry_policy : Types::RetryPolicy.default
        end

        def retry_policy = @retry_policy
      end
    end
  end
end
