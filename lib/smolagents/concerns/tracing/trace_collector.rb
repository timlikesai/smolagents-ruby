# frozen_string_literal: true

module Smolagents
  module Concerns
    # Collects traces of tool routing decisions for training data.
    #
    # Records the input (task, tools, context), the dispatcher's prediction,
    # and the actual outcome. This data can be used to fine-tune the dispatcher
    # model for better accuracy on domain-specific tools.
    #
    # @example Collecting a trace
    #   collector = TraceCollector.new(output_dir: "traces/")
    #   collector.record(
    #     input: { task: "Search for Ruby", tools: [...] },
    #     prediction: { tool: "search", confidence: 0.85 },
    #     outcome: { executed: true, success: true }
    #   )
    #
    module TraceCollector
      # Single trace record for training.
      TraceRecord = Data.define(
        :id,
        :timestamp,
        :task,
        :available_tools,
        :dispatcher_model,
        :prediction,
        :validation_result,
        :execution_outcome,
        :latency_ms
      ) do
        def success? = execution_outcome&.dig(:success)
        def validated? = validation_result&.dig(:validated)

        def to_training_example
          {
            input: {
              tools: available_tools,
              query: task
            },
            output: {
              tool_name: prediction&.dig(:tool_name),
              arguments: prediction&.dig(:arguments)
            },
            metadata: {
              confidence: prediction&.dig(:confidence),
              success: success?,
              validated: validated?
            }
          }
        end
      end

      # Collects and stores trace records.
      class Collector
        attr_reader :traces, :output_dir

        def initialize(output_dir: nil, max_traces: 10_000)
          @traces = []
          @output_dir = output_dir
          @max_traces = max_traces
          @mutex = Mutex.new
        end

        # Records a new trace.
        #
        # @param task [String] The user's task/query
        # @param available_tools [Array<Hash>] Tool definitions
        # @param dispatcher_model [String] Model used for dispatch
        # @param prediction [Hash] Dispatcher's prediction
        # @param validation_result [Hash, nil] Validation outcome
        # @param execution_outcome [Hash, nil] Final execution result
        # @param latency_ms [Float] Dispatch latency
        # @return [TraceRecord] The recorded trace
        def record(task:, available_tools:, dispatcher_model:, prediction:,
                   validation_result: nil, execution_outcome: nil, latency_ms: 0)
          trace = TraceRecord.new(
            id: generate_id,
            timestamp: Time.now.utc,
            task:,
            available_tools:,
            dispatcher_model:,
            prediction:,
            validation_result:,
            execution_outcome:,
            latency_ms:
          )

          @mutex.synchronize do
            @traces << trace
            flush_if_needed
          end

          trace
        end

        # Updates an existing trace with execution outcome.
        #
        # @param trace_id [String] ID of trace to update
        # @param execution_outcome [Hash] Outcome to record
        def update_outcome(trace_id, execution_outcome:)
          @mutex.synchronize do
            idx = @traces.find_index { |t| t.id == trace_id }
            return unless idx

            @traces[idx] = @traces[idx].with(execution_outcome:)
          end
        end

        # Exports traces for training.
        #
        # @param format [Symbol] :jsonl or :json
        # @return [String] Serialized traces
        def export(format: :jsonl)
          examples = @traces.map(&:to_training_example)

          case format
          when :jsonl
            examples.map { |e| JSON.generate(e) }.join("\n")
          when :json
            JSON.pretty_generate(examples)
          else
            raise ArgumentError, "Unknown format: #{format}"
          end
        end

        # Writes traces to output directory.
        def flush
          return unless @output_dir

          FileUtils.mkdir_p(@output_dir)
          filename = File.join(@output_dir, "traces_#{Time.now.strftime('%Y%m%d_%H%M%S')}.jsonl")
          File.write(filename, export(format: :jsonl))
          @traces.clear
        end

        # Returns statistics about collected traces.
        def stats
          {
            total: @traces.size,
            successful: @traces.count(&:success?),
            validated: @traces.count(&:validated?),
            avg_latency_ms: @traces.empty? ? 0 : @traces.sum(&:latency_ms) / @traces.size.to_f
          }
        end

        private

        def generate_id = "trace_#{SecureRandom.hex(8)}"

        def flush_if_needed
          flush if @traces.size >= @max_traces && @output_dir
        end
      end

      # Module-level collector instance.
      @default_collector = nil

      class << self
        def default_collector
          @default_collector ||= Collector.new
        end

        def configure(output_dir: nil, max_traces: 10_000)
          @default_collector = Collector.new(output_dir:, max_traces:)
        end

        def record(**kwargs) = default_collector.record(**kwargs)
        def export(**kwargs) = default_collector.export(**kwargs)
        def stats = default_collector.stats
        def flush = default_collector.flush
      end
    end
  end
end
