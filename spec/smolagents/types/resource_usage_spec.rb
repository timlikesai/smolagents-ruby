require "smolagents"

RSpec.describe Smolagents::Types::ResourceUsage do
  let(:instance) do
    described_class.new(
      total_tokens: 150, prompt_tokens: 100, completion_tokens: 50,
      total_duration_ms: 400, model_duration_ms: 350, tool_duration_ms: 50,
      api_calls: 3, tool_calls: 2
    )
  end
  let(:instance_a) do
    described_class.new(
      total_tokens: 200, prompt_tokens: 120, completion_tokens: 80,
      total_duration_ms: 500, model_duration_ms: 400, tool_duration_ms: 100,
      api_calls: 4, tool_calls: 3
    )
  end
  let(:instance_b) do
    described_class.new(
      total_tokens: 100, prompt_tokens: 60, completion_tokens: 40,
      total_duration_ms: 300, model_duration_ms: 250, tool_duration_ms: 50,
      api_calls: 2, tool_calls: 1
    )
  end

  it_behaves_like "a data type"
  it_behaves_like "a type with to_h",
                  expected_keys: %i[total_tokens prompt_tokens completion_tokens
                                    total_duration_ms model_duration_ms tool_duration_ms
                                    api_calls tool_calls
                                    model_time_percent tool_time_percent]

  describe ".zero" do
    it "creates usage with all counters at zero" do
      usage = described_class.zero

      expect(usage.total_tokens).to eq(0)
      expect(usage.prompt_tokens).to eq(0)
      expect(usage.completion_tokens).to eq(0)
      expect(usage.total_duration_ms).to eq(0)
      expect(usage.model_duration_ms).to eq(0)
      expect(usage.tool_duration_ms).to eq(0)
      expect(usage.api_calls).to eq(0)
      expect(usage.tool_calls).to eq(0)
    end

    it "is frozen" do
      expect(described_class.zero).to be_frozen
    end
  end

  describe "#add_model_call" do
    it "accumulates tokens and duration" do
      usage = described_class.zero
      updated = usage.add_model_call(prompt_tokens: 100, completion_tokens: 50, duration_ms: 350)

      expect(updated.total_tokens).to eq(150)
      expect(updated.prompt_tokens).to eq(100)
      expect(updated.completion_tokens).to eq(50)
      expect(updated.total_duration_ms).to eq(350)
      expect(updated.model_duration_ms).to eq(350)
      expect(updated.api_calls).to eq(1)
    end

    it "increments api_calls" do
      usage = described_class.zero
                             .add_model_call(prompt_tokens: 10, completion_tokens: 5, duration_ms: 100)
                             .add_model_call(prompt_tokens: 20, completion_tokens: 10, duration_ms: 200)

      expect(usage.api_calls).to eq(2)
    end

    it "does not affect tool counters" do
      usage = described_class.zero.add_model_call(prompt_tokens: 50, completion_tokens: 25, duration_ms: 100)

      expect(usage.tool_duration_ms).to eq(0)
      expect(usage.tool_calls).to eq(0)
    end

    it "returns new instance (immutable)" do
      original = described_class.zero
      updated = original.add_model_call(prompt_tokens: 100, completion_tokens: 50, duration_ms: 350)

      expect(original.total_tokens).to eq(0)
      expect(original.api_calls).to eq(0)
      expect(updated).not_to equal(original)
    end
  end

  describe "#add_tool_call" do
    it "accumulates tool duration" do
      usage = described_class.zero
      updated = usage.add_tool_call(duration_ms: 20)

      expect(updated.tool_duration_ms).to eq(20)
      expect(updated.total_duration_ms).to eq(20)
      expect(updated.tool_calls).to eq(1)
    end

    it "increments tool_calls" do
      usage = described_class.zero
                             .add_tool_call(duration_ms: 10)
                             .add_tool_call(duration_ms: 15)

      expect(usage.tool_calls).to eq(2)
      expect(usage.tool_duration_ms).to eq(25)
    end

    it "does not affect model counters" do
      usage = described_class.zero.add_tool_call(duration_ms: 50)

      expect(usage.total_tokens).to eq(0)
      expect(usage.prompt_tokens).to eq(0)
      expect(usage.completion_tokens).to eq(0)
      expect(usage.model_duration_ms).to eq(0)
      expect(usage.api_calls).to eq(0)
    end

    it "returns new instance (immutable)" do
      original = described_class.zero
      updated = original.add_tool_call(duration_ms: 20)

      expect(original.tool_calls).to eq(0)
      expect(original.tool_duration_ms).to eq(0)
      expect(updated).not_to equal(original)
    end
  end

  describe "chaining multiple calls" do
    it "accumulates across model and tool calls" do
      usage = described_class.zero
                             .add_model_call(prompt_tokens: 100, completion_tokens: 50, duration_ms: 300)
                             .add_tool_call(duration_ms: 20)
                             .add_model_call(prompt_tokens: 80, completion_tokens: 40, duration_ms: 250)
                             .add_tool_call(duration_ms: 30)

      expect(usage.total_tokens).to eq(270)
      expect(usage.prompt_tokens).to eq(180)
      expect(usage.completion_tokens).to eq(90)
      expect(usage.total_duration_ms).to eq(600)
      expect(usage.model_duration_ms).to eq(550)
      expect(usage.tool_duration_ms).to eq(50)
      expect(usage.api_calls).to eq(2)
      expect(usage.tool_calls).to eq(2)
    end
  end

  describe "#model_time_percent" do
    it "calculates percentage of time in model calls" do
      usage = described_class.new(
        total_tokens: 0, prompt_tokens: 0, completion_tokens: 0,
        total_duration_ms: 1000, model_duration_ms: 750, tool_duration_ms: 250,
        api_calls: 1, tool_calls: 1
      )

      expect(usage.model_time_percent).to eq(75.0)
    end

    it "returns 0.0 when total duration is zero" do
      usage = described_class.zero
      expect(usage.model_time_percent).to eq(0.0)
    end

    it "rounds to one decimal place" do
      usage = described_class.new(
        total_tokens: 0, prompt_tokens: 0, completion_tokens: 0,
        total_duration_ms: 300, model_duration_ms: 200, tool_duration_ms: 100,
        api_calls: 1, tool_calls: 1
      )

      expect(usage.model_time_percent).to eq(66.7)
    end
  end

  describe "#tool_time_percent" do
    it "calculates percentage of time in tool calls" do
      usage = described_class.new(
        total_tokens: 0, prompt_tokens: 0, completion_tokens: 0,
        total_duration_ms: 1000, model_duration_ms: 750, tool_duration_ms: 250,
        api_calls: 1, tool_calls: 1
      )

      expect(usage.tool_time_percent).to eq(25.0)
    end

    it "returns 0.0 when total duration is zero" do
      usage = described_class.zero
      expect(usage.tool_time_percent).to eq(0.0)
    end
  end

  describe "#empty?" do
    it "returns true when no calls have been made" do
      usage = described_class.zero
      expect(usage.empty?).to be true
    end

    it "returns false when api calls have been made" do
      usage = described_class.zero.add_model_call(prompt_tokens: 10, completion_tokens: 5, duration_ms: 100)
      expect(usage.empty?).to be false
    end

    it "returns false when tool calls have been made" do
      usage = described_class.zero.add_tool_call(duration_ms: 10)
      expect(usage.empty?).to be false
    end
  end

  describe "#summary" do
    it "returns human-readable string" do
      usage = described_class.new(
        total_tokens: 150, prompt_tokens: 100, completion_tokens: 50,
        total_duration_ms: 400, model_duration_ms: 350, tool_duration_ms: 50,
        api_calls: 3, tool_calls: 2
      )

      expect(usage.summary).to eq("150 tokens (3 API calls, 2 tool calls) in 400ms")
    end

    it "works for zero usage" do
      expect(described_class.zero.summary).to eq("0 tokens (0 API calls, 0 tool calls) in 0ms")
    end
  end

  describe "#to_h" do
    it "includes all fields and derived metrics" do
      hash = instance.to_h

      expect(hash[:total_tokens]).to eq(150)
      expect(hash[:prompt_tokens]).to eq(100)
      expect(hash[:completion_tokens]).to eq(50)
      expect(hash[:total_duration_ms]).to eq(400)
      expect(hash[:model_duration_ms]).to eq(350)
      expect(hash[:tool_duration_ms]).to eq(50)
      expect(hash[:api_calls]).to eq(3)
      expect(hash[:tool_calls]).to eq(2)
      expect(hash[:model_time_percent]).to eq(87.5)
      expect(hash[:tool_time_percent]).to eq(12.5)
    end
  end

  describe "pattern matching" do
    it "supports deconstruct_keys" do
      usage = described_class.new(
        total_tokens: 150, prompt_tokens: 100, completion_tokens: 50,
        total_duration_ms: 400, model_duration_ms: 350, tool_duration_ms: 50,
        api_calls: 3, tool_calls: 2
      )

      case usage
      in { total_tokens:, api_calls: }
        expect(total_tokens).to eq(150)
        expect(api_calls).to eq(3)
      else
        raise "Pattern should match"
      end
    end
  end
end
