module Smolagents
  module Concerns
    module ModelHealth
      # Health check execution logic
      module Checks
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
          return @last_health_check if cache_for && cached_check_valid?(cache_for)

          @last_health_check = perform_health_check
        end

        # Clear the health check cache.
        def clear_health_cache = @last_health_check = nil

        private

        def cached_check_valid?(cache_for)
          return false unless @last_health_check

          (Time.now - @last_health_check.checked_at) < cache_for
        end

        def perform_health_check
          start_time = monotonic_time
          response = models_request(timeout: current_thresholds[:timeout_ms] / 1000.0)
          build_healthy_status(response, elapsed_ms(start_time))
        rescue Faraday::TimeoutError
          build_unhealthy_status(error: "Request timeout", latency_ms: elapsed_ms(start_time))
        rescue Faraday::ConnectionFailed => e
          build_unhealthy_status(error: "Connection failed: #{e.message}", latency_ms: 0)
        rescue StandardError => e
          build_unhealthy_status(error: e.message, latency_ms: elapsed_ms(start_time))
        end

        # Timing helpers
        def monotonic_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        def elapsed_ms(start_time) = ((monotonic_time - start_time) * 1000).round

        # Status builders
        def build_healthy_status(response, latency_ms)
          models = parse_models_response(response)
          HealthStatus.new(
            status: latency_ms < current_thresholds[:healthy_latency_ms] ? :healthy : :degraded,
            latency_ms:, error: nil, checked_at: Time.now, model_id:,
            details: { model_count: models.size, models: models.map(&:id).first(5) }
          )
        end

        def build_unhealthy_status(error:, latency_ms:)
          HealthStatus.new(
            status: :unhealthy, latency_ms:, error:,
            checked_at: Time.now, model_id:, details: {}
          )
        end
      end
    end
  end
end
