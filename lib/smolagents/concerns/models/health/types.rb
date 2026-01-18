module Smolagents
  module Concerns
    module ModelHealth
      # Health check result with status, latency, and optional error.
      #
      # Immutable result of a model server health check operation.
      # Tracks server response time, error conditions, and model availability.
      #
      # @!attribute [r] status
      #   @return [Symbol] Health status (:healthy, :degraded, or :unhealthy)
      # @!attribute [r] latency_ms
      #   @return [Integer] Request latency in milliseconds
      # @!attribute [r] error
      #   @return [String, nil] Error message if unhealthy, nil otherwise
      # @!attribute [r] checked_at
      #   @return [Time] When the health check was performed
      # @!attribute [r] model_id
      #   @return [String] The model being checked
      # @!attribute [r] details
      #   @return [Hash] Additional metadata (model count, examples, etc.)
      HealthStatus = Data.define(:status, :latency_ms, :error, :checked_at, :model_id, :details) do
        def healthy? = status == :healthy
        def degraded? = status == :degraded
        def unhealthy? = status == :unhealthy

        # @return [Hash] Serializable hash representation
        def to_h = { status:, latency_ms:, error:, checked_at: checked_at.iso8601, model_id:, details: }
      end

      # Model information from /v1/models endpoint.
      #
      # Immutable record of a model available from the server.
      #
      # @!attribute [r] id
      #   @return [String] Model identifier (e.g., "gpt-4")
      # @!attribute [r] object
      #   @return [String] Object type (typically "model")
      # @!attribute [r] created
      #   @return [Integer, nil] Unix timestamp of model creation
      # @!attribute [r] owned_by
      #   @return [String, nil] Organization owning the model
      # @!attribute [r] loaded
      #   @return [Boolean, nil] Whether model is currently loaded in server memory
      ModelInfo = Data.define(:id, :object, :created, :owned_by, :loaded) do
        # @return [Hash] Serializable hash representation
        def to_h = { id:, object:, created:, owned_by:, loaded: }
      end
    end
  end
end
