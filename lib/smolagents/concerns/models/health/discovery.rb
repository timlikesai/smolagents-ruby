module Smolagents
  module Concerns
    module ModelHealth
      # Model discovery and change detection. Uses Http concern for SSRF-protected requests.
      module Discovery
        CACHE_TTL_SECONDS = 60
        private_constant :CACHE_TTL_SECONDS

        def self.included(base)
          base.include(Events::Emitter)
          base.include(Concerns::Http)
          base.attr_reader :last_known_model, :model_change_callbacks
        end

        def initialize_discovery
          @model_change_callbacks = []
          @last_known_model = @models_cache = @models_cache_time = nil
        end

        def available_models(force_refresh: false)
          return @models_cache if @models_cache && !force_refresh && cache_valid?

          refresh_models
        end

        def loaded_model
          models = available_models
          models.find(&:loaded) || models.find { |m| m.id == model_id }
        rescue DiscoveryError => e
          block_given? ? yield(e) : raise
        end

        def model_changed?
          return false unless @last_known_model

          (current = loaded_model&.id) && current != @last_known_model
        rescue DiscoveryError
          false
        end

        def cache_valid? = !!(@models_cache_time && (Time.now - @models_cache_time) < CACHE_TTL_SECONDS)

        def refresh_models(fallback_to_cache: true)
          @models_cache = parse_models_response(models_request)
          @models_cache_time = Time.now
          emit_model_discovered_events(@models_cache)
          @models_cache
        rescue StandardError => e
          return @models_cache if fallback_to_cache && @models_cache

          raise DiscoveryError.model_query_failed(e.message)
        end

        def notify_model_change # rubocop:disable Naming/PredicateMethod -- command, not predicate
          return false unless model_changed?

          current = loaded_model&.id
          emit_model_changed(@last_known_model, current)
          @model_change_callbacks.each { |cb| cb.call(@last_known_model, current) }
          @last_known_model = current
          true
        end

        def on_model_change(&block)
          raise ArgumentError, "Block required for on_model_change" unless block

          @model_change_callbacks << block
        end

        private

        # Emit discovery events for each model.
        # @param models [Array<ModelInfo>] Models to emit events for
        # @return [void]
        def emit_model_discovered_events(models)
          models.each { emit(Events::ModelDiscovered.create(model_id: it.id, provider: it.owned_by, capabilities: {})) }
        end

        # Emit model change event.
        # @param from_model_id [String] Previous model ID
        # @param to_model_id [String] New model ID
        # @return [void]
        def emit_model_changed(from_model_id, to_model_id)
          emit(Events::ModelChanged.create(from_model_id:, to_model_id:))
        end

        # Request models list from API.
        # @param timeout [Float, nil] Request timeout in seconds
        # @return [Hash] Parsed models API response
        def models_request(timeout: nil)
          return @client.models.list if @client.respond_to?(:models) && @client.models.respond_to?(:list)

          JSON.parse(get(models_endpoint_uri, headers: auth_headers, allow_private: true, timeout:).body)
        end

        # Get authorization headers for API requests.
        # @return [Hash] Headers with Bearer token if API key is set
        def auth_headers = @api_key && @api_key != "not-needed" ? { "Authorization" => "Bearer #{@api_key}" } : {}

        # Build models endpoint URI.
        # @return [String] Full URI to /v1/models endpoint
        def models_endpoint_uri
          base = @client&.uri_base || @api_base || "https://api.openai.com/v1"
          "#{base.sub(%r{/+$}, "")}/models"
        end

        # Parse API response into ModelInfo objects.
        # @param response [Hash, Object] API response (models list wrapper)
        # @return [Array<ModelInfo>] Parsed model information
        def parse_models_response(response)
          data = response.is_a?(Hash) ? response : response.to_h
          (data["data"] || data[:data] || []).map { build_model_info(it) }
        end

        # Build ModelInfo from raw model data.
        # @param model_data [Hash] Model data from API
        # @return [ModelInfo] Constructed model information
        def build_model_info(model_data)
          ModelInfo.new(
            id: model_data["id"] || model_data[:id],
            object: model_data["object"] || model_data[:object] || "model",
            created: model_data["created"] || model_data[:created],
            owned_by: model_data["owned_by"] || model_data[:owned_by],
            loaded: model_data["loaded"] || model_data[:loaded]
          )
        end
      end
    end
  end
end
