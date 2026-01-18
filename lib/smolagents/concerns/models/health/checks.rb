module Smolagents
  module Concerns
    module ModelHealth
      # Health check execution logic
      module Checks
        include TimingHelpers

        def self.included(base)
          base.include(Events::Emitter)
        end

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

        # Get current health thresholds for this model.
        # @return [Hash] Thresholds including latency and timeout settings
        def current_thresholds
          self.class.respond_to?(:health_thresholds) ? self.class.health_thresholds : ModelHealth::HEALTH_THRESHOLDS
        end

        # Build healthy status from successful health check.
        # @param response [Hash] Models API response
        # @param latency_ms [Integer] Request latency in milliseconds
        # @return [HealthStatus] Healthy or degraded status
        def build_healthy_status(response, latency_ms)
          models = parse_models_response(response)
          status = latency_ms < current_thresholds[:healthy_latency_ms] ? :healthy : :degraded
          emit(Events::HealthCheckCompleted.create(model_id:, status:, latency_ms:,
                                                   error: nil))
          HealthStatus.new(
            status:, latency_ms:, error: nil, checked_at: Time.now, model_id:,
            details: { model_count: models.size, models: models.map(&:id).first(5) }
          )
        end

        # Build unhealthy status from failed health check.
        # @param error [String] Error message
        # @param latency_ms [Integer] Request latency in milliseconds
        # @return [HealthStatus] Unhealthy status
        def build_unhealthy_status(error:, latency_ms:)
          emit(Events::HealthCheckCompleted.create(model_id:, status: :unhealthy, latency_ms:,
                                                   error:))
          HealthStatus.new(
            status: :unhealthy, latency_ms:, error:,
            checked_at: Time.now, model_id:, details: {}
          )
        end
      end
    end
  end
end
