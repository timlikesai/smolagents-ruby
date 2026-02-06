module Smolagents
  module Concerns
    module ModelHealth
      # Health check execution logic
      module Checks
        include TimingHelpers

        def self.included(base)
          base.include(Events::Emitter)
        end

        # Configure health check options.
        #
        # @param cache_for [Integer] Default cache duration in seconds
        # @param verify_model [Boolean] Whether to verify model_id is in models list
        # @param thresholds [Hash] Custom health check thresholds
        def configure_health_check(cache_for: 5, verify_model: false, thresholds: {})
          @health_check_config = { cache_for:, verify_model:, thresholds: }
        end

        # Get health check configuration.
        # @return [Hash] Health check configuration
        def health_check_config
          @health_check_config ||= { cache_for: 5, verify_model: false, thresholds: {} }
        end

        # Check if model verification is enabled.
        # @return [Boolean]
        def verify_model? = health_check_config[:verify_model]

        # Check if the model server is responding.
        #
        # @param cache_for [Integer, nil] Cache result for this many seconds (nil = no cache)
        # @return [Boolean] true if server is healthy or degraded, false if unhealthy
        def healthy?(cache_for: nil)
          check = health_check(cache_for:)
          check.healthy? || check.degraded?
        end

        # Perform a detailed health check.
        #
        # @param cache_for [Integer, nil] Cache result for this many seconds
        # @return [HealthStatus] Detailed health status
        def health_check(cache_for: nil)
          check_type = cache_for && cached_check_valid?(cache_for) ? :cached : :full
          emit(Events::HealthCheckRequested.create(model_id:, check_type:))

          return @last_health_check if check_type == :cached

          @last_health_check = perform_health_check
        end

        # Clear the health check cache.
        def clear_health_cache = @last_health_check = nil

        private

        def cached_check_valid?(cache_for)
          return false unless @last_health_check

          (Time.now - @last_health_check.checked_at) < cache_for
        end

        # rubocop:disable Metrics/AbcSize -- health check needs multiple exception paths
        def perform_health_check
          start_time = monotonic_now
          response = models_request(timeout: current_thresholds[:timeout_ms] / 1000.0)
          build_healthy_status(response, elapsed_ms(start_time, precision: 0).to_i)
        rescue Faraday::TimeoutError
          build_unhealthy_status(error: "Request timeout", latency_ms: elapsed_ms(start_time, precision: 0).to_i)
        rescue Faraday::ConnectionFailed => e
          build_unhealthy_status(error: "Connection failed: #{e.message}", latency_ms: 0)
        rescue StandardError => e
          build_unhealthy_status(error: e.message, latency_ms: elapsed_ms(start_time, precision: 0).to_i)
        end
        # rubocop:enable Metrics/AbcSize

        def current_thresholds
          self.class.respond_to?(:health_thresholds) ? self.class.health_thresholds : ModelHealth::HEALTH_THRESHOLDS
        end

        def build_healthy_status(response, latency_ms)
          models = parse_models_response(response)
          return model_not_found_status(models, latency_ms) if model_verification_failed?(models)

          emit_and_build_healthy(models, latency_ms)
        end

        def model_verification_failed?(models) = verify_model? && models.none? { |m| m.id == model_id }

        def model_not_found_status(models, latency_ms)
          build_unhealthy_status(
            error: "Model '#{model_id}' not found in available models: #{models.map(&:id).first(5).join(", ")}",
            latency_ms:
          )
        end

        def emit_and_build_healthy(models, latency_ms)
          status = latency_ms < current_thresholds[:healthy_latency_ms] ? :healthy : :degraded
          emit(Events::HealthCheckCompleted.create(model_id:, status:, latency_ms:, error: nil))
          Types::HealthStatus.new(
            status:, latency_ms:, error: nil, checked_at: Time.now, model_id:,
            details: { model_count: models.size, models: models.map(&:id).first(5), model_verified: verify_model? }
          )
        end

        def build_unhealthy_status(error:, latency_ms:)
          emit(Events::HealthCheckCompleted.create(model_id:, status: :unhealthy, latency_ms:, error:))
          Types::HealthStatus.new(
            status: :unhealthy, latency_ms:, error:,
            checked_at: Time.now, model_id:, details: {}
          )
        end
      end
    end
  end
end
