# frozen_string_literal: true

require "securerandom"

module Smolagents
  module Concerns
    # Audit logging for HTTP requests with correlation IDs and timing.
    module Auditable
      def with_audit_log(service:, operation:)
        request_id = SecureRandom.uuid
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        result = yield

        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        log_request(
          request_id: request_id,
          service: service,
          operation: operation,
          duration_ms: (duration * 1000).round(2),
          status: :success
        )

        result
      rescue => e
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        log_request(
          request_id: request_id,
          service: service,
          operation: operation,
          duration_ms: (duration * 1000).round(2),
          status: :error,
          error: e.class.name
        )
        raise
      end

      private

      def log_request(attrs)
        return unless Smolagents.audit_logger

        # Support both structured loggers (with keyword args) and standard Ruby loggers
        message = "HTTP Request"
        logger = Smolagents.audit_logger

        # Check if logger accepts keyword arguments (structured logger like AgentLogger)
        # Standard Logger.info signature: info(progname = nil, &block) or info(message)
        # AgentLogger.info signature: info(message, **context)
        begin
          # Try calling with keyword arguments first (structured logger)
          logger.info(message, **attrs)
        rescue ArgumentError => e
          # Fall back to string formatting for standard Ruby Logger
          if e.message.include?("wrong number of arguments") || e.message.include?("unknown keyword")
            formatted = "#{message} | #{attrs.map { |k, v| "#{k}=#{v}" }.join(" ")}"
            logger.info(formatted)
          else
            raise
          end
        end
      end
    end
  end
end
