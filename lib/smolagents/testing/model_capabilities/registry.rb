require_relative "capability"

module Smolagents
  module Testing
    module ModelCapabilities
      # Registry of known models and their capabilities.
      #
      # Provides querying and filtering of available models.
      # Integrates with LM Studio to discover loaded models.
      #
      # @example Fetch from LM Studio
      #   registry = Registry.from_lm_studio("http://localhost:1234")
      #   registry.each { |caps| puts caps.model_id }
      #
      # @example Filter models
      #   fast_models = registry.select(&:fast?)
      class Registry
        include Enumerable

        attr_reader :models

        def initialize(models = {})
          @models = models.freeze
        end

        # Create registry by discovering models from LM Studio.
        # @param base_url [String] LM Studio base URL
        # @return [Registry] Registry with discovered models
        def self.from_lm_studio(base_url = Config::DEFAULT_LOCAL_BASE_URL)
          new(fetch_models_from_lm_studio(base_url))
        rescue StandardError => e
          warn "Failed to fetch models from LM Studio: #{e.message}"
          new({})
        end

        def self.fetch_models_from_lm_studio(base_url)
          require "net/http"
          require "json"

          data = JSON.parse(Net::HTTP.get(URI("#{base_url}/api/v0/models")))
          data["data"]
            .select { |m| m["state"] == "loaded" }
            .to_h { |m| [m["id"], Capability.from_lm_studio(m)] }
        end

        # @param model_id [String] Model ID to look up
        # @return [Capability, nil] Model capabilities or nil
        def [](model_id) = @models[model_id]

        # @yield [Capability] Each model's capabilities
        def each(&) = @models.values.each(&)

        # @return [Array<String>] All model IDs
        def ids = @models.keys

        # @return [Integer] Number of models
        def size = @models.size

        # @return [Boolean] True if no models
        def empty? = @models.empty?

        # @return [Registry] Models with tool-use capability
        def with_tool_use = select(&:tool_use?)

        # @return [Registry] Vision-capable models
        def with_vision = select(&:vision?)

        # @return [Registry] Fast execution models
        def fast_models = select(&:fast?)

        # @param level [Symbol] Reasoning level
        # @return [Registry] Models with matching reasoning
        def by_reasoning(level) = select { |m| m.reasoning == level }

        # @yield [Capability] Model to test
        # @return [Registry] Filtered registry
        def select
          self.class.new(@models.select { |_, v| yield(v) })
        end

        # @return [Hash{String => Hash}] Model IDs to capability hashes
        def to_h = @models.transform_values(&:to_h)
      end
    end
  end
end
