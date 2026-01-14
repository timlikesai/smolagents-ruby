require "securerandom"

module Smolagents
  module Concerns
    # Audit logging for API calls with request tracking and timing.
    #
    # Wraps operations with automatic logging of:
    # - Request ID (UUID for tracing)
    # - Service and operation names
    # - Duration in milliseconds
    # - Success/error status
    # - Error class names
    #
    # Integrates with {Smolagents.audit_logger} for flexible backend support.
    #
    # @example Basic usage
    #   with_audit_log(service: "openai", operation: "chat") do
    #     @client.chat(messages: messages)
    #   end
    #   # Logs: service=openai, operation=chat, duration_ms=145.5, status=success
    #
    # @example With error tracking
    #   with_audit_log(service: "api", operation: "search") do
    #     raise "Connection failed"
    #   end
    #   # Logs: status=error, error=RuntimeError
    #
    # @see Api Which uses this for API call tracking
    module Auditable
      # Execute a block with audit logging
      #
      # Automatically tracks request ID, duration, and success/error status.
      # Logs are sent to {Smolagents.audit_logger} if configured.
      #
      # @param service [String] Service name (e.g., "openai", "anthropic")
      # @param operation [String] Operation name (e.g., "chat", "embed")
      # @yield Block containing the operation to audit
      # @return [Object] Result of the block
      # @raise [StandardError] Re-raises any exception from block after logging
      def with_audit_log(service:, operation:)
        request_id = SecureRandom.uuid
        start_time = monotonic_now

        result = yield
        log_audit(request_id:, service:, operation:, start_time:, status: :success)
        result
      rescue StandardError => e
        log_audit(request_id:, service:, operation:, start_time:, status: :error, error: e.class.name)
        raise
      end

      private

      def monotonic_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      def log_audit(request_id:, service:, operation:, start_time:, status:, error: nil)
        log_request(request_id:, service:, operation:, duration_ms: ((monotonic_now - start_time) * 1000).round(2), status:, error:)
      end

      # Log a request to the audit logger
      #
      # Handles flexible logger interfaces that may or may not support kwargs.
      # Falls back to formatted string if logger doesn't support keyword arguments.
      #
      # @param attrs [Hash] Attributes to log (request_id, service, operation, etc.)
      # @return [void]
      # @api private
      def log_request(attrs)
        return unless Smolagents.audit_logger

        message = "HTTP Request"
        logger = Smolagents.audit_logger

        begin
          logger.info(message, **attrs)
        rescue ArgumentError => e
          raise unless e.message.include?("wrong number of arguments") || e.message.include?("unknown keyword")

          formatted = "#{message} | #{attrs.map { |key, val| "#{key}=#{val}" }.join(" ")}"
          logger.info(formatted)
        end
      end
    end
  end
end
