module Smolagents
  module Concerns
    # Event-driven reliability for model failover, retry, and routing.
    #
    # Composable reliability primitives with no blocking sleeps.
    # All operations emit events that can be handled by consumers.
    #
    # @example Fallback chain
    #   model.with_fallback(backup_model).with_fallback(emergency_model)
    #
    # @example Retry with event handling
    #   model.with_retry(max_attempts: 5)
    #        .on(Events::RetryRequested) { |e| log("Retry #{e.attempt}") }
    #
    # @example Health-based routing
    #   model.prefer_healthy.with_fallback(backup)
    #
    # @example Full reliability stack
    #   model.with_retry(max_attempts: 3)
    #        .with_fallback(backup_model)
    #        .on(Events::FailoverOccurred) { |e| log("#{e.from_model_id} -> #{e.to_model_id}") }
    #
    module ModelReliability
      # Retry configuration
      #
      # Immutable configuration for retry behavior with exponential/linear backoff.
      # Intervals are for informational/callback purposes only - this module does NOT sleep.
      # The caller handles scheduling via event callbacks.
      #
      # @!attribute [r] max_attempts
      #   @return [Integer] Maximum number of retry attempts
      # @!attribute [r] base_interval
      #   @return [Float] Initial backoff interval in seconds
      # @!attribute [r] max_interval
      #   @return [Float] Maximum backoff interval in seconds
      # @!attribute [r] backoff
      #   @return [Symbol] Backoff strategy (:exponential, :linear, or :constant)
      # @!attribute [r] retryable_errors
      #   @return [Array<Class>] Exception classes that trigger retries
      #
      # @example Creating custom policy
      #   policy = RetryPolicy.new(
      #     max_attempts: 5,
      #     base_interval: 2.0,
      #     max_interval: 60.0,
      #     backoff: :exponential,
      #     retryable_errors: [Faraday::Error]
      #   )
      #
      # @example Using default policy
      #   policy = RetryPolicy.default
      #   # => max_attempts: 3, base_interval: 1.0, backoff: :exponential
      RetryPolicy = Data.define(:max_attempts, :base_interval, :max_interval, :backoff, :retryable_errors) do
        # Get the default retry policy (3 attempts, 1s base interval, exponential backoff).
        #
        # @return [RetryPolicy] Default retry configuration
        def self.default
          new(
            max_attempts: 3,
            base_interval: 1.0,
            max_interval: 30.0,
            backoff: :exponential,
            retryable_errors: [Faraday::Error, Faraday::TimeoutError]
          )
        end

        # Calculate the backoff multiplier based on the strategy.
        #
        # @return [Float] Multiplier for exponential (2.0), linear (1.5), or constant (1.0) backoff
        #
        # @example Exponential growth
        #   policy = RetryPolicy.new(..., backoff: :exponential)
        #   policy.multiplier  # => 2.0
        #   # Intervals: 1s, 2s, 4s, 8s, 16s, 30s (capped)
        def multiplier
          case backoff
          when :exponential then 2.0
          when :linear then 1.5
          else 1.0
          end
        end
      end

      # Event emitted before a retry attempt.
      #
      # Immutable record of a retry attempt with calculated backoff interval.
      # Allows subscribers to log retries or adjust scheduling.
      #
      # @!attribute [r] model
      #   @return [Model] The model being retried
      # @!attribute [r] error
      #   @return [StandardError] The error that triggered the retry
      # @!attribute [r] attempt
      #   @return [Integer] Current attempt number (1-indexed)
      # @!attribute [r] max_attempts
      #   @return [Integer] Maximum attempts allowed
      # @!attribute [r] suggested_interval
      #   @return [Float] Suggested wait time in seconds before next retry
      #
      # @example Converting to hash
      #   event = RetryEvent.new(model:, error:, attempt: 2, max_attempts: 3, suggested_interval: 2.0)
      #   event.to_h
      #   # => { model: "gpt-4", error: "timeout", attempt: 2, max_attempts: 3, suggested_interval: 2.0 }
      RetryEvent = Data.define(:model, :error, :attempt, :max_attempts, :suggested_interval) do
        # Convert retry event to a Hash for serialization or logging.
        #
        # @return [Hash] Hash with :model (model_id), :error (message), :attempt, :max_attempts, :suggested_interval
        def to_h
          { model: model.model_id, error: error.message, attempt:, max_attempts:, suggested_interval: }
        end
      end

      # Failover event emitted when switching to a backup model.
      #
      # Immutable record of a failover event with source, destination, and error details.
      # Allows monitoring and logging of model switching events.
      #
      # @!attribute [r] from_model
      #   @return [Model] The model that failed
      # @!attribute [r] to_model
      #   @return [Model, nil] The backup model being switched to (nil if none available)
      # @!attribute [r] error
      #   @return [StandardError] The error that triggered failover
      # @!attribute [r] attempt
      #   @return [Integer] Attempt number when failover occurred
      # @!attribute [r] timestamp
      #   @return [Time] When the failover occurred
      #
      # @example Converting to hash
      #   event = FailoverEvent.new(from_model: m1, to_model: m2, error:, attempt: 1, timestamp: Time.now)
      #   event.to_h
      #   # => { from: m1, to: m2, error: "Connection failed", attempt: 1, timestamp: "2024-01-15T10:30:00Z" }
      FailoverEvent = Data.define(:from_model, :to_model, :error, :attempt, :timestamp) do
        # Convert failover event to a Hash for serialization or logging.
        #
        # @return [Hash] Hash with :from, :to, :error (message), :attempt, :timestamp (ISO8601)
        def to_h
          { from: from_model, to: to_model, error: error.message, attempt:, timestamp: timestamp.iso8601 }
        end
      end

      def self.included(base)
        base.include(Events::Emitter) unless base < Events::Emitter
        base.include(Events::Consumer) unless base < Events::Consumer
        base.extend(ClassMethods)
      end

      # Handle when module is extended onto a single instance
      def self.extended(instance)
        # Extend with Emitter and Consumer on the singleton class
        instance.extend(Events::Emitter) unless instance.singleton_class.include?(Events::Emitter)
        instance.extend(Events::Consumer) unless instance.singleton_class.include?(Events::Consumer)
      end

      # Class-level reliability configuration
      module ClassMethods
        # Set or get the default retry policy for all instances of this model class.
        #
        # @param policy [RetryPolicy, nil] Retry policy to set as default, or nil to get current
        # @return [RetryPolicy] The default retry policy (existing or RetryPolicy.default)
        #
        # @example Setting a custom default policy
        #   class FastModel < OpenAIModel
        #     default_retry_policy(
        #       RetryPolicy.new(
        #         max_attempts: 5,
        #         base_interval: 2.0,
        #         backoff: :exponential
        #       )
        #     )
        #   end
        #
        # @example Getting the policy
        #   policy = FastModel.default_retry_policy
        #   # => RetryPolicy(max_attempts: 5, ...)
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

      # Subscribe to failover events.
      # @yield [FailoverOccurred] Called when failover occurs
      # @return [self] For chaining
      def on_failover(&) = on(Events::FailoverOccurred, &)

      # Subscribe to error events.
      # @yield [ErrorOccurred] Called on each error
      # @return [self] For chaining
      def on_error(&) = on(Events::ErrorOccurred, &)

      # Subscribe to recovery events.
      # @yield [RecoveryCompleted] Called when generation succeeds after failures
      # @return [self] For chaining
      def on_recovery(&) = on(Events::RecoveryCompleted, &)

      # Subscribe to retry events.
      # @yield [RetryRequested] Called before each retry
      # @return [self] For chaining
      def on_retry(&) = on(Events::RetryRequested, &)

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
        clear_handlers
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

            # Calculate suggested backoff interval for event subscribers
            # Note: We do NOT sleep - callers handle scheduling via callbacks
            interval = calculate_backoff(retry_num, policy)
            notify_retry(model, e, attempt, policy.max_attempts, interval)
            # Immediate retry - no blocking sleep
          end
        end

        { success: false, error: AgentError.new("Max retries exceeded"), attempt: }
      end

      def calculate_backoff(retry_num, policy)
        interval = policy.base_interval * (policy.multiplier**retry_num)
        [interval, policy.max_interval].min
      end

      def notify_failover(from_model, to_model, error, attempt)
        event = Events::FailoverOccurred.create(
          from_model_id: from_model.model_id,
          to_model_id: to_model&.model_id || "none",
          error:,
          attempt:
        )
        emit_event(event) if emitting?
        consume(event)
      end

      def notify_error(error, attempt, model)
        emit_error(error, context: { model_id: model.model_id, attempt: }, recoverable: true) if emitting?
      end

      def notify_recovery(model, attempt)
        event = Events::RecoveryCompleted.create(model_id: model.model_id, attempts_before_recovery: attempt)
        emit_event(event) if emitting?
        consume(event)
      end

      def notify_retry(model, error, attempt, max_attempts, suggested_interval)
        event = Events::RetryRequested.create(model_id: model.model_id, error:, attempt:, max_attempts:, suggested_interval:)
        emit_event(event) if emitting?
        consume(event)
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
