module Smolagents
  module Concerns
    # Adds reliability constructs for model failover, retry, and routing.
    #
    # This concern provides composable reliability primitives that can be
    # combined to build robust model configurations.
    #
    # @example Fallback chain
    #   model.with_fallback(backup_model)
    #        .with_fallback(emergency_model)
    #
    # @example Retry with custom policy
    #   model.with_retry(max_attempts: 5, backoff: :exponential)
    #
    # @example Health-based routing
    #   model.prefer_healthy
    #        .with_fallback(backup)
    #
    # @example Full reliability stack
    #   model.with_retry(max_attempts: 3)
    #        .with_fallback(backup_model)
    #        .on_failover { |from, to, error| log("Switched: #{from} -> #{to}") }
    #
    module ModelReliability
      # Retry configuration
      RetryPolicy = Data.define(:max_attempts, :base_interval, :max_interval, :backoff, :retryable_errors) do
        def self.default
          new(
            max_attempts: 3,
            base_interval: 1.0,
            max_interval: 30.0,
            backoff: :exponential,
            retryable_errors: [Faraday::Error, Faraday::TimeoutError]
          )
        end

        def multiplier
          case backoff
          when :exponential then 2.0
          when :linear then 1.5
          else 1.0
          end
        end
      end

      # Failover event for callbacks
      FailoverEvent = Data.define(:from_model, :to_model, :error, :attempt, :timestamp) do
        def to_h
          { from: from_model, to: to_model, error: error.message, attempt:, timestamp: timestamp.iso8601 }
        end
      end

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # Default retry policy for all instances
        def default_retry_policy(policy = nil)
          @default_retry_policy = policy if policy
          @default_retry_policy || RetryPolicy.default
        end
      end

      # Configure retry behavior
      #
      # @param max_attempts [Integer] Maximum retry attempts (default: 3)
      # @param base_interval [Float] Initial wait between retries in seconds
      # @param max_interval [Float] Maximum wait between retries
      # @param backoff [Symbol] Backoff strategy: :exponential, :linear, :constant
      # @param on [Array<Class>] Error classes to retry on
      # @return [self] For chaining
      def with_retry(max_attempts: nil, base_interval: nil, max_interval: nil, backoff: nil, on: nil)
        base = @retry_policy || self.class.respond_to?(:default_retry_policy) ? self.class.default_retry_policy : RetryPolicy.default
        @retry_policy = RetryPolicy.new(
          max_attempts: max_attempts || base.max_attempts,
          base_interval: base_interval || base.base_interval,
          max_interval: max_interval || base.max_interval,
          backoff: backoff || base.backoff,
          retryable_errors: on || base.retryable_errors
        )
        self
      end

      # Add a fallback model to use when this model fails
      #
      # @param fallback_model [Model] Model to use as fallback
      # @return [self] For chaining
      def with_fallback(fallback_model)
        @fallback_chain ||= []
        @fallback_chain << fallback_model
        self
      end

      # Prefer healthy models - check health before generating
      #
      # @param cache_health_for [Integer] Cache health check for N seconds
      # @return [self] For chaining
      def prefer_healthy(cache_health_for: 5)
        @prefer_healthy = true
        @health_cache_duration = cache_health_for
        self
      end

      # Register callback for failover events
      #
      # @yield [FailoverEvent] Called when failover occurs
      # @return [self] For chaining
      def on_failover(&block)
        @failover_callbacks ||= []
        @failover_callbacks << block
        self
      end

      # Register callback for all errors (including retried ones)
      #
      # @yield [error, attempt, model] Called on each error
      # @return [self] For chaining
      def on_error(&block)
        @error_callbacks ||= []
        @error_callbacks << block
        self
      end

      # Register callback for successful recovery after errors
      #
      # @yield [model, attempt] Called when generation succeeds after failures
      # @return [self] For chaining
      def on_recovery(&block)
        @recovery_callbacks ||= []
        @recovery_callbacks << block
        self
      end

      # Generate with reliability features applied
      #
      # @param messages [Array] Messages to send
      # @param kwargs [Hash] Additional arguments
      # @return [ChatMessage] Response
      def reliable_generate(messages, **)
        models_to_try = build_model_chain
        last_error = nil
        attempt = 0

        models_to_try.each_with_index do |model, model_index|
          # Health check if configured
          if @prefer_healthy && model.respond_to?(:healthy?) && !model.healthy?(cache_for: @health_cache_duration)
            notify_failover(model, models_to_try[model_index + 1], AgentError.new("Health check failed"), attempt)
            next
          end

          # Try this model with retries
          policy = model_retry_policy(model)
          result = try_model_with_retry(model, messages, policy, attempt, **)

          if result[:success]
            # Notify recovery if there were any retries (attempt > 1 means at least one retry)
            notify_recovery(model, result[:attempt]) if result[:attempt] > 1
            return result[:response]
          end

          last_error = result[:error]
          attempt = result[:attempt]

          # Notify failover to next model
          notify_failover(model, models_to_try[model_index + 1], last_error, attempt) if model_index < models_to_try.size - 1
        end

        raise last_error || AgentError.new("All models failed")
      end

      # Check if any model in the chain is healthy
      #
      # @return [Boolean]
      def any_healthy?
        build_model_chain.any? do |model|
          model.respond_to?(:healthy?) && model.healthy?(cache_for: 5)
        end
      end

      # Get the first healthy model in the chain
      #
      # @return [Model, nil]
      def first_healthy
        build_model_chain.find do |model|
          !model.respond_to?(:healthy?) || model.healthy?(cache_for: 5)
        end
      end

      # Clear all reliability configuration
      def reset_reliability
        @retry_policy = nil
        @fallback_chain = nil
        @prefer_healthy = false
        @failover_callbacks = nil
        @error_callbacks = nil
        @recovery_callbacks = nil
        self
      end

      # Get current reliability configuration
      def reliability_config
        {
          retry_policy: @retry_policy || RetryPolicy.default,
          fallback_count: @fallback_chain&.size || 0,
          prefer_healthy: @prefer_healthy || false,
          health_cache_duration: @health_cache_duration
        }
      end

      private

      def build_model_chain
        [self] + (@fallback_chain || [])
      end

      def model_retry_policy(model)
        if model == self && @retry_policy
          @retry_policy
        elsif model.respond_to?(:retry_policy, true) && model.send(:retry_policy)
          model.send(:retry_policy)
        else
          RetryPolicy.default
        end
      end

      def retry_policy
        @retry_policy
      end

      def try_model_with_retry(model, messages, policy, starting_attempt, **)
        attempt = starting_attempt

        policy.max_attempts.times do |retry_num|
          attempt += 1
          begin
            response = if model == self
                         generate_without_reliability(messages, **)
                       else
                         model.generate(messages, **)
                       end
            return { success: true, response:, attempt: }
          rescue *policy.retryable_errors => e
            notify_error(e, attempt, model)

            # Last attempt for this model
            return { success: false, error: e, attempt: } if retry_num == policy.max_attempts - 1

            # Calculate backoff
            interval = calculate_backoff(retry_num, policy)
            sleep(interval)
          end
        end

        { success: false, error: AgentError.new("Max retries exceeded"), attempt: }
      end

      def calculate_backoff(retry_num, policy)
        interval = policy.base_interval * (policy.multiplier**retry_num)
        [interval, policy.max_interval].min
      end

      def notify_failover(from_model, to_model, error, attempt)
        return unless @failover_callbacks&.any?

        event = FailoverEvent.new(
          from_model: from_model.model_id,
          to_model: to_model&.model_id || "none",
          error:,
          attempt:,
          timestamp: Time.now
        )
        @failover_callbacks.each { |cb| cb.call(event) }
      end

      def notify_error(error, attempt, model)
        @error_callbacks&.each { |cb| cb.call(error, attempt, model) }
      end

      def notify_recovery(model, attempt)
        @recovery_callbacks&.each { |cb| cb.call(model, attempt) }
      end

      # Hook for subclasses to call original generate
      def generate_without_reliability(messages, **)
        # This calls the original generate method
        # Subclasses should alias the original generate before including this concern
        raise NotImplementedError, "Include ModelReliability after defining generate, or alias original_generate" unless respond_to?(:original_generate, true)

        original_generate(messages, **)
      end
    end
  end
end
