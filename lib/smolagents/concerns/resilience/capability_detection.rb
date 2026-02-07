require_relative "lm_studio_probe"

module Smolagents
  module Concerns
    module Resilience
      # Detects and caches server capabilities through probing and error learning.
      #
      # Provides runtime capability detection for inference endpoints. Caches
      # results per-endpoint and learns from 400 errors to update capability state.
      #
      # For LM Studio 0.4.0+ servers, probes `/api/v1/models` to get actual model
      # capabilities (trained_for_tool_use, vision, max_context_length).
      #
      # @example Basic usage
      #   include CapabilityDetection
      #
      #   caps = detect_capabilities(base_url: "http://localhost:1234/v1")
      #   if caps.supports_tools
      #     # Include tools in request
      #   end
      #
      # @example With model-specific probing (LM Studio 0.4.0+)
      #   caps = detect_capabilities(
      #     base_url: "http://localhost:1234/v1",
      #     model_id: "qwen3-coder-30b"
      #   )
      #   caps.supports_tools  # => true (from trained_for_tool_use)
      #   caps.probed?         # => true
      #
      # @example Learning from errors
      #   learn_from_error(
      #     base_url: "http://localhost:1234/v1",
      #     error: api_error,
      #     attempted_feature: :supports_tools
      #   )
      #
      # @see Types::ServerCapability
      # @see Types::ServerType
      # @see LmStudioProbe For LM Studio 0.4.0 API probing
      module CapabilityDetection
        CACHE_TTL = 3600 # 1 hour

        def self.included(base)
          base.extend(ClassMethods)
        end

        # Class-level cache and mutex for thread safety.
        module ClassMethods
          def capability_cache
            @capability_cache ||= {}
          end

          def capability_cache_mutex
            @capability_cache_mutex ||= Mutex.new
          end
        end

        # Detect capabilities for an endpoint.
        #
        # Returns cached capabilities if fresh, otherwise builds from server type.
        # For LM Studio 0.4.0+ servers, probes `/api/v1/models` for actual capabilities.
        #
        # @param base_url [String] Base URL for the endpoint
        # @param server_type [Symbol, nil] Optional server type override
        # @param model_id [String, nil] Model ID for model-specific capability probing
        # @param probe [Boolean] Whether to probe for capabilities (default: true for LM Studio)
        # @return [Types::ServerCapability]
        def detect_capabilities(base_url:, server_type: nil, model_id: nil, probe: true)
          cache_key = build_cache_key(base_url, model_id)

          cached = cache_mutex.synchronize { cache[cache_key] }
          return cached if cached && !stale?(cached)

          type = resolve_server_type(server_type, base_url)
          capability = build_capability(base_url:, type:, model_id:, probe:)

          emit_capability_detected(base_url, type, capability) if respond_to?(:emit, true)

          cache_mutex.synchronize { cache[cache_key] = capability }
          capability
        end

        # Learn from a runtime error.
        #
        # When we get a 400 error indicating a capability mismatch, update
        # the cached capabilities to avoid repeating the same mistake.
        #
        # @param base_url [String] Base URL for the endpoint
        # @param error [Exception] The error that occurred
        # @param attempted_feature [Symbol] The feature that was attempted
        # @return [void]
        def learn_from_error(base_url:, error:, attempted_feature:)
          cache_key = normalize_url(base_url)

          cache_mutex.synchronize do
            current = cache[cache_key]
            return unless current

            if capability_error?(error)
              updated = current.with_learned(attempted_feature, false)
              cache[cache_key] = updated
              emit_capability_learned(base_url, attempted_feature) if respond_to?(:emit, true)
            end
          end
        end

        # Get cached capabilities for a URL.
        #
        # @param base_url [String] Base URL
        # @return [Types::ServerCapability, nil]
        def cached_capabilities(base_url:)
          cache_mutex.synchronize { cache[normalize_url(base_url)] }
        end

        # Clear capability cache for a URL or all URLs.
        #
        # @param base_url [String, nil] URL to clear, or nil for all
        # @return [void]
        def clear_capability_cache(base_url: nil)
          cache_mutex.synchronize do
            if base_url
              cache.delete(normalize_url(base_url))
            else
              cache.clear
            end
          end
        end

        private

        def cache = self.class.capability_cache

        def cache_mutex = self.class.capability_cache_mutex

        def build_cache_key(base_url, model_id)
          key = normalize_url(base_url)
          model_id ? "#{key}:#{model_id}" : key
        end

        def build_capability(base_url:, type:, model_id:, probe:)
          # Try probing if server supports it and we have a model ID
          if probe && type.base_capabilities[:supports_capability_query] && model_id
            probed = probe_lm_studio(base_url, model_id)
            return probed if probed
          end

          # Fall back to base capabilities from server type
          Types::ServerCapability.from_server_type(type)
        end

        def probe_lm_studio(base_url, model_id)
          model_caps = LmStudioProbe.probe_model(base_url, model_id)
          return nil unless model_caps

          Types::ServerCapability.from_lm_studio_probe(model_caps)
        end

        def resolve_server_type(type_override, url)
          if type_override.is_a?(Symbol)
            Types::ServerType.lookup(type_override) || Types::ServerType.infer_from_url(url)
          elsif type_override.is_a?(Types::ServerType)
            type_override
          else
            Types::ServerType.infer_from_url(url)
          end
        end

        def capability_error?(error)
          return false unless error.respond_to?(:response)

          status = error.response&.dig(:status) || error.response&.dig("status")
          status == 400
        end

        def stale?(capability)
          Time.now - capability.detected_at > CACHE_TTL
        end

        def normalize_url(url)
          uri = URI.parse(url.to_s)
          "#{uri.scheme}://#{uri.host}:#{uri.port}"
        rescue URI::InvalidURIError
          url.to_s
        end

        def emit_capability_detected(url, type, capability)
          emit :capability_event, phase: :probed,
                                  url:,
                                  server_type: type.name,
                                  probed: capability.probed?,
                                  supports_tools: capability.supports_tools
        end

        def emit_capability_learned(url, feature)
          emit :capability_event, phase: :learned, url:, feature:, supported: false
        end
      end
    end
  end
end
