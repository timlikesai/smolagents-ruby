module Smolagents
  module Concerns
    module ModelHealth
      # Model discovery and change detection
      module Discovery
        # @return [Array<ModelInfo>] List of available models
        # @raise [AgentError] If the models endpoint is not available
        def available_models
          parse_models_response(models_request)
        rescue StandardError => e
          raise AgentError, "Failed to query models: #{e.message}"
        end

        # @return [ModelInfo, nil] The loaded model info, or nil if unknown
        def loaded_model
          models = available_models
          models.find(&:loaded) || models.find { |m| m.id == model_id }
        rescue AgentError
          nil
        end

        # @yield [old_model_id, new_model_id] Called when loaded model changes
        def on_model_change(&block)
          (@model_change_callbacks ||= []) << block
        end

        # @return [Boolean] true if model changed
        def model_changed?
          current = loaded_model&.id
          changed = @last_known_model && current && current != @last_known_model
          @model_change_callbacks&.each { |cb| cb.call(@last_known_model, current) } if changed
          @last_known_model = current
          changed
        end

        private

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
