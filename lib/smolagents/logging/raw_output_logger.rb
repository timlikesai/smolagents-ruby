require "json"
require "fileutils"

module Smolagents
  module Logging
    # Logs raw model outputs to disk for debugging and analysis.
    #
    # Every model response is saved with full context so failures can be analyzed.
    # Files are never overwritten - each session creates a new timestamped file.
    #
    # @example Basic usage
    #   logger = RawOutputLogger.new(directory: "logs")
    #   logger.log_run(model_id: "gpt-4", config: "baseline", data: { output: "..." })
    #   logger.close
    #
    # @example With block (auto-closes)
    #   RawOutputLogger.open(directory: "logs") do |logger|
    #     logger.log_run(model_id: "gpt-4", config: "test", data: result_hash)
    #   end
    #
    class RawOutputLogger
      # @return [String] Path to the current log file
      attr_reader :filepath

      # @return [String] Directory where logs are stored
      attr_reader :directory

      # @return [Boolean] Whether the logger is open
      def open? = !@file.nil? && !@file.closed?

      # @return [Integer] Number of entries written
      attr_reader :entry_count

      # Creates and opens a logger, yields it, then closes.
      #
      # @param directory [String] Directory for log files
      # @yield [RawOutputLogger] The opened logger
      # @return [Object] Result of the block
      def self.open(directory:)
        logger = new(directory:)
        begin
          yield(logger)
        ensure
          logger.close
        end
      end

      # Creates a new logger.
      #
      # @param directory [String] Directory for log files (created if missing)
      # @param timestamp [Time] Timestamp for filename (default: now)
      def initialize(directory:, timestamp: Time.now)
        @directory = directory
        @entry_count = 0
        @timestamp = timestamp
        FileUtils.mkdir_p(directory)
        @filepath = File.join(directory, "#{@timestamp.strftime("%Y%m%d-%H%M%S")}_raw_outputs.log")
        @file = File.open(@filepath, "w")
        @file.sync = true # Flush immediately - never lose data
      end

      # Logs a model run with full context.
      #
      # @param model_id [String] Model identifier
      # @param config [String] Configuration/strategy name
      # @param data [Hash] Run data (task, output, steps, etc.)
      # @return [self]
      def log_run(model_id:, config:, data:)
        raise "Logger is closed" unless open?

        @entry_count += 1
        write_entry("MODEL: #{model_id} | CONFIG: #{config}", data.to_json)
        self
      end

      # Logs an error with context.
      #
      # @param model_id [String] Model identifier
      # @param error [Exception, String] The error
      # @param context [Hash] Additional context
      # @return [self]
      def log_error(model_id:, error:, context: {})
        raise "Logger is closed" unless open?

        @entry_count += 1
        error_data = {
          error_class: error.is_a?(Exception) ? error.class.name : "String",
          message: error.is_a?(Exception) ? error.message : error.to_s,
          backtrace: error.is_a?(Exception) ? error.backtrace&.first(10) : nil,
          context:
        }
        write_entry("ERROR: #{model_id}", error_data.to_json)
        self
      end

      # Logs raw model output for a single step.
      #
      # @param model_id [String] Model identifier
      # @param step_number [Integer] Step number
      # @param raw_output [String] Raw model response text
      # @param parsed_code [String, nil] Extracted code (if any)
      # @param parse_error [String, nil] Parse error (if any)
      # @return [self]
      def log_step(model_id:, step_number:, raw_output:, parsed_code: nil, parse_error: nil)
        raise "Logger is closed" unless open?

        @entry_count += 1
        step_data = { step: step_number, raw_output:, parsed_code:, parse_error:, timestamp: Time.now.iso8601 }
        write_entry("STEP: #{model_id} ##{step_number}", step_data.to_json)
        self
      end

      # Closes the log file.
      #
      # @return [void]
      def close
        @file&.close
        @file = nil
      end

      private

      def write_entry(label, content)
        @file.puts "=" * 80
        @file.puts "[#{Time.now.iso8601}] #{label}"
        @file.puts "-" * 80
        @file.puts content
        @file.puts
      end
    end
  end
end
