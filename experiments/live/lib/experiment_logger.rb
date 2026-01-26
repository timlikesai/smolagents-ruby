# Experiment Logger
#
# JSONL logging with immediate flush for crash-safe data collection.

require "json"
require "fileutils"

module LiveExperiments
  class ExperimentLogger
    attr_reader :run_id, :run_dir

    def initialize(logs_dir, run_id)
      @run_id = run_id
      @run_dir = File.join(logs_dir, Time.now.strftime("%Y-%m-%d"), run_id)
      FileUtils.mkdir_p(@run_dir)

      @traces_file = File.open(File.join(@run_dir, "traces.jsonl"), "a")
      @events_file = File.open(File.join(@run_dir, "events.jsonl"), "a")
      @summary_file = File.join(@run_dir, "summary.json")

      @sequence = 0
      @trace_id = nil
      @mutex = Mutex.new
      @stats = { tasks: 0, passed: 0, failed: 0, errors: 0, total_tokens: 0 }
    end

    # Start a new trace context
    def with_trace(trace_id = SecureRandom.hex(16))
      previous = @trace_id
      @trace_id = trace_id
      yield
    ensure
      @trace_id = previous
    end

    # Log an LLM interaction trace
    def trace(data)
      write(@traces_file, data.merge(
        trace_id: @trace_id,
        span_id: SecureRandom.hex(8),
        sequence: next_sequence,
        timestamp: Time.now.iso8601
      ))
    end

    # Log a high-level event
    def event(type, data = {})
      write(@events_file, data.merge(
        type: type.to_s,
        trace_id: @trace_id,
        timestamp: Time.now.iso8601
      ))

      # Update stats
      case type
      when :task_complete
        @mutex.synchronize do
          @stats[:tasks] += 1
          @stats[:passed] += 1 if data[:passed]
          @stats[:failed] += 1 unless data[:passed]
        end
      when :error
        @mutex.synchronize { @stats[:errors] += 1 }
      when :llm_call
        @mutex.synchronize do
          @stats[:total_tokens] += (data[:input_tokens] || 0) + (data[:output_tokens] || 0)
        end
      end
    end

    # Log an error
    def error(err, context: {})
      event(:error, context.merge(
        error_class: err.class.name,
        message: err.message,
        backtrace: err.backtrace&.first(10)
      ))
    end

    # Log experiment start
    def experiment_started(experiment_name, config)
      event(:experiment_started, {
        experiment: experiment_name,
        config: config,
        infrastructure: LiveExperiments::Infrastructure::HealthChecker.new.check_all
      })
    end

    # Log experiment completion
    def experiment_completed(experiment_name, duration_seconds)
      event(:experiment_completed, {
        experiment: experiment_name,
        duration_seconds: duration_seconds.round(2),
        stats: stats
      })
      write_summary
    end

    # Get current stats
    def stats
      @mutex.synchronize { @stats.dup }
    end

    # Close file handles
    def close
      write_summary
      @traces_file.close
      @events_file.close
    end

    private

    def write(file, data)
      @mutex.synchronize do
        file.puts(JSON.generate(data))
        file.flush
      end
    end

    def next_sequence
      @mutex.synchronize { @sequence += 1 }
    end

    def write_summary
      File.write(@summary_file, JSON.pretty_generate({
        run_id: @run_id,
        completed_at: Time.now.iso8601,
        stats: stats,
        run_dir: @run_dir
      }))
    end
  end
end
