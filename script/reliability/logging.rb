require "fileutils"
require "json"

module Reliability
  # Verbose logger that captures all prompts and responses to timestamped files
  class Logger
    attr_reader :log_dir, :session_id

    def initialize(log_dir: "logs/reliability", model_id: nil)
      @log_dir = log_dir
      @session_id = Time.now.strftime("%Y%m%d-%H%M%S")
      @model_suffix = model_id ? "_#{sanitize(model_id)}" : ""
      FileUtils.mkdir_p(log_dir)
      @log_file = File.open(log_path, "w")
      @log_file.sync = true # Flush immediately for reliability
    end

    def log_path = File.join(@log_dir, "#{@session_id}#{@model_suffix}.log")

    def section(title)
      write("\n#{"=" * 80}")
      write("[#{timestamp}] #{title}")
      write("=" * 80)
    end

    def subsection(title)
      write("\n#{"-" * 60}")
      write("[#{timestamp}] #{title}")
      write("-" * 60)
    end

    def info(msg) = write("[#{timestamp}] #{msg}")
    def success(msg) = write("[#{timestamp}] ✓ #{msg}")
    def failure(msg) = write("[#{timestamp}] ✗ #{msg}")
    def error(msg) = write("[#{timestamp}] ERROR: #{msg}")

    def prompt(messages)
      subsection("PROMPT SENT TO MODEL")
      messages.each_with_index do |msg, i|
        role = msg.respond_to?(:role) ? msg.role : msg[:role]
        content = msg.respond_to?(:content) ? msg.content : msg[:content]
        write("--- Message #{i + 1} (#{role}) ---")
        content_str = content.is_a?(String) ? content : JSON.pretty_generate(content)
        write(content_str)
      end
      write("--- END PROMPT ---")
    end

    def raw_response(response, raw_text: nil)
      subsection("RAW MODEL RESPONSE")
      write(extract_response_text(response, raw_text))
      write("--- END RESPONSE ---")
    end

    def extract_response_text(response, raw_text)
      return raw_text if raw_text
      return JSON.pretty_generate(response.raw) if response.respond_to?(:raw)
      return "Content: #{response.content}" if response.respond_to?(:content)

      response.to_s
    end

    def test_start(name, task)
      section("TEST: #{name}")
      write("Task: #{task}")
    end

    def test_result(name, passed, details = {})
      status = passed ? "PASS" : "FAIL"
      subsection("TEST RESULT: #{name} - #{status}")
      details.each { |k, v| write("  #{k}: #{v}") }
    end

    def tool_call(name, args, result)
      write("[#{timestamp}] TOOL CALL: #{name}")
      write("  Args: #{args.inspect}")
      write("  Result: #{result.inspect[0..500]}")
    end

    def close
      info("Log closed at #{Time.now}")
      @log_file&.close
      puts "\nLog saved to: #{log_path}"
    end

    private

    def timestamp = Time.now.strftime("%H:%M:%S.%L")

    def write(msg)
      @log_file.puts(msg)
      # Don't echo to console - too verbose during test runs
    end

    def sanitize(str) = str.gsub(/[^a-zA-Z0-9._-]/, "_")[0..30]
  end

  # Wraps a model to intercept all generate calls for logging
  class LoggingModelWrapper
    attr_reader :wrapped_model, :logger

    def initialize(model, logger)
      @wrapped_model = model
      @logger = logger
    end

    def model_id = @wrapped_model.model_id

    def generate(messages, **)
      @logger.prompt(messages)

      response = @wrapped_model.generate(messages, **)

      # Try to capture raw response text
      raw_text = extract_raw_text(response)
      @logger.raw_response(response, raw_text:)

      response
    end

    def method_missing(method, ...) = @wrapped_model.send(method, ...)
    def respond_to_missing?(method, include_private = false) = @wrapped_model.respond_to?(method, include_private)

    private

    def extract_raw_text(response)
      return response.raw.to_json if response.respond_to?(:raw)
      return response.content if response.respond_to?(:content)

      nil
    end
  end
end
