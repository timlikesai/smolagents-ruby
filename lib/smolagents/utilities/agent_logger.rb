# frozen_string_literal: true

require "logger"
require "json"

module Smolagents
  # Structured logger for agent operations with context-aware logging.
  # Supports both human-readable (text) and JSON output formats.
  #
  # @example Text format (default)
  #   logger = AgentLogger.new(format: :text)
  #   logger.info("Task started", agent: "CodeAgent", task_id: 123)
  #   # => I, [2025-01-11] INFO -- : Task started | agent=CodeAgent task_id=123
  #
  # @example JSON format (for log aggregation)
  #   logger = AgentLogger.new(format: :json)
  #   logger.info("Task started", agent: "CodeAgent", task_id: 123)
  #   # => {"timestamp":"2025-01-11T12:00:00Z","level":"INFO","message":"Task started","agent":"CodeAgent","task_id":123}
  class AgentLogger
    attr_accessor :level
    attr_reader :format

    DEBUG = 0
    INFO = 1
    WARN = 2
    ERROR = 3

    LEVEL_NAMES = %w[DEBUG INFO WARN ERROR].freeze
    LEVEL_MAP = { DEBUG => Logger::DEBUG, INFO => Logger::INFO, WARN => Logger::WARN, ERROR => Logger::ERROR }.freeze

    # @param output [IO] output stream (default: $stdout)
    # @param level [Integer] log level (DEBUG, INFO, WARN, ERROR)
    # @param format [Symbol] output format (:text or :json)
    def initialize(output: $stdout, level: INFO, format: :text)
      @output = output
      @level = level
      @format = format
      @logger = Logger.new(output)
      @logger.level = LEVEL_MAP[level] || Logger::INFO
      @logger.formatter = method(:format_message) if format == :json
    end

    def debug(message, **context) = log(DEBUG, message, context)
    def info(message, **context) = log(INFO, message, context)
    def warn(message, **context) = log(WARN, message, context)
    def error(message, **context) = log(ERROR, message, context)

    def step_start(step_number, **context)
      info("Step #{step_number} starting", step: step_number, event: "step_start", **context)
    end

    def step_complete(step_number, duration: nil, **context)
      msg = duration ? "Step #{step_number} complete (#{duration.round(2)}s)" : "Step #{step_number} complete"
      info(msg, step: step_number, event: "step_complete", duration: duration, **context)
    end

    def step_error(step_number, err, **context)
      error("Step #{step_number} failed: #{err.message}", step: step_number, event: "step_error", error_class: err.class.name, **context)
    end

    private

    def log(lvl, message, context)
      return if lvl < @level

      if @format == :json
        @logger.public_send(%i[debug info warn error][lvl]) { { message: message, **context } }
      else
        formatted = context.empty? ? message : "#{message} | #{context.map { |k, v| "#{k}=#{v}" }.join(" ")}"
        @logger.public_send(%i[debug info warn error][lvl], formatted)
      end
    end

    def format_message(severity, time, _progname, msg)
      data = msg.is_a?(Hash) ? msg : { message: msg }
      "#{JSON.generate({ timestamp: time.utc.iso8601, level: severity, **data })}\n"
    end
  end
end
