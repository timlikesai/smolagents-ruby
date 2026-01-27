# Simple logger for test visibility.

module Smolagents
  module Testing
    # A simple stdout logger for test visibility.
    #
    # Unlike NullLogger which discards messages, TestLogger outputs
    # to stdout for debugging tests. Unlike RawOutputLogger which
    # writes to files, this keeps everything in the console.
    #
    # @example Use in tests
    #   agent = Smolagents.agent
    #     .model { mock }
    #     .logging(:verbose)  # Uses TestLogger
    #     .build
    #
    # @see Logging::NullLogger For silent logging
    class TestLogger
      # @return [Symbol] Current log level
      attr_accessor :level

      # @return [Boolean] Whether to show verbose output
      attr_accessor :verbose

      # @param level [Symbol] Log level (:debug, :info, :warn, :error)
      # @param verbose [Boolean] Show extra detail
      def initialize(level: :info, verbose: false)
        @level = level
        @verbose = verbose
      end

      # Log a debug message.
      # @param message [String] Message to log
      # @return [nil]
      def debug(message = nil, **)
        return unless level == :debug

        puts "[DEBUG] #{message}" if message
      end

      # Log an info message.
      # @param message [String] Message to log
      # @return [nil]
      def info(message = nil, **)
        return unless %i[debug info].include?(level)

        puts "[INFO] #{message}" if message
      end

      # Log a warning message.
      # @param message [String] Message to log
      # @return [nil]
      def warn(message = nil, **)
        return unless %i[debug info warn].include?(level)

        puts "[WARN] #{message}" if message
      end

      # Log an error message.
      # @param message [String] Message to log
      # @return [nil]
      def error(message = nil, **)
        puts "[ERROR] #{message}" if message
      end

      # Log step start.
      # @param step_number [Integer] Step number
      # @return [nil]
      def step_start(step_number, **)
        return unless %i[debug info].include?(level)

        puts "  Step #{step_number} starting..."
      end

      # Log step completion.
      # @param step_number [Integer] Step number
      # @param duration [Float, nil] Duration in seconds
      # @return [nil]
      def step_complete(step_number, duration: nil, **)
        return unless %i[debug info].include?(level)

        duration_str = duration ? " (#{(duration * 1000).round}ms)" : ""
        puts "  Step #{step_number} complete#{duration_str}"
      end

      # Log step error.
      # @param step_number [Integer] Step number
      # @param err [Exception] Error that occurred
      # @return [nil]
      def step_error(step_number, err, **)
        puts "  Step #{step_number} ERROR: #{err.message}"
      end

      # @return [Boolean] Always false for TestLogger
      def null? = false
    end
  end
end
