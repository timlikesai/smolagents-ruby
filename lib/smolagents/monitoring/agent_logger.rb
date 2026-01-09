# frozen_string_literal: true

require "logger"

module Smolagents
  module Monitoring
    # Structured logger for agent operations.
    # Provides context-aware logging with log levels and formatting.
    #
    # @example Basic usage
    #   logger = AgentLogger.new
    #   logger.info("Starting task", task: "search")
    #   logger.error("Failed", error: error.message)
    class AgentLogger
      attr_accessor :level

      # Log levels
      DEBUG = 0
      INFO = 1
      WARN = 2
      ERROR = 3

      def initialize(output: $stdout, level: INFO)
        @output = output
        @level = level
        @logger = Logger.new(output)
        @logger.level = map_level(level)
      end

      # Log debug message.
      #
      # @param message [String] log message
      # @param context [Hash] additional context
      def debug(message, **context)
        log(DEBUG, message, context)
      end

      # Log info message.
      #
      # @param message [String] log message
      # @param context [Hash] additional context
      def info(message, **context)
        log(INFO, message, context)
      end

      # Log warning message.
      #
      # @param message [String] log message
      # @param context [Hash] additional context
      def warn(message, **context)
        log(WARN, message, context)
      end

      # Log error message.
      #
      # @param message [String] log message
      # @param context [Hash] additional context
      def error(message, **context)
        log(ERROR, message, context)
      end

      # Log step start.
      #
      # @param step_number [Integer] step number
      # @param context [Hash] additional context
      def step_start(step_number, **context)
        info("Step #{step_number} starting", **context)
      end

      # Log step complete.
      #
      # @param step_number [Integer] step number
      # @param duration [Float] step duration in seconds
      # @param context [Hash] additional context
      def step_complete(step_number, duration: nil, **context)
        msg = "Step #{step_number} complete"
        msg += " (#{duration.round(2)}s)" if duration
        info(msg, **context)
      end

      # Log step error.
      #
      # @param step_number [Integer] step number
      # @param error [Exception] error that occurred
      # @param context [Hash] additional context
      def step_error(step_number, error, **context)
        error("Step #{step_number} failed: #{error.message}", error: error.class.name, **context)
      end

      private

      def log(level, message, context)
        return if level < @level

        formatted = format_message(message, context)
        case level
        when DEBUG then @logger.debug(formatted)
        when INFO then @logger.info(formatted)
        when WARN then @logger.warn(formatted)
        when ERROR then @logger.error(formatted)
        end
      end

      def format_message(message, context)
        return message if context.empty?

        context_str = context.map { |k, v| "#{k}=#{v}" }.join(" ")
        "#{message} | #{context_str}"
      end

      def map_level(level)
        case level
        when DEBUG then Logger::DEBUG
        when INFO then Logger::INFO
        when WARN then Logger::WARN
        when ERROR then Logger::ERROR
        else Logger::INFO
        end
      end
    end
  end
end
