module Smolagents
  module Types
    # Model information from /v1/models endpoint.
    #
    # Immutable record of a model available from a server, following
    # the OpenAI API models response format.
    #
    # @example Creating model info
    #   info = ModelInfo.new(
    #     id: "gpt-4",
    #     object: "model",
    #     created: 1686935002,
    #     owned_by: "openai",
    #     loaded: true
    #   )
    #
    # @example Pattern matching on loaded state
    #   case model_info
    #   in ModelInfo[loaded: true]
    #     :ready_to_use
    #   in ModelInfo[loaded: false]
    #     warmup_model(model_info.id)
    #   end
    #
    # @see Concerns::ModelHealth For health checking that uses this type
    ModelInfo = Data.define(:id, :object, :created, :owned_by, :loaded) do
      include TypeSupport::Deconstructable

      # Whether the model is currently loaded in server memory.
      # @return [Boolean]
      def loaded? = loaded == true

      # Serializable hash representation.
      # @return [Hash]
      def to_h = { id:, object:, created:, owned_by:, loaded: }

      class << self
        # Creates ModelInfo from an API response hash.
        #
        # @param hash [Hash] API response with model data
        # @return [ModelInfo]
        def from_api(hash)
          new(
            id: hash["id"] || hash[:id],
            object: hash["object"] || hash[:object] || "model",
            created: hash["created"] || hash[:created],
            owned_by: hash["owned_by"] || hash[:owned_by],
            loaded: hash["loaded"] || hash[:loaded]
          )
        end
      end
    end
  end
end
