require "spec_helper"

RSpec.describe Smolagents::Telemetry::Instrumentation do
  after { described_class.subscriber = nil }

  describe ".subscriber" do
    it "is nil by default" do
      described_class.subscriber = nil

      expect(described_class.subscriber).to be_nil
    end

    it "can be set to a callable" do
      subscriber = ->(event, payload) { [event, payload] }
      described_class.subscriber = subscriber

      expect(described_class.subscriber).to eq(subscriber)
    end
  end

  describe ".observe" do
    let(:collected_events) { [] }
    let(:subscriber) { ->(event, payload) { collected_events << { event:, payload: } } }

    before { described_class.subscriber = subscriber }

    it "returns the outcome unchanged" do
      outcome = Smolagents::ExecutionOutcome.success("result")

      result = described_class.observe("test.event") { outcome }

      expect(result).to eq(outcome)
    end

    it "emits event with outcome data" do
      outcome = Smolagents::ExecutionOutcome.success("result", duration: 0.5)

      described_class.observe("smolagents.tool.call", tool_name: "search") { outcome }

      expect(collected_events.size).to eq(1)
      event_data = collected_events.first
      expect(event_data[:event]).to eq("smolagents.tool.call")
      expect(event_data[:payload][:tool_name]).to eq("search")
      expect(event_data[:payload][:outcome]).to eq(:success)
      expect(event_data[:payload][:duration]).to eq(0.5)
    end

    it "yields without emitting when no subscriber is set" do
      described_class.subscriber = nil
      outcome = Smolagents::ExecutionOutcome.success("result")

      result = described_class.observe("test.event") { outcome }

      expect(result).to eq(outcome)
      expect(collected_events).to be_empty
    end

    it "includes metadata from outcome" do
      outcome = Smolagents::ExecutionOutcome.success("result", metadata: { step: 1 })

      described_class.observe("test.event") { outcome }

      expect(collected_events.first[:payload][:metadata]).to eq({ step: 1 })
    end
  end

  describe ".instrument" do
    let(:collected_events) { [] }
    let(:subscriber) { ->(event, payload) { collected_events << { event:, payload: } } }

    before { described_class.subscriber = subscriber }

    it "returns the block result" do
      result = described_class.instrument("test.event") { "success" }

      expect(result).to eq("success")
    end

    it "emits success event on completion" do
      described_class.instrument("test.operation", task: "research") { "done" }

      expect(collected_events.size).to eq(1)
      event_data = collected_events.first
      expect(event_data[:event]).to eq("test.operation")
      expect(event_data[:payload][:task]).to eq("research")
      expect(event_data[:payload][:outcome]).to eq(:success)
      expect(event_data[:payload][:duration]).to be_a(Numeric)
    end

    it "emits error event and re-raises on exception" do
      expect do
        described_class.instrument("test.operation") { raise StandardError, "boom" }
      end.to raise_error(StandardError, "boom")

      expect(collected_events.size).to eq(1)
      event_data = collected_events.first
      expect(event_data[:payload][:outcome]).to eq(:error)
      expect(event_data[:payload][:error]).to eq("StandardError")
      expect(event_data[:payload][:error_message]).to eq("boom")
    end

    it "emits final_answer event for FinalAnswerException" do
      expect do
        described_class.instrument("test.operation") do
          raise Smolagents::FinalAnswerException, "The answer is 42"
        end
      end.to raise_error(Smolagents::FinalAnswerException)

      expect(collected_events.size).to eq(1)
      event_data = collected_events.first
      expect(event_data[:payload][:outcome]).to eq(:final_answer)
      expect(event_data[:payload][:value]).to eq("The answer is 42")
    end

    it "yields without emitting when no subscriber is set" do
      described_class.subscriber = nil

      result = described_class.instrument("test.event") { "result" }

      expect(result).to eq("result")
      expect(collected_events).to be_empty
    end

    it "includes timestamp in event payload" do
      described_class.instrument("test.event") { "done" }

      expect(collected_events.first[:payload][:timestamp]).to match(/\d{4}-\d{2}-\d{2}T/)
    end

    it "tracks duration accurately" do
      described_class.instrument("test.event") { nil }

      expect(collected_events.first[:payload][:duration]).to be_a(Float)
    end
  end

  describe ".emit_final_answer" do
    let(:collected_events) { [] }
    let(:subscriber) { ->(event, payload) { collected_events << { event:, payload: } } }

    before { described_class.subscriber = subscriber }

    it "emits event with final_answer outcome" do
      exception = Smolagents::FinalAnswerException.new("answer")
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      described_class.emit_final_answer("test.event", { task: "done" }, exception, start_time)

      event_data = collected_events.first
      expect(event_data[:payload][:outcome]).to eq(:final_answer)
      expect(event_data[:payload][:value]).to eq("answer")
      expect(event_data[:payload][:task]).to eq("done")
    end
  end

  describe ".emit_error" do
    let(:collected_events) { [] }
    let(:subscriber) { ->(event, payload) { collected_events << { event:, payload: } } }

    before { described_class.subscriber = subscriber }

    it "emits event with error outcome" do
      exception = RuntimeError.new("failed")
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      described_class.emit_error("test.event", { step: 1 }, exception, start_time)

      event_data = collected_events.first
      expect(event_data[:payload][:outcome]).to eq(:error)
      expect(event_data[:payload][:error]).to eq("RuntimeError")
      expect(event_data[:payload][:error_message]).to eq("failed")
      expect(event_data[:payload][:step]).to eq(1)
    end
  end
end
