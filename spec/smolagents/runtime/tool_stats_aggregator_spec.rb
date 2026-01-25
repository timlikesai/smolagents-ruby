RSpec.describe Smolagents::Runtime::ToolStatsAggregator do
  describe "#initialize" do
    it "creates an empty aggregator" do
      aggregator = described_class.new

      expect(aggregator.tools).to be_empty
    end
  end

  describe "#record" do
    it "records a single tool execution" do
      aggregator = described_class.new
      aggregator.record("search", duration: 0.5, error: false)

      stats = aggregator["search"]
      expect(stats).not_to be_nil
      expect(stats.call_count).to eq(1)
    end

    it "accumulates multiple calls for same tool" do
      aggregator = described_class.new
      aggregator.record("search", duration: 0.5, error: false)
      aggregator.record("search", duration: 0.3, error: false)

      stats = aggregator["search"]
      expect(stats.call_count).to eq(2)
    end

    it "sums durations across calls" do
      aggregator = described_class.new
      aggregator.record("search", duration: 0.5, error: false)
      aggregator.record("search", duration: 0.3, error: false)

      stats = aggregator["search"]
      expect(stats.total_duration).to eq(0.8)
    end

    it "tracks errors separately" do
      aggregator = described_class.new
      aggregator.record("api", duration: 0.1, error: false)
      aggregator.record("api", duration: 0.2, error: true)

      stats = aggregator["api"]
      expect(stats.call_count).to eq(2)
      expect(stats.error_count).to eq(1)
    end

    it "defaults error to false" do
      aggregator = described_class.new
      aggregator.record("search", duration: 0.5)

      stats = aggregator["search"]
      expect(stats.error_count).to eq(0)
    end

    it "records different tools separately" do
      aggregator = described_class.new
      aggregator.record("search", duration: 0.5, error: false)
      aggregator.record("file", duration: 1.2, error: false)

      expect(aggregator["search"].call_count).to eq(1)
      expect(aggregator["file"].call_count).to eq(1)
    end

    it "returns the updated stats" do
      aggregator = described_class.new
      result = aggregator.record("search", duration: 0.5, error: false)

      expect(result).to be_a(Smolagents::Types::ToolStats)
      expect(result.call_count).to eq(1)
    end
  end

  describe "#[]" do
    it "returns stats for recorded tool" do
      aggregator = described_class.new
      aggregator.record("search", duration: 0.5, error: false)

      stats = aggregator["search"]
      expect(stats).not_to be_nil
      expect(stats.call_count).to eq(1)
    end

    it "returns nil for unrecorded tool" do
      aggregator = described_class.new

      stats = aggregator["unknown"]
      expect(stats).to be_nil
    end
  end

  describe "#tools" do
    it "returns empty array initially" do
      aggregator = described_class.new

      expect(aggregator.tools).to eq([])
    end

    it "returns recorded tool names" do
      aggregator = described_class.new
      aggregator.record("search", duration: 0.5, error: false)
      aggregator.record("file", duration: 1.0, error: false)

      expect(aggregator.tools).to contain_exactly("search", "file")
    end

    it "preserves insertion order" do
      aggregator = described_class.new
      aggregator.record("z", duration: 0.1, error: false)
      aggregator.record("a", duration: 0.1, error: false)
      aggregator.record("m", duration: 0.1, error: false)

      expect(aggregator.tools).to eq(%w[z a m])
    end

    it "does not duplicate tool names" do
      aggregator = described_class.new
      aggregator.record("search", duration: 0.5, error: false)
      aggregator.record("search", duration: 0.3, error: false)

      expect(aggregator.tools).to eq(["search"])
    end
  end

  describe "#to_a" do
    it "returns empty array initially" do
      aggregator = described_class.new

      expect(aggregator.to_a).to be_empty
    end

    it "returns all stats as array" do
      aggregator = described_class.new
      aggregator.record("search", duration: 0.5, error: false)
      aggregator.record("file", duration: 1.0, error: false)

      result = aggregator.to_a
      expect(result.length).to eq(2)
      expect(result).to all(be_a(Smolagents::Types::ToolStats))
    end

    it "preserves insertion order" do
      aggregator = described_class.new
      aggregator.record("search", duration: 0.5, error: false)
      aggregator.record("file", duration: 1.0, error: false)

      result = aggregator.to_a
      expect(result.map(&:name)).to eq(%w[search file])
    end
  end

  describe "#to_h" do
    it "returns empty hash initially" do
      aggregator = described_class.new

      expect(aggregator.to_h).to eq({})
    end

    it "converts stats to hash" do
      aggregator = described_class.new
      aggregator.record("search", duration: 0.5, error: false)

      result = aggregator.to_h
      expect(result).to have_key("search")
      expect(result["search"]).to be_a(Hash)
    end

    it "includes all tool stats" do
      aggregator = described_class.new
      aggregator.record("search", duration: 0.5, error: false)
      aggregator.record("file", duration: 1.0, error: false)

      result = aggregator.to_h
      expect(result.keys).to contain_exactly("search", "file")
    end
  end

  describe ".from_steps" do
    it "creates aggregator from empty steps" do
      aggregator = described_class.from_steps([])

      expect(aggregator.tools).to be_empty
    end

    it "extracts stats from action steps" do
      step = instance_double(
        Smolagents::Types::ActionStep,
        tool_calls: [
          double("ToolCall", name: "search"),
          double("ToolCall", name: "file")
        ],
        timing: double("Timing", duration: 1.0),
        error: nil
      )

      aggregator = described_class.from_steps([step])

      expect(aggregator.tools).to contain_exactly("search", "file")
    end

    it "distributes step duration across tools" do
      step = instance_double(
        Smolagents::Types::ActionStep,
        tool_calls: [
          double("ToolCall", name: "search"),
          double("ToolCall", name: "file")
        ],
        timing: double("Timing", duration: 2.0),
        error: nil
      )

      aggregator = described_class.from_steps([step])

      # Each tool should get 2.0 / 2 = 1.0
      expect(aggregator["search"].total_duration).to eq(1.0)
      expect(aggregator["file"].total_duration).to eq(1.0)
    end

    it "marks tools as errored if step has error" do
      step = instance_double(
        Smolagents::Types::ActionStep,
        tool_calls: [double("ToolCall", name: "search")],
        timing: double("Timing", duration: 1.0),
        error: StandardError.new("Test error")
      )

      aggregator = described_class.from_steps([step])

      expect(aggregator["search"].error_count).to eq(1)
    end

    it "ignores steps without tool_calls" do
      step = instance_double(
        Smolagents::Types::ActionStep,
        respond_to?: false
      )
      allow(step).to receive(:respond_to?).with(:tool_calls).and_return(false)

      aggregator = described_class.from_steps([step])

      expect(aggregator.tools).to be_empty
    end

    it "ignores steps with nil tool_calls" do
      step = instance_double(
        Smolagents::Types::ActionStep,
        tool_calls: nil,
        respond_to?: true
      )
      allow(step).to receive(:respond_to?).with(:tool_calls).and_return(true)

      aggregator = described_class.from_steps([step])

      expect(aggregator.tools).to be_empty
    end

    it "processes multiple steps" do
      step1 = instance_double(
        Smolagents::Types::ActionStep,
        tool_calls: [double("ToolCall", name: "search")],
        timing: double("Timing", duration: 0.5),
        error: nil
      )
      step2 = instance_double(
        Smolagents::Types::ActionStep,
        tool_calls: [double("ToolCall", name: "search")],
        timing: double("Timing", duration: 0.3),
        error: nil
      )

      aggregator = described_class.from_steps([step1, step2])

      expect(aggregator["search"].call_count).to eq(2)
      expect(aggregator["search"].total_duration).to eq(0.8)
    end

    it "handles single tool call in step" do
      step = instance_double(
        Smolagents::Types::ActionStep,
        tool_calls: [double("ToolCall", name: "search")],
        timing: double("Timing", duration: 1.0),
        error: nil
      )

      aggregator = described_class.from_steps([step])

      expect(aggregator["search"].total_duration).to eq(1.0)
    end

    it "handles step with nil timing" do
      step = instance_double(
        Smolagents::Types::ActionStep,
        tool_calls: [double("ToolCall", name: "search")],
        timing: nil,
        error: nil
      )

      aggregator = described_class.from_steps([step])

      expect(aggregator["search"].total_duration).to eq(0.0)
    end
  end

  describe "integration" do
    it "allows building complex statistics" do
      aggregator = described_class.new

      # Simulate multiple tool calls with different outcomes
      aggregator.record("search", duration: 0.5, error: false)
      aggregator.record("search", duration: 0.3, error: false)
      aggregator.record("search", duration: 0.2, error: true)
      aggregator.record("file", duration: 1.0, error: false)
      aggregator.record("file", duration: 0.8, error: true)

      expect(aggregator.tools).to contain_exactly("search", "file")
      expect(aggregator["search"].call_count).to eq(3)
      expect(aggregator["search"].error_count).to eq(1)
      expect(aggregator["file"].call_count).to eq(2)
      expect(aggregator["file"].error_count).to eq(1)
    end

    it "can serialize and inspect stats" do
      aggregator = described_class.new
      aggregator.record("search", duration: 0.5, error: false)

      hash = aggregator.to_h
      expect(hash["search"]).to include(:name, :call_count)
    end
  end
end
