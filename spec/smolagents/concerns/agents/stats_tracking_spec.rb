require "spec_helper"

RSpec.describe Smolagents::Concerns::StatsTracking do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Consumer
      include Smolagents::Concerns::StatsTracking

      def initialize = initialize_stats
    end
  end

  let(:tracker) { test_class.new }

  describe "#stats" do
    it "starts with zero stats" do
      expect(tracker.stats).to eq(Smolagents::Types::AgentStats.zero)
    end

    it "returns an AgentStats instance" do
      expect(tracker.stats).to be_a(Smolagents::Types::AgentStats)
    end
  end

  describe "step tracking" do
    it "records steps from StepCompleted events" do
      event = Smolagents::Events::StepCompleted.create(
        step_number: 1, outcome: :success
      )
      tracker.consume(event)

      expect(tracker.stats.steps_taken).to eq(1)
    end

    it "accumulates multiple steps" do
      2.times do |i|
        event = Smolagents::Events::StepCompleted.create(
          step_number: i + 1, outcome: :success
        )
        tracker.consume(event)
      end

      expect(tracker.stats.steps_taken).to eq(2)
    end
  end

  describe "tool call tracking" do
    it "records tool calls from ToolCallCompleted events" do
      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "r1", tool_name: "search",
        result: "data", observation: "found"
      )
      tracker.consume(event)

      expect(tracker.stats.tool_calls).to eq(1)
    end
  end

  describe "model call tracking" do
    it "records model calls from completed ModelGeneration events" do
      event = Smolagents::Events::ModelGeneration.create(
        model_id: "test", phase: :completed,
        duration_ms: 350,
        token_usage: { input_tokens: 100, output_tokens: 50 }
      )
      tracker.consume(event)

      expect(tracker.stats.model_calls).to eq(1)
      expect(tracker.stats.total_tokens).to eq(150)
      expect(tracker.stats.prompt_tokens).to eq(100)
      expect(tracker.stats.completion_tokens).to eq(50)
      expect(tracker.stats.duration_ms).to eq(350)
    end

    it "ignores requested ModelGeneration events" do
      event = Smolagents::Events::ModelGeneration.create(
        model_id: "test", phase: :requested
      )
      tracker.consume(event)

      expect(tracker.stats.model_calls).to eq(0)
    end

    it "handles nil token_usage gracefully" do
      event = Smolagents::Events::ModelGeneration.create(
        model_id: "test", phase: :completed,
        duration_ms: 100, token_usage: nil
      )
      tracker.consume(event)

      expect(tracker.stats.model_calls).to eq(1)
      expect(tracker.stats.total_tokens).to eq(0)
    end
  end

  describe "error tracking" do
    it "records errors from ErrorOccurred events" do
      event = Smolagents::Events::ErrorOccurred.create(
        error: RuntimeError.new("fail"),
        context: {}, recoverable: true
      )
      tracker.consume(event)

      expect(tracker.stats.errors).to eq(1)
    end
  end

  describe "combined tracking" do
    it "accumulates stats across event types" do
      tracker.consume(
        Smolagents::Events::StepCompleted.create(
          step_number: 1, outcome: :success
        )
      )
      tracker.consume(
        Smolagents::Events::ToolCallCompleted.create(
          request_id: "r1", tool_name: "search",
          result: "ok", observation: "done"
        )
      )
      tracker.consume(
        Smolagents::Events::ModelGeneration.create(
          model_id: "m1", phase: :completed,
          duration_ms: 200,
          token_usage: { input_tokens: 80, output_tokens: 40 }
        )
      )
      tracker.consume(
        Smolagents::Events::ErrorOccurred.create(
          error: RuntimeError.new("oops"),
          context: {}, recoverable: false
        )
      )

      stats = tracker.stats
      expect(stats.steps_taken).to eq(1)
      expect(stats.tool_calls).to eq(1)
      expect(stats.model_calls).to eq(1)
      expect(stats.total_tokens).to eq(120)
      expect(stats.errors).to eq(1)
      expect(stats).not_to be_empty
    end
  end
end
