require "json"
require "net/http"
require "uri"

module Smolagents
  module Concerns
    module Resilience
      # Probes LM Studio 0.4.0+ servers for model capabilities.
      #
      # LM Studio's `/api/v1/models` endpoint returns detailed capability info:
      # - `trained_for_tool_use`: Whether model supports native function calling
      # - `vision`: Whether model supports image inputs
      # - `max_context_length`: Maximum context window size
      #
      # @example Probe for model capabilities
      #   probe = LmStudioProbe.new("http://localhost:1234")
      #   result = probe.fetch_model_capabilities("qwen3-coder-30b")
      #   result[:trained_for_tool_use]  # => true
      #
      # @see https://lmstudio.ai/blog/0.4.0 LM Studio 0.4.0 release notes
      module LmStudioProbe
        PROBE_TIMEOUT = 5 # seconds
        API_MODELS_PATH = "/api/v1/models".freeze

        # Result of probing a model's capabilities.
        ModelCapabilities = Data.define(
          :model_key,
          :trained_for_tool_use,
          :vision,
          :max_context_length,
          :format,
          :architecture,
          :quantization
        ) do
          def tools_supported? = trained_for_tool_use == true
          def vision_supported? = vision == true
        end

        # Result of probing a server's available models.
        ServerProbeResult = Data.define(:models, :probed_at, :success, :error) do
          def success? = success
          def failed? = !success

          def find_model(model_id)
            models.find { |m| model_matches?(m.model_key, model_id) }
          end

          private

          # Flexible model matching that handles various ID formats:
          # - Exact match: "qwen3-coder" == "qwen3-coder"
          # - Prefix match: "lmstudio/qwen3-coder" ends with "/qwen3-coder"
          # - Substring in key: "qwen3-coder-30b-a3b-instruct" includes "qwen3-coder"
          # - Substring in id: "lmstudio/qwen3-coder" includes "qwen3-coder"
          def model_matches?(key, id)
            key == id ||
              key.end_with?("/#{id}") ||
              key.include?(id) ||
              id.include?(key)
          end
        end

        class << self
          # Probe an LM Studio server for available models and their capabilities.
          #
          # @param base_url [String] Server base URL (e.g., "http://localhost:1234")
          # @param timeout [Integer] Request timeout in seconds
          # @return [ServerProbeResult] Probe result with models and capabilities
          def probe(base_url, timeout: PROBE_TIMEOUT)
            uri = build_probe_uri(base_url)
            response = fetch_with_timeout(uri, timeout)
            parse_response(response)
          rescue StandardError => e
            ServerProbeResult.new(
              models: [],
              probed_at: Time.now,
              success: false,
              error: e.message
            )
          end

          # Probe for a specific model's capabilities.
          #
          # @param base_url [String] Server base URL
          # @param model_id [String] Model identifier to look up
          # @param timeout [Integer] Request timeout in seconds
          # @return [ModelCapabilities, nil] Model capabilities or nil if not found
          def probe_model(base_url, model_id, timeout: PROBE_TIMEOUT)
            result = probe(base_url, timeout:)
            return nil unless result.success?

            result.find_model(model_id)
          end

          private

          def build_probe_uri(base_url)
            uri = URI.parse(base_url.to_s.chomp("/"))
            uri.path = API_MODELS_PATH
            uri
          end

          def fetch_with_timeout(uri, timeout)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = uri.scheme == "https"
            http.open_timeout = timeout
            http.read_timeout = timeout

            request = Net::HTTP::Get.new(uri)
            request["Accept"] = "application/json"

            http.request(request)
          end

          def parse_response(response)
            return error_result("HTTP #{response.code}: #{response.message}") unless response.is_a?(Net::HTTPSuccess)

            data = JSON.parse(response.body)
            success_result(parse_models(data["models"] || []))
          end

          def success_result(models)
            ServerProbeResult.new(models:, probed_at: Time.now, success: true, error: nil)
          end

          def error_result(message)
            ServerProbeResult.new(models: [], probed_at: Time.now, success: false, error: message)
          end

          def parse_models(models_data) = models_data.filter_map { |m| parse_model(m) }

          def parse_model(model_data)
            return nil unless parseable_model?(model_data)

            build_model_capabilities(model_data)
          end

          def parseable_model?(data) = data.is_a?(Hash) && data["type"] != "embedding"

          def build_model_capabilities(data)
            caps = data["capabilities"] || {}
            ModelCapabilities.new(
              model_key: data["key"],
              trained_for_tool_use: caps["trained_for_tool_use"],
              vision: caps["vision"],
              max_context_length: data["max_context_length"],
              format: data["format"],
              architecture: data["architecture"],
              quantization: format_quantization(data["quantization"])
            )
          end

          def format_quantization(quant)
            return nil unless quant.is_a?(Hash)

            "#{quant["name"]} (#{quant["bits_per_weight"]}bit)"
          end
        end
      end
    end
  end
end
