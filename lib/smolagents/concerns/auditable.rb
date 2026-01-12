# frozen_string_literal: true

require "securerandom"

module Smolagents
  module Concerns
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
      rescue StandardError => e
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

        message = "HTTP Request"
        logger = Smolagents.audit_logger

        begin
          logger.info(message, **attrs)
        rescue ArgumentError => e
          raise unless e.message.include?("wrong number of arguments") || e.message.include?("unknown keyword")

          formatted = "#{message} | #{attrs.map { |k, v| "#{k}=#{v}" }.join(" ")}"
          logger.info(formatted)
        end
      end
    end
  end
end
