# Live Infrastructure Configuration
#
# Real endpoints and model configurations for distributed experiments.
# Configure via environment variables or .env file.
#
# LM Studio 0.4.0+ endpoints support capability probing via /api/v1/models.
# See .env.example for configuration template.

require "dotenv"
Dotenv.load(File.expand_path("../.env", __dir__))

module LiveExperiments
  module Infrastructure
    # Endpoints configured from environment (with Tailscale defaults)
    module Endpoints
      LLAMA_CPP_ULTRA = ENV.fetch("LLAMA_CPP_ULTRA_URL", "http://localhost:8080/v1").freeze
      MACBOOK_PRO_M4 = ENV.fetch(
        "MACBOOK_PRO_M4_URL",
        "http://macbook-pro-m4.reverse-bull.ts.net:1234/v1"
      ).freeze
      MAC_STUDIO = ENV.fetch(
        "MAC_STUDIO_URL",
        "http://mac-studio.reverse-bull.ts.net:1234/v1"
      ).freeze

      def self.configured?
        !ENV["LLAMA_CPP_ULTRA_URL"].nil? || !ENV["MACBOOK_PRO_M4_URL"].nil?
      end

      def self.all = [LLAMA_CPP_ULTRA, MACBOOK_PRO_M4, MAC_STUDIO]
    end

    # Model IDs from environment with defaults
    module ModelIds
      FAST = ENV.fetch("FAST_MODEL_ID", "GLM-4.7-Flash-Q4_1").freeze
      REASONING = ENV.fetch("REASONING_MODEL_ID", "NVIDIA-Nemotron-3-Nano-30B-A3B-Q4_1").freeze
      CODER = ENV.fetch("CODER_MODEL_ID", "Devstral-Small-2-24B-Instruct-2512-Q4_1").freeze
      MATH = ENV.fetch("MATH_MODEL_ID", "Qwen3-4B-math.Q8_0").freeze
      UTILITY = ENV.fetch("UTILITY_MODEL_ID", "LFM2.5-1.2B-Instruct-Q8_0").freeze
      FALLBACK = ENV.fetch("FALLBACK_MODEL_ID", "glm-4.7-flash-mlx@8bit").freeze
    end

    # Endpoint configurations with server types
    ENDPOINTS = {
      "llama-cpp-ultra" => {
        endpoint: Endpoints::LLAMA_CPP_ULTRA,
        server_type: :llama_cpp,
        characteristics: { speed: :very_fast, vram: :constrained }
      },
      "macbook-pro-m4" => {
        endpoint: Endpoints::MACBOOK_PRO_M4,
        server_type: :lm_studio,
        characteristics: { speed: :fast, vram: :large }
      },
      "mac-studio" => {
        endpoint: Endpoints::MAC_STUDIO,
        server_type: :lm_studio,
        characteristics: { speed: :medium, vram: :large }
      }
    }.freeze

    # Model factory methods
    module ModelFactories
      module_function

      # Fast model on primary endpoint
      def fast_model(timeout: 30)
        Smolagents.model(:openai)
                  .base_url(Endpoints::LLAMA_CPP_ULTRA)
                  .id(ModelIds::FAST)
                  .timeout(timeout)
                  .server_type(:llama_cpp)
                  .with_retry(max_attempts: 2)
                  .build
      end

      # Big reasoning model
      def reasoning_model(timeout: 120)
        Smolagents.model(:openai)
                  .base_url(Endpoints::LLAMA_CPP_ULTRA)
                  .id(ModelIds::REASONING)
                  .timeout(timeout)
                  .server_type(:llama_cpp)
                  .with_retry(max_attempts: 2)
                  .build
      end

      # Coding specialist model
      def coder_model(timeout: 90)
        Smolagents.model(:openai)
                  .base_url(Endpoints::LLAMA_CPP_ULTRA)
                  .id(ModelIds::CODER)
                  .timeout(timeout)
                  .server_type(:llama_cpp)
                  .with_retry(max_attempts: 2)
                  .build
      end

      # Math specialist model
      def math_model(timeout: 60)
        Smolagents.model(:openai)
                  .base_url(Endpoints::LLAMA_CPP_ULTRA)
                  .id(ModelIds::MATH)
                  .timeout(timeout)
                  .server_type(:llama_cpp)
                  .with_retry(max_attempts: 2)
                  .build
      end

      # Tiny utility model
      def utility_model(timeout: 15)
        Smolagents.model(:openai)
                  .base_url(Endpoints::LLAMA_CPP_ULTRA)
                  .id(ModelIds::UTILITY)
                  .timeout(timeout)
                  .server_type(:llama_cpp)
                  .build
      end

      # Fallback model on secondary endpoint
      def fallback_model(timeout: 60)
        Smolagents.model(:openai)
                  .base_url(Endpoints::MACBOOK_PRO_M4)
                  .id(ModelIds::FALLBACK)
                  .timeout(timeout)
                  .server_type(:lm_studio)
                  .with_retry(max_attempts: 3)
                  .build
      end

      # Resilient fast model with fallback chain
      def resilient_fast_model
        Smolagents.model(:openai)
                  .base_url(Endpoints::LLAMA_CPP_ULTRA)
                  .id(ModelIds::FAST)
                  .timeout(30)
                  .server_type(:llama_cpp)
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
        ENDPOINTS.transform_values do |config|
          check_endpoint(config[:endpoint])
        end
      end

      def check_endpoint(endpoint)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = get("#{endpoint}/models", headers: {}, allow_private: true, timeout: 5.0)
        build_healthy_result(response, start)
      rescue Faraday::TimeoutError then { status: :timeout, latency_ms: nil, models: [] }
      rescue Faraday::ConnectionFailed => e then { status: :unreachable, error: e.message, models: [] }
      rescue StandardError => e then { status: :error, error: e.message, models: [] }
      end

      def build_healthy_result(response, start)
        latency = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round
        models = JSON.parse(response.body)["data"]&.map { |m| m["id"] } || []
        { status: :healthy, latency_ms: latency, models: models.first(5) }
      end

      def any_healthy?
        check_all.values.any? { |s| s[:status] == :healthy }
      end

      def report
        lines = ["Infrastructure Health Check", "=" * 40]
        lines.concat(configuration_notice) unless Endpoints.configured?
        check_all.each { |name, status| lines.concat(format_status(name, status)) }
        lines.join("\n")
      end

      def configuration_notice
        ["", "NOTE: Using default localhost URLs.", "Copy .env.example to .env and configure your endpoints.", ""]
      end

      def format_status(name, status)
        icon = status[:status] == :healthy ? "[OK]" : "[--]"
        lines = ["#{icon} #{name}: #{status[:status]}"]
        lines << "   Latency: #{status[:latency_ms]}ms" if status[:latency_ms]
        lines << "   Models: #{status[:models].join(", ")}" if status[:models].any?
        lines << "   Error: #{status[:error]}" if status[:error]
        lines
      end
    end
  end
end
