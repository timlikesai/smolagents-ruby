require "logger"
require "json"

module Smolagents
  module Logging
    # Structured logger for agent execution with step tracking.
    #
    # Provides logging tailored for AI agent workflows, including:
    # - Step lifecycle events (start, complete, error)
    # - Structured context via keyword arguments
    # - JSON output format for observability systems
    #
    # @example Basic usage
    #   logger = AgentLogger.new(level: AgentLogger::DEBUG)
    #   logger.info("Starting agent", task: "research")
    #
    # @example Step tracking
    #   logger.step_start(1, tool: "search")
    #   # ... execute step ...
    #   logger.step_complete(1, duration: 0.5, results: 10)
    #
    # @example JSON format for log aggregation
    #   logger = AgentLogger.new(format: :json, output: File.open("agent.log", "w"))
    #   logger.info("Tool call", tool: "search", query: "Ruby gems")
    #   # => {"timestamp":"2024-01-15T10:30:00Z","level":"INFO","message":"Tool call","tool":"search"}
    #
    class AgentLogger
      # @return [Integer] Current log level
      attr_accessor :level

      # @return [Symbol] Output format (:text or :json)
      attr_reader :format

      # @return [Integer] Debug level constant (0). Used to suppress all but debug messages.
      DEBUG = 0

      # @return [Integer] Info level constant (1). Standard information logging.
      INFO = 1

      # @return [Integer] Warning level constant (2). Logs warnings and higher severity.
      WARN = 2

      # @return [Integer] Error level constant (3). Logs only errors.
      ERROR = 3

      # @return [Array<String>] String names for log levels indexed by level constant.
      #   Maps level integers to human-readable names: ["DEBUG", "INFO", "WARN", "ERROR"]
      LEVEL_NAMES = %w[DEBUG INFO WARN ERROR].freeze

      # @return [Hash{Integer => Integer}] Mapping from AgentLogger level constants to Ruby Logger levels.
      #   Converts between AgentLogger's 0-3 range and Logger's standard levels for internal logging.
      #   Example: {0 => 0, 1 => 1, 2 => 2, 3 => 3} mapped to Logger constants.
      LEVEL_MAP = { DEBUG => Logger::DEBUG, INFO => Logger::INFO, WARN => Logger::WARN, ERROR => Logger::ERROR }.freeze

      # Creates a new AgentLogger.
      #
      # @param output [IO] Output stream (default: $stdout)
      # @param level [Integer] Log level (default: INFO)
      # @param format [Symbol] Output format - :text or :json (default: :text)
      def initialize(output: $stdout, level: INFO, format: :text)
        @output = output
        @level = level
        @format = format
        @logger = Logger.new(output)
        @logger.level = LEVEL_MAP[level] || Logger::INFO
        @logger.formatter = method(:format_message) if format == :json
      end

      # Logs a debug message.
      #
      # @param message [String] Log message
      # @param context [Hash] Additional context as keyword arguments
      def debug(message, **context) = log(DEBUG, message, context)

      # Logs an info message.
      #
      # @param message [String] Log message
      # @param context [Hash] Additional context as keyword arguments
      def info(message, **context) = log(INFO, message, context)

      # Logs a warning message.
      #
      # @param message [String] Log message
      # @param context [Hash] Additional context as keyword arguments
      def warn(message, **context) = log(WARN, message, context)

      # Logs an error message.
      #
      # @param message [String] Log message
      # @param context [Hash] Additional context as keyword arguments
      def error(message, **context) = log(ERROR, message, context)

      # Logs the start of an agent step.
      #
      # @param step_number [Integer] Step number (1-indexed)
      # @param context [Hash] Additional context
      def step_start(step_number, **context)
        info("Step #{step_number} starting", step: step_number, event: "step_start", **context)
      end

      # Logs the completion of an agent step.
      #
      # @param step_number [Integer] Step number (1-indexed)
      # @param duration [Float, nil] Step duration in seconds
      # @param context [Hash] Additional context
      def step_complete(step_number, duration: nil, **context)
        msg = duration ? "Step #{step_number} complete (#{duration.round(2)}s)" : "Step #{step_number} complete"
        info(msg, step: step_number, event: "step_complete", duration:, **context)
      end

      # Logs an error during an agent step.
      #
      # @param step_number [Integer] Step number (1-indexed)
      # @param err [Exception] The error that occurred
      # @param context [Hash] Additional context
      def step_error(step_number, err, **context)
        error("Step #{step_number} failed: #{err.message}", step: step_number, event: "step_error",
                                                            error_class: err.class.name, **context)
      end

      private

      def log(lvl, message, context)
        return if lvl < @level

        if @format == :json
          @logger.public_send(%i[debug info warn error][lvl]) { { message:, **context } }
        else
          formatted = context.empty? ? message : "#{message} | #{context.map { |key, val| "#{key}=#{val}" }.join(" ")}"
          @logger.public_send(%i[debug info warn error][lvl], formatted)
        end
      end

      def format_message(severity, time, _progname, msg)
        data = msg.is_a?(Hash) ? msg : { message: msg }
        "#{JSON.generate({ timestamp: time.utc.iso8601, level: severity, **data })}\n"
      end
    end
  end
end
