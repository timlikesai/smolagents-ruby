# Live Infrastructure Configuration
#
# Real endpoints and model configurations for distributed experiments.

module LiveExperiments
  module Infrastructure
    # Endpoints for real hardware
    module Endpoints
      LLAMA_ULTRA = "https://llama-cpp-ultra.reverse-bull.ts.net/v1".freeze
      MACBOOK_PRO = "http://macbook-pro-m4.reverse-bull.ts.net:1234/v1".freeze
      MAC_STUDIO = "http://mac-studio.reverse-bull.ts.net:1234/v1".freeze
    end

    # Available models by endpoint (discovered 2026-01-26)
    MODELS = {
      llama_ultra: {
        endpoint: Endpoints::LLAMA_ULTRA,
        models: {
          fast_20b: "gpt-oss-20b-MXFP4",
          coder_30b: "Qwen3-Coder-30B-A3B-Instruct-MXFP4_MOE",
          glm_flash: "GLM-4.7-Flash-MXFP4_MOE",
          nemotron_30b: "NVIDIA-Nemotron-3-Nano-30B-A3B-MXFP4_MOE",
          devstral: "Devstral-Small-2-24B-Instruct-2512-Q4_1",
          qwen_math: "Qwen3-4B-math.Q8_0",
          lfm_tiny: "LFM2.5-1.2B-Instruct-Q8_0"
        },
        characteristics: { speed: :very_fast, vram: :constrained }
      },
      macbook_pro: {
        endpoint: Endpoints::MACBOOK_PRO,
        models: {
          glm_flash: "glm-4.7-flash-mlx@8bit",
          nemotron_nano: "nemotron-3-nano",
          lfm_instruct: "lfm2.5-1.2b-instruct"
        },
        characteristics: { speed: :fast, vram: :large }
      },
      mac_studio: {
        endpoint: Endpoints::MAC_STUDIO,
        models: {
          gpt_20b: "openai/gpt-oss-20b",
          glm_flash: "glm-4.7-flash-mlx",
          nemotron_30b: "mlx-community/nvidia-nemotron-3-nano-30b-a3b-mlx",
          medgemma: "medgemma-1.5-4b-it"
        },
        characteristics: { speed: :medium, vram: :large }
      }
    }.freeze

    # Model factory methods
    module ModelFactories
      extend self

      # Fast model on LLaMA Ultra - best for triage and quick tasks
      def fast_model(timeout: 30)
        Smolagents.model(:openai)
                  .base_url(Endpoints::LLAMA_ULTRA)
                  .id(MODELS[:llama_ultra][:models][:fast_20b])
                  .timeout(timeout)
                  .with_retry(max_attempts: 2)
                  .build
      end

      # Big reasoning model - for complex tasks
      def reasoning_model(timeout: 120)
        Smolagents.model(:openai)
                  .base_url(Endpoints::LLAMA_ULTRA)
                  .id(MODELS[:llama_ultra][:models][:coder_30b])
                  .timeout(timeout)
                  .with_retry(max_attempts: 2)
                  .build
      end

      # Coding specialist model
      def coder_model(timeout: 90)
        Smolagents.model(:openai)
                  .base_url(Endpoints::LLAMA_ULTRA)
                  .id(MODELS[:llama_ultra][:models][:devstral])
                  .timeout(timeout)
                  .with_retry(max_attempts: 2)
                  .build
      end

      # Math specialist model
      def math_model(timeout: 60)
        Smolagents.model(:openai)
                  .base_url(Endpoints::LLAMA_ULTRA)
                  .id(MODELS[:llama_ultra][:models][:qwen_math])
                  .timeout(timeout)
                  .with_retry(max_attempts: 2)
                  .build
      end

      # Fallback model on Mac Studio
      def fallback_model(timeout: 60)
        Smolagents.model(:openai)
                  .base_url(Endpoints::MAC_STUDIO)
                  .id(MODELS[:mac_studio][:models][:gpt_20b])
                  .timeout(timeout)
                  .with_retry(max_attempts: 3)
                  .build
      end

      # Tiny utility model - for quick classification
      def utility_model(timeout: 15)
        Smolagents.model(:openai)
                  .base_url(Endpoints::LLAMA_ULTRA)
                  .id(MODELS[:llama_ultra][:models][:lfm_tiny])
                  .timeout(timeout)
                  .build
      end

      # Resilient fast model with fallback chain
      def resilient_fast_model
        Smolagents.model(:openai)
                  .base_url(Endpoints::LLAMA_ULTRA)
                  .id(MODELS[:llama_ultra][:models][:fast_20b])
                  .timeout(30)
                  .with_retry(max_attempts: 2)
                  .with_fallback { fallback_model }
                  .with_circuit_breaker(threshold: 3, reset_after: 60)
                  .build
      end
    end

    # Health check for all endpoints
    class HealthChecker
      include Smolagents::Concerns::Http

      def check_all
        MODELS.transform_values do |config|
          check_endpoint(config[:endpoint])
        end
      end

      def check_endpoint(endpoint)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = get("#{endpoint}/models", headers: {}, allow_private: true, timeout: 5.0)
        latency = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round

        models = JSON.parse(response.body)["data"]&.map { |m| m["id"] } || []
        { status: :healthy, latency_ms: latency, models: models.first(5) }
      rescue Faraday::TimeoutError
        { status: :timeout, latency_ms: nil, models: [] }
      rescue Faraday::ConnectionFailed => e
        { status: :unreachable, error: e.message, models: [] }
      rescue StandardError => e
        { status: :error, error: e.message, models: [] }
      end

      def any_healthy?
        check_all.values.any? { |s| s[:status] == :healthy }
      end

      def report
        results = check_all
        lines = ["Infrastructure Health Check", "=" * 40]

        results.each do |name, status|
          emoji = status[:status] == :healthy ? "✅" : "❌"
          lines << "#{emoji} #{name}: #{status[:status]}"
          lines << "   Latency: #{status[:latency_ms]}ms" if status[:latency_ms]
          lines << "   Models: #{status[:models].join(", ")}" if status[:models].any?
          lines << "   Error: #{status[:error]}" if status[:error]
        end

        lines.join("\n")
      end
    end
  end
end
