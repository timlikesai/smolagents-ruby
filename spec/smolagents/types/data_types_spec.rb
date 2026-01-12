RSpec.describe Smolagents::TokenUsage do
  describe ".zero" do
    it "creates usage with zero tokens" do
      usage = described_class.zero
      expect(usage.input_tokens).to eq(0)
      expect(usage.output_tokens).to eq(0)
    end
  end

  describe "#+" do
    it "adds token counts" do
      a = described_class.new(input_tokens: 100, output_tokens: 50)
      b = described_class.new(input_tokens: 200, output_tokens: 75)

      result = a + b

      expect(result.input_tokens).to eq(300)
      expect(result.output_tokens).to eq(125)
    end

    it "works with zero" do
      usage = described_class.new(input_tokens: 100, output_tokens: 50)
      result = described_class.zero + usage

      expect(result).to eq(usage)
    end
  end

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
      stopped = timing.stop
      expect(stopped.end_time).to be_a(Time)
      expect(stopped.end_time).to be >= stopped.start_time
    end
  end

  describe "#duration" do
    it "returns nil when not stopped" do
      timing = described_class.start_now
      expect(timing.duration).to be_nil
    end

    it "returns duration in seconds when stopped" do
      timing = described_class.start_now
      stopped = timing.stop
      expect(stopped.duration).to be >= 0
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

RSpec.describe Smolagents::RunContext do
  describe ".start" do
    it "creates context at step 1 with zero tokens" do
      context = described_class.start

      expect(context.step_number).to eq(1)
      expect(context.total_tokens).to eq(Smolagents::TokenUsage.zero)
      expect(context.timing.start_time).to be_a(Time)
      expect(context.timing.end_time).to be_nil
    end
  end

  describe "#advance" do
    it "returns new context with incremented step number" do
      context = described_class.start
      advanced = context.advance

      expect(advanced.step_number).to eq(2)
      expect(context.step_number).to eq(1) # immutable
    end
  end

  describe "#add_tokens" do
    it "accumulates token usage" do
      context = described_class.start
      usage = Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50)

      updated = context.add_tokens(usage)

      expect(updated.total_tokens.input_tokens).to eq(100)
      expect(updated.total_tokens.output_tokens).to eq(50)
    end

    it "returns self when usage is nil" do
      context = described_class.start
      updated = context.add_tokens(nil)

      expect(updated).to eq(context)
    end
  end

  describe "#finish" do
    it "stops the timing" do
      context = described_class.start
      finished = context.finish

      expect(finished.timing.end_time).to be_a(Time)
      expect(finished.timing.duration).to be >= 0
    end
  end

  describe "#exceeded?" do
    it "returns false when step_number <= max_steps" do
      context = described_class.start
      expect(context.exceeded?(5)).to be false
    end

    it "returns true when step_number > max_steps" do
      context = described_class.start.advance.advance # step 3
      expect(context.exceeded?(2)).to be true
    end
  end

  describe "#steps_completed" do
    it "returns step_number - 1" do
      context = described_class.start.advance.advance # step 3
      expect(context.steps_completed).to eq(2)
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
