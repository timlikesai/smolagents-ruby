require "singleton"

module Smolagents
  module Logging
    # A no-op logger that silently discards all log messages.
    #
    # NullLogger implements the same interface as AgentLogger but does nothing.
    # This is the Null Object pattern - it provides safe defaults when no logger
    # is configured, avoiding nil checks throughout the codebase.
    #
    # @example Use as default logger
    #   @logger = logger || NullLogger.instance
    #   @logger.info("This goes nowhere")  # No-op
    #
    # @example Check if logging is disabled
    #   logger.null? # => true (for NullLogger)
    #
    class NullLogger
      include Singleton

      # @return [Symbol] Always returns :off
      def level = :off

      # @param _ [Object] Ignored
      # @return [nil]
      def level=(_)
        nil
      end

      # Log a debug message (no-op).
      # @param _message [String] Ignored
      # @param _context [Hash] Ignored
      # @return [nil]
      def debug(_message = nil, **) = nil

      # Log an info message (no-op).
      # @param _message [String] Ignored
      # @param _context [Hash] Ignored
      # @return [nil]
      def info(_message = nil, **) = nil

      # Log a warning message (no-op).
      # @param _message [String] Ignored
      # @param _context [Hash] Ignored
      # @return [nil]
      def warn(_message = nil, **) = nil

      # Log an error message (no-op).
      # @param _message [String] Ignored
      # @param _context [Hash] Ignored
      # @return [nil]
      def error(_message = nil, **) = nil

      # Log step start (no-op).
      # @param _step_number [Integer] Ignored
      # @param _context [Hash] Ignored
      # @return [nil]
      def step_start(_step_number, **) = nil

      # Log step completion (no-op).
      # @param _step_number [Integer] Ignored
      # @param _duration [Float, nil] Ignored
      # @param _context [Hash] Ignored
      # @return [nil]
      def step_complete(_step_number, _duration: nil, **) = nil

      # Log step error (no-op).
      # @param _step_number [Integer] Ignored
      # @param _err [Exception] Ignored
      # @param _context [Hash] Ignored
      # @return [nil]
      def step_error(_step_number, _err, **) = nil

      # @return [Boolean] Always true for NullLogger
      def null? = true
    end
  end
end
