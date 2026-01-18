module Smolagents
  module Concerns
    module ModelHealth
      # Model discovery and change detection with explicit state management.
      #
      # Provides cached model queries, change detection, and callback support.
      # All state is explicitly initialized via {#initialize_discovery}.
      #
      # @example Basic usage
      #   class MyModel
      #     include Smolagents::Concerns::ModelHealth::Discovery
      #
      #     def initialize
      #       initialize_discovery
      #     end
      #   end
      module Discovery
        # Self-documentation for composable concern introspection.
        def self.provided_methods
          {
            initialization: %i[initialize_discovery],
            queries: %i[available_models loaded_model model_changed? cache_valid?],
            commands: %i[refresh_models notify_model_change],
            callbacks: %i[on_model_change]
          }
        end

        def self.included(base)
          base.include(Events::Emitter)
          base.attr_reader :last_known_model, :model_change_callbacks
        end

        # Explicit initialization - must be called from including class.
        # @return [void]
        def initialize_discovery
          @model_change_callbacks = []
          @last_known_model = nil
          @models_cache = nil
          @models_cache_time = nil
        end

        # === Queries (no side effects) ===

        # @return [Array<ModelInfo>] List of available models (cached)
        # @raise [DiscoveryError] If the models endpoint is not available
        def available_models(force_refresh: false)
          return @models_cache if @models_cache && !force_refresh && cache_valid?

          refresh_models
        end

        # @return [ModelInfo, nil] The loaded model info
        # @raise [DiscoveryError] If discovery fails (unless block given)
        # @yield [error] Block called with error if discovery fails
        def loaded_model
          models = available_models
          models.find(&:loaded) || models.find { |m| m.id == model_id }
        rescue DiscoveryError => e
          return yield(e) if block_given?

          raise
        end

        # Pure query - checks if model changed without side effects.
        # @return [Boolean] true if current model differs from last known
        def model_changed?
          return false unless @last_known_model

          current = loaded_model&.id
          return false unless current

          current != @last_known_model
        rescue DiscoveryError
          false
        end

        # @return [Boolean] true if cache is still valid
        def cache_valid?
          return false unless @models_cache_time

          (Time.now - @models_cache_time) < cache_ttl
        end

        # === Commands (have side effects) ===

        # Force refresh the models cache.
        #
        # If discovery fails and a cache exists, returns the stale cache
        # with a degraded status instead of raising. Only raises if no
        # cache exists at all.
        #
        # @param fallback_to_cache [Boolean] Return stale cache on failure (default: true)
        # @return [Array<ModelInfo>] Fresh list of models (or stale cache on failure)
        # @raise [DiscoveryError] If the query fails and no cache exists
        def refresh_models(fallback_to_cache: true)
          @models_cache = parse_models_response(models_request)
          @models_cache_time = Time.now
          emit_model_discovered_events(@models_cache)
          @models_cache
        rescue StandardError => e
          return @models_cache if fallback_to_cache && @models_cache

          raise DiscoveryError.model_query_failed(e.message)
        end

        # Check for model change and notify callbacks if changed.
        # Separated from {#model_changed?} for Command-Query separation.
        # @return [Boolean] true if model changed and callbacks were notified
        # rubocop:disable Naming/PredicateMethod -- command, not predicate
        def notify_model_change
          return false unless model_changed?

          current = loaded_model&.id
          emit_model_changed(@last_known_model, current)
          @model_change_callbacks.each { |cb| cb.call(@last_known_model, current) }
          @last_known_model = current
          true
        end
        # rubocop:enable Naming/PredicateMethod

        # === Callbacks ===

        # Register a callback for model changes.
        # @yield [old_model_id, new_model_id] Called when loaded model changes
        # @raise [ArgumentError] If no block given
        def on_model_change(&block)
          raise ArgumentError, "Block required for on_model_change" unless block

          @model_change_callbacks << block
        end

        private

        def emit_model_discovered_events(models)
          models.each do |model|
            emit(Events::ModelDiscovered.create(
                   model_id: model.id,
                   provider: model.owned_by,
                   capabilities: {}
                 ))
          end
        end

        def emit_model_changed(from_model_id, to_model_id)
          emit(Events::ModelChanged.create(from_model_id:, to_model_id:))
        end

        # seconds
        def cache_ttl = 60

        def models_request(timeout: 10)
          return client.models.list if respond_to?(:client, true) && client.respond_to?(:models)
          return @client.models.list if instance_variable_defined?(:@client) && @client.respond_to?(:models)

          fetch_models_via_http(timeout)
        end

        def fetch_models_via_http(timeout)
          conn = Faraday.new do |f|
            f.options.timeout = timeout
            f.adapter(Faraday.default_adapter)
          end
          JSON.parse(conn.get(models_endpoint_uri) { add_auth_header(it) }.body)
        end

        def add_auth_header(request)
          return unless @api_key && @api_key != "not-needed"

          request.headers["Authorization"] = "Bearer #{@api_key}"
        end

        def models_endpoint_uri
          base = (@client&.uri_base || @api_base || "https://api.openai.com/v1").sub(%r{/+$}, "")
          "#{base}/models"
        end

        def parse_models_response(response)
          data = response.is_a?(Hash) ? response : response.to_h
          (data["data"] || data[:data] || []).map { build_model_info(it) }
        end

        def build_model_info(model)
          ModelInfo.new(
            id: model["id"] || model[:id],
            object: model["object"] || model[:object] || "model",
            created: model["created"] || model[:created],
            owned_by: model["owned_by"] || model[:owned_by],
            loaded: model["loaded"] || model[:loaded]
          )
        end

        def client = @client
      end
    end
  end
end
