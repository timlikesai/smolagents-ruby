# frozen_string_literal: true

require "logger"

module Smolagents
  module Monitoring
    # Structured logger for agent operations with context-aware logging.
    class AgentLogger
      attr_accessor :level

      DEBUG = 0
      INFO = 1
      WARN = 2
      ERROR = 3

      LEVEL_MAP = { DEBUG => Logger::DEBUG, INFO => Logger::INFO, WARN => Logger::WARN, ERROR => Logger::ERROR }.freeze

      def initialize(output: $stdout, level: INFO)
        @output = output
        @level = level
        @logger = Logger.new(output)
        @logger.level = LEVEL_MAP[level] || Logger::INFO
      end

      def debug(message, **context) = log(DEBUG, message, context)
      def info(message, **context) = log(INFO, message, context)
      def warn(message, **context) = log(WARN, message, context)
      def error(message, **context) = log(ERROR, message, context)

      def step_start(step_number, **context) = info("Step #{step_number} starting", **context)
      def step_complete(step_number, duration: nil, **context) = info("Step #{step_number} complete#{" (#{duration.round(2)}s)" if duration}", **context)
      def step_error(step_number, err, **context) = error("Step #{step_number} failed: #{err.message}", error: err.class.name, **context)

      private

      def log(lvl, message, context)
        return if lvl < @level

        formatted = context.empty? ? message : "#{message} | #{context.map { |k, v| "#{k}=#{v}" }.join(" ")}"
        @logger.public_send(%i[debug info warn error][lvl], formatted)
      end
    end
  end
end
