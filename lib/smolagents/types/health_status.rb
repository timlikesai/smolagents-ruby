module Smolagents
  module Types
    # Health check result with status, latency, and optional error.
    #
    # Immutable result of a model server health check operation.
    # Tracks server response time, error conditions, and model availability.
    #
    # @example Creating a healthy status
    #   status = HealthStatus.healthy(
    #     model_id: "gpt-4",
    #     latency_ms: 250,
    #     details: { model_count: 5 }
    #   )
    #   status.healthy?  # => true
    #
    # @example Creating an unhealthy status
    #   status = HealthStatus.unhealthy(
    #     model_id: "gpt-4",
    #     error: "Connection refused",
    #     latency_ms: 0
    #   )
    #   status.unhealthy?  # => true
    #
    # @example Pattern matching
    #   case check_health(model)
    #   in HealthStatus[status: :healthy, latency_ms:] if latency_ms < 500
    #     :fast_and_healthy
    #   in HealthStatus[status: :degraded]
    #     :slow_but_working
    #   in HealthStatus[status: :unhealthy, error:]
    #     log_error(error)
    #   end
    #
    # @see Concerns::ModelHealth For health checking concern
    HealthStatus = Data.define(:status, :latency_ms, :error, :checked_at, :model_id, :details) do
      include TypeSupport::Deconstructable

      # Whether the model is healthy (fast response, no errors).
      # @return [Boolean]
      def healthy? = status == :healthy

      # Whether the model is degraded (slow but responding).
      # @return [Boolean]
      def degraded? = status == :degraded

      # Whether the model is unhealthy (errors or timeouts).
      # @return [Boolean]
      def unhealthy? = status == :unhealthy

      # Whether there was an error during the health check.
      # @return [Boolean]
      def error? = !error.nil?

      # Serializable hash representation.
      # @return [Hash]
      def to_h
        {
          status:,
          latency_ms:,
          error:,
          checked_at: checked_at&.iso8601,
          model_id:,
          details:
        }
      end

      class << self
        # Creates a healthy status result.
        #
        # @param model_id [String] The model being checked
        # @param latency_ms [Integer] Response latency in milliseconds
        # @param details [Hash] Additional metadata
        # @return [HealthStatus]
        def healthy(model_id:, latency_ms:, details: {})
          new(
            status: :healthy,
            latency_ms:,
            error: nil,
            checked_at: Time.now,
            model_id:,
            details:
          )
        end

        # Creates a degraded status result.
        #
        # @param model_id [String] The model being checked
        # @param latency_ms [Integer] Response latency in milliseconds
        # @param details [Hash] Additional metadata
        # @return [HealthStatus]
        def degraded(model_id:, latency_ms:, details: {})
          new(
            status: :degraded,
            latency_ms:,
            error: nil,
            checked_at: Time.now,
            model_id:,
            details:
          )
        end

        # Creates an unhealthy status result.
        #
        # @param model_id [String] The model being checked
        # @param error [String] Error message describing the failure
        # @param latency_ms [Integer] Response latency (may be 0 for timeouts)
        # @param details [Hash] Additional metadata
        # @return [HealthStatus]
        def unhealthy(model_id:, error:, latency_ms: 0, details: {})
          new(
            status: :unhealthy,
            latency_ms:,
            error:,
            checked_at: Time.now,
            model_id:,
            details:
          )
        end
      end
    end
  end
end
