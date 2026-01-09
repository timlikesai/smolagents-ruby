# frozen_string_literal: true

RSpec.describe Smolagents::TokenUsage do
  describe "#total_tokens" do
    it "returns sum of input and output tokens" do
      usage = described_class.new(input_tokens: 100, output_tokens: 50)
      expect(usage.total_tokens).to eq(150)
    end
  end

  describe "#to_h" do
    it "returns hash with total_tokens included" do
      usage = described_class.new(input_tokens: 100, output_tokens: 50)
      expect(usage.to_h).to eq({
        input_tokens: 100,
        output_tokens: 50,
        total_tokens: 150
      })
    end
  end
end

RSpec.describe Smolagents::Timing do
  describe ".start_now" do
    it "creates timing with start_time set" do
      timing = described_class.start_now
      expect(timing.start_time).to be_a(Time)
      expect(timing.end_time).to be_nil
    end
  end

  describe "#stop" do
    it "returns new timing with end_time set" do
      timing = described_class.start_now
      sleep(0.01) # Small delay
      stopped = timing.stop
      expect(stopped.end_time).to be_a(Time)
      expect(stopped.end_time).to be > stopped.start_time
    end
  end

  describe "#duration" do
    it "returns nil when not stopped" do
      timing = described_class.start_now
      expect(timing.duration).to be_nil
    end

    it "returns duration in seconds when stopped" do
      timing = described_class.start_now
      sleep(0.01)
      stopped = timing.stop
      expect(stopped.duration).to be > 0
      expect(stopped.duration).to be_a(Float)
    end
  end
end

RSpec.describe Smolagents::ToolCall do
  describe "#to_h" do
    it "returns hash in API format" do
      tool_call = described_class.new(
        name: "web_search",
        arguments: { query: "test" },
        id: "call_123"
      )

      expect(tool_call.to_h).to eq({
        id: "call_123",
        type: "function",
        function: {
          name: "web_search",
          arguments: { query: "test" }
        }
      })
    end
  end
end

RSpec.describe Smolagents::RunResult do
  describe "#success?" do
    it "returns true when state is :success" do
      result = described_class.new(
        output: "done",
        state: :success,
        steps: [],
        token_usage: nil,
        timing: nil
      )
      expect(result.success?).to be true
    end

    it "returns false when state is not :success" do
      result = described_class.new(
        output: nil,
        state: :max_steps_error,
        steps: [],
        token_usage: nil,
        timing: nil
      )
      expect(result.success?).to be false
    end
  end
end
