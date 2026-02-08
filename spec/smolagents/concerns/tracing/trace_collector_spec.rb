require "spec_helper"

RSpec.describe Smolagents::Concerns::TraceCollector do
  let(:collector) { described_class::Collector.new }

  describe "Collector" do
    describe "#record" do
      it "creates a trace record" do
        trace = collector.record(
          task: "Find Ruby info",
          available_tools: %w[search calculate],
          dispatcher_model: "functiongemma",
          prediction: { tool_name: "search", arguments: { query: "Ruby" }, confidence: 0.85 },
          latency_ms: 50.5
        )

        expect(trace.id).to start_with("trace_")
        expect(trace.task).to eq("Find Ruby info")
        expect(trace.prediction[:tool_name]).to eq("search")
        expect(trace.latency_ms).to eq(50.5)
      end

      it "adds trace to collection" do
        collector.record(task: "t1", available_tools: [], dispatcher_model: "m", prediction: {})
        collector.record(task: "t2", available_tools: [], dispatcher_model: "m", prediction: {})

        expect(collector.traces.size).to eq(2)
      end
    end

    describe "#update_outcome" do
      it "updates existing trace with outcome" do
        trace = collector.record(
          task: "test",
          available_tools: [],
          dispatcher_model: "m",
          prediction: { tool_name: "search", confidence: 0.8 }
        )

        collector.update_outcome(trace.id, execution_outcome: { success: true })

        updated = collector.traces.find { |t| t.id == trace.id }
        expect(updated.execution_outcome[:success]).to be true
        expect(updated.success?).to be true
      end
    end

    describe "#export" do
      before do
        collector.record(
          task: "test task",
          available_tools: %w[search],
          dispatcher_model: "test-model",
          prediction: { tool_name: "search", arguments: { q: "x" }, confidence: 0.9 }
        )
      end

      it "exports as JSONL" do
        output = collector.export(format: :jsonl)
        expect(output).to be_a(String)
        expect { JSON.parse(output) }.not_to raise_error
      end

      it "exports as JSON" do
        output = collector.export(format: :json)
        parsed = JSON.parse(output)
        expect(parsed).to be_an(Array)
        expect(parsed.first["input"]["query"]).to eq("test task")
      end
    end

    describe "#stats" do
      it "returns empty stats for no traces" do
        stats = collector.stats

        expect(stats[:total]).to eq(0)
        expect(stats[:successful]).to eq(0)
        expect(stats[:avg_latency_ms]).to eq(0)
      end

      it "calculates stats correctly" do
        collector.record(task: "t1", available_tools: [], dispatcher_model: "m",
                         prediction: {}, latency_ms: 100)
        collector.record(task: "t2", available_tools: [], dispatcher_model: "m",
                         prediction: {}, latency_ms: 200)

        stats = collector.stats
        expect(stats[:total]).to eq(2)
        expect(stats[:avg_latency_ms]).to eq(150.0)
      end
    end
  end

  describe "TraceRecord" do
    let(:trace) do
      described_class::TraceRecord.new(
        id: "trace_1",
        timestamp: Time.now,
        task: "Find info",
        available_tools: %w[search],
        dispatcher_model: "test",
        prediction: { tool_name: "search", arguments: { query: "test" }, confidence: 0.85 },
        validation_result: { validated: true },
        execution_outcome: { success: true },
        latency_ms: 50
      )
    end

    it "provides success predicate" do
      expect(trace.success?).to be true
    end

    it "provides validated predicate" do
      expect(trace.validated?).to be true
    end

    it "converts to training example" do
      example = trace.to_training_example

      expect(example[:input][:tools]).to eq(%w[search])
      expect(example[:input][:query]).to eq("Find info")
      expect(example[:output][:tool_name]).to eq("search")
      expect(example[:metadata][:confidence]).to eq(0.85)
      expect(example[:metadata][:success]).to be true
    end
  end

  describe "module-level API" do
    before { described_class.configure }

    it "provides default collector" do
      expect(described_class.default_collector).to be_a(described_class::Collector)
    end

    it "records traces via module method" do
      described_class.record(
        task: "test",
        available_tools: [],
        dispatcher_model: "m",
        prediction: {}
      )

      expect(described_class.stats[:total]).to be >= 1
    end
  end
end
