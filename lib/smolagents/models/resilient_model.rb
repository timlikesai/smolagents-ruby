require "delegate"
require_relative "../concerns/resilience/retry_policy"
require_relative "../concerns/resilience/events"
require_relative "../events"

module Smolagents
  module Models
    # Decorator that adds resilience capabilities to any model.
    #
    # ResilientModel wraps a base model and provides retry, fallback,
    # and health-based routing without coupling these features directly
    # to model implementations. It implements the Decorator pattern, delegating
    # all Model methods to the wrapped model while adding reliability features.
    #
    # Key capabilities:
    # - **Retry**: Automatic retry with configurable backoff strategies
    # - **Fallback**: Chain of backup models tried in order on failure
    # - **Health-based routing**: Skip unhealthy models in the chain
    # - **Event handling**: Subscribe to failover, retry, and recovery events
    #
    # The resilient model inherits all capabilities from the base model via
    # SimpleDelegator, so it can be used anywhere a regular Model is expected.
    #
    # @example Basic usage with retry
    #   model = OpenAIModel.new(model_id: "gpt-4", api_key: key)
    #   resilient = ResilientModel.new(model, retry_policy: RetryPolicy.default)
    #   response = resilient.generate(messages)  # Retries on transient failures
    #
    # @example With fallback chain
    #   primary = OpenAIModel.new(model_id: "gpt-4", api_key: key)
    #   backup = OpenAIModel.new(model_id: "gpt-3.5-turbo", api_key: key)
    #   resilient = ResilientModel.new(primary, fallbacks: [backup])
    #   # If gpt-4 fails, automatically tries gpt-3.5-turbo
    #
    # @example Full resilience stack
    #   resilient = ResilientModel.new(primary,
    #     retry_policy: RetryPolicy.aggressive,
    #     fallbacks: [backup, emergency],
    #     prefer_healthy: true,
    #     health_cache_duration: 10
    #   )
    #
    # @example Fluent configuration
    #   resilient = ResilientModel.new(primary)
    #     .with_retry(max_attempts: 5, backoff: :exponential)
    #     .with_fallback(backup_model)
    #     .prefer_healthy(cache_health_for: 10)
    #
    # @example Event handling
    #   resilient = ResilientModel.new(primary)
    #     .on_failover { |e| logger.warn("Failover: #{e.from_model_id} -> #{e.to_model_id}") }
    #     .on_retry { |e| logger.info("Retry #{e.attempt}/#{e.max_attempts}") }
    #     .on_recovery { |e| logger.info("Recovered after #{e.attempts_before_recovery} attempts") }
    #
    # @see Model Base class documentation
    # @see Concerns::RetryPolicy For retry configuration
    # @see Events::FailoverOccurred For failover event structure
    class ResilientModel < SimpleDelegator
      include Events::Emitter
      include Events::Consumer

      # @!attribute [r] retry_policy
      #   @return [Concerns::RetryPolicy, nil] The configured retry policy, or nil if no retry
      attr_reader :retry_policy

      # @!attribute [r] fallbacks
      #   @return [Array<Model>] List of fallback models in priority order (frozen)
      attr_reader :fallbacks

      # @!attribute [r] health_cache_duration
      #   @return [Integer] How long to cache health check results in seconds
      attr_reader :health_cache_duration

      # Creates a new resilient model wrapper.
      #
      # Wraps a base model with resilience capabilities. The wrapper delegates all
      # Model methods to the base model while adding retry, fallback, and health
      # routing logic around the generate method.
      #
      # @param model [Model] The base model to wrap. Any Model subclass works.
      # @param retry_policy [Concerns::RetryPolicy, nil] Retry configuration controlling
      #   attempts, backoff, and which errors to retry. Use RetryPolicy.default for
      #   sensible defaults or RetryPolicy.aggressive for more retries.
      # @param fallbacks [Array<Model>] Backup models tried in order when the primary
      #   fails. Each model in the chain is tried with its own retry policy.
      # @param prefer_healthy [Boolean] When true, skips models that fail health checks
      #   before attempting generation. Requires models to implement #healthy? method.
      # @param health_cache_duration [Integer] How long to cache health check results
      #   in seconds. Prevents excessive health check calls. Default: 5 seconds.
      #
      # @example Minimal usage
      #   resilient = ResilientModel.new(my_model)
      #
      # @example With retry policy
      #   policy = Concerns::RetryPolicy.new(max_attempts: 3, backoff: :exponential)
      #   resilient = ResilientModel.new(my_model, retry_policy: policy)
      #
      # @example With fallback chain
      #   resilient = ResilientModel.new(gpt4,
      #     fallbacks: [gpt35, claude],
      #     retry_policy: RetryPolicy.default
      #   )
      def initialize(model, retry_policy: nil, fallbacks: [], prefer_healthy: false, health_cache_duration: 5)
        super(model)
        @retry_policy = retry_policy
        @fallbacks = fallbacks.dup.freeze
        @prefer_healthy = prefer_healthy
        @health_cache_duration = health_cache_duration
        setup_consumer
      end

      # The wrapped model.
      #
      # @return [Model] The underlying model instance
      def base_model = __getobj__

      # Model ID from the base model.
      #
      # @return [String] The model identifier
      def model_id = base_model.model_id

      # Generates a response with resilience features applied.
      #
      # When resilience is enabled (retry policy, fallbacks, or prefer_healthy),
      # wraps the generation with retry and fallback logic. On failure, tries
      # fallback models in order. Emits events for failover, retry, and recovery.
      #
      # When resilience is disabled, delegates directly to the base model
      # with no additional overhead.
      #
      # @param messages [Array<ChatMessage>] The conversation history
      # @param options [Hash] Additional arguments passed to the backend model
      # @option options [Float] :temperature Sampling temperature override
      # @option options [Integer] :max_tokens Maximum tokens override
      # @option options [Array<Tool>] :tools_to_call_from Available tools
      #
      # @return [ChatMessage] Model response from primary or fallback
      #
      # @raise [StandardError] When all models in the chain fail after exhausting
      #   retries. The last error is re-raised.
      #
      # @example Basic generation with retry
      #   resilient = ResilientModel.new(model, retry_policy: RetryPolicy.default)
      #   response = resilient.generate([ChatMessage.user("Hello")])
      #
      # @example Handling fallback scenarios
      #   resilient = ResilientModel.new(gpt4, fallbacks: [gpt35])
      #     .on_failover { |e| puts "Switched to: #{e.to_model_id}" }
      #   response = resilient.generate(messages)
      #
      # @see #reliable_generate For explicit resilient generation
      # @see Model#generate Base class definition
      def generate(messages, **)
        return base_model.generate(messages, **) unless resilience_enabled?

        reliable_generate(messages, **)
      end

      # Generates a response with resilience explicitly applied.
      #
      # Unlike {#generate}, this method always applies resilience logic even if
      # no retry policy or fallbacks are configured. Useful when you want to
      # explicitly invoke the retry/fallback chain.
      #
      # @param messages [Array<ChatMessage>] The conversation history
      # @param options [Hash] Additional arguments passed to the backend model
      #
      # @return [ChatMessage] Model response from primary or fallback
      #
      # @raise [AgentError] When all models fail. Raises the last encountered error
      #   or a generic "All models failed" error if no specific error was captured.
      #
      # @see #generate For automatic resilience based on configuration
      def reliable_generate(messages, **)
        state = { last_error: nil, attempt: 0 }
        result = try_chain(messages, state, **)
        return result if result

        raise state[:last_error] || AgentError.new("All models failed")
      end

      # Configure retry behavior.
      #
      # @param max_attempts [Integer, nil] Maximum retry attempts
      # @param base_interval [Float, nil] Initial backoff interval
      # @param max_interval [Float, nil] Maximum backoff interval
      # @param backoff [Symbol, nil] Backoff strategy
      # @param jitter [Float, nil] Jitter factor
      # @param on [Array<Class>, nil] Retryable error classes
      # @return [self] For chaining
      def with_retry(max_attempts: nil, base_interval: nil, max_interval: nil, backoff: nil, jitter: nil, on: nil)
        base = @retry_policy || Concerns::RetryPolicy.default
        @retry_policy = Concerns::RetryPolicy.new(
          max_attempts: max_attempts || base.max_attempts,
          base_interval: base_interval || base.base_interval,
          max_interval: max_interval || base.max_interval,
          backoff: backoff || base.backoff,
          jitter: jitter || base.jitter,
          retryable_errors: on || base.retryable_errors
        )
        self
      end

      # Add a fallback model.
      #
      # @param fallback_model [Model] Model to use when primary fails
      # @return [self] For chaining
      def with_fallback(fallback_model)
        @fallbacks = (@fallbacks + [fallback_model]).freeze
        self
      end

      # Enable health-based routing.
      #
      # @param cache_health_for [Integer] Cache health check for N seconds
      # @return [self] For chaining
      def prefer_healthy(cache_health_for: 5)
        @prefer_healthy = true
        @health_cache_duration = cache_health_for
        self
      end

      # Check if health-based routing is enabled.
      #
      # @return [Boolean]
      def prefer_healthy? = @prefer_healthy

      # Get the complete model chain.
      #
      # @return [Array<Model>] Base model followed by fallbacks
      def model_chain
        [base_model] + @fallbacks
      end

      # Number of fallback models.
      #
      # @return [Integer]
      def fallback_count = @fallbacks.size

      # Check if any model in the chain is healthy.
      #
      # @return [Boolean]
      def any_healthy?
        model_chain.any? do |model|
          model.respond_to?(:healthy?) && model.healthy?(cache_for: @health_cache_duration)
        end
      end

      # Get the first healthy model in the chain.
      #
      # @return [Model, nil]
      def first_healthy
        model_chain.find do |model|
          !model.respond_to?(:healthy?) || model.healthy?(cache_for: @health_cache_duration)
        end
      end

      # Reset all resilience configuration.
      #
      # @return [self] For chaining
      def reset_reliability
        @retry_policy = nil
        @fallbacks = [].freeze
        @prefer_healthy = false
        @health_cache_duration = 5
        clear_handlers
        self
      end

      # Current resilience configuration.
      #
      # @return [Hash]
      def reliability_config
        {
          retry_policy: @retry_policy || Concerns::RetryPolicy.default,
          fallback_count:,
          prefer_healthy: prefer_healthy?,
          health_cache_duration: @health_cache_duration
        }
      end

      # Subscribe to failover events.
      #
      # @yield [Events::FailoverOccurred] Called on failover
      # @return [self] For chaining
      def on_failover(&) = on(Events::FailoverOccurred, &)

      # Subscribe to error events.
      #
      # @yield [Events::ErrorOccurred] Called on error
      # @return [self] For chaining
      def on_error(&) = on(Events::ErrorOccurred, &)

      # Subscribe to recovery events.
      #
      # @yield [Events::RecoveryCompleted] Called on recovery
      # @return [self] For chaining
      def on_recovery(&) = on(Events::RecoveryCompleted, &)

      # Subscribe to retry events.
      #
      # @yield [Events::RetryRequested] Called before retry
      # @return [self] For chaining
      def on_retry(&) = on(Events::RetryRequested, &)

      private

      def resilience_enabled?
        @retry_policy || @fallbacks.any? || @prefer_healthy
      end

      def try_chain(messages, state, **)
        models = model_chain
        models.each_with_index do |model, idx|
          result = try_model_in_chain(model, models[idx + 1], messages, state, **)
          return result if result
        end
        nil
      end

      def try_model_in_chain(model, next_model, messages, state, **)
        return nil if skip_unhealthy?(model, next_model, state[:attempt])

        policy = model_retry_policy(model)
        result = try_model_with_retry(model, messages, policy, state[:attempt], **)
        return handle_success(model, result) if result[:success]

        state[:last_error] = result[:error]
        state[:attempt] = result[:attempt]
        notify_failover(model, next_model, state[:last_error], state[:attempt]) if next_model
        nil
      end

      def skip_unhealthy?(model, next_model, attempt)
        return false unless @prefer_healthy
        return false unless model.respond_to?(:healthy?)
        return false if model.healthy?(cache_for: @health_cache_duration)

        notify_failover(model, next_model, AgentError.new("Health check failed"), attempt)
        true
      end

      def handle_success(model, result)
        notify_recovery(model, result[:attempt]) if result[:attempt] > 1
        result[:response]
      end

      def model_retry_policy(model)
        return @retry_policy if model == base_model && @retry_policy

        # Check if model has its own retry policy (if it's also a ResilientModel)
        return model.retry_policy if model.respond_to?(:retry_policy, true) && model.retry_policy

        Concerns::RetryPolicy.default
      end

      def try_model_with_retry(model, messages, policy, starting_attempt, **)
        state = { attempt: starting_attempt, last_error: nil }
        policy.max_attempts.times do |retry_num|
          state[:attempt] += 1
          result = attempt_generate(model, messages, **)
          return result.merge(attempt: state[:attempt]) if result[:success]

          handle_retry_failure(model, result[:error], state, retry_num, policy)
        end
        { success: false, error: state[:last_error] || AgentError.new("Max retries exceeded"),
          attempt: state[:attempt] }
      end

      def handle_retry_failure(model, error, state, retry_num, policy)
        state[:last_error] = error
        notify_error(error, state[:attempt], model)
        return if retry_num == policy.max_attempts - 1

        notify_retry(model, error, state[:attempt], policy.max_attempts, policy.backoff_for(retry_num))
      end

      def attempt_generate(model, messages, **)
        response = if model == base_model
                     base_model.generate(messages, **)
                   elsif model.is_a?(ResilientModel)
                     # Unwrap to avoid nested resilience
                     model.base_model.generate(messages, **)
                   else
                     model.generate(messages, **)
                   end
        { success: true, response: }
      rescue *Concerns::RetryPolicy.default.retryable_errors => e
        { success: false, error: e }
      end

      # Event notification helpers

      def notify_failover(from_model, to_model, error, attempt)
        from_id = from_model.respond_to?(:model_id) ? from_model.model_id : from_model.to_s
        to_id = to_model.respond_to?(:model_id) ? to_model.model_id : (to_model&.to_s || "none")
        event = Events::FailoverOccurred.create(
          from_model_id: from_id, to_model_id: to_id, error:, attempt:
        )
        emit_event(event) if emitting?
        consume(event)
      end

      def notify_error(error, attempt, model)
        model_id = model.respond_to?(:model_id) ? model.model_id : model.to_s
        emit_error(error, context: { model_id:, attempt: }, recoverable: true) if emitting?
      end

      def notify_recovery(model, attempt)
        model_id = model.respond_to?(:model_id) ? model.model_id : model.to_s
        event = Events::RecoveryCompleted.create(model_id:, attempts_before_recovery: attempt)
        emit_event(event) if emitting?
        consume(event)
      end

      def notify_retry(model, error, attempt, max_attempts, suggested_interval)
        model_id = model.respond_to?(:model_id) ? model.model_id : model.to_s
        event = Events::RetryRequested.create(
          model_id:, error:, attempt:, max_attempts:, suggested_interval:
        )
        emit_event(event) if emitting?
        consume(event)
      end
    end
  end
end
