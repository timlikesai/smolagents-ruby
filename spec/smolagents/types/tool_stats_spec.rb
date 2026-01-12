require "smolagents"

RSpec.describe Smolagents::ToolStats do
  describe "#avg_duration" do
    it "calculates average duration" do
      stats = described_class.new(name: "search", call_count: 4, error_count: 1, total_duration: 2.0)
      expect(stats.avg_duration).to eq(0.5)
    end

    it "returns 0 for zero calls" do
      stats = described_class.new(name: "search", call_count: 0, error_count: 0, total_duration: 0.0)
      expect(stats.avg_duration).to eq(0.0)
    end
  end

  describe "#error_rate" do
    it "calculates error rate" do
      stats = described_class.new(name: "search", call_count: 10, error_count: 2, total_duration: 1.0)
      expect(stats.error_rate).to eq(0.2)
    end

    it "returns 0 for zero calls" do
      stats = described_class.new(name: "search", call_count: 0, error_count: 0, total_duration: 0.0)
      expect(stats.error_rate).to eq(0.0)
    end
  end

  describe "#success_count" do
    it "calculates successful calls" do
      stats = described_class.new(name: "search", call_count: 10, error_count: 3, total_duration: 1.0)
      expect(stats.success_count).to eq(7)
    end
  end

  describe "#success_rate" do
    it "calculates success rate" do
      stats = described_class.new(name: "search", call_count: 10, error_count: 2, total_duration: 1.0)
      expect(stats.success_rate).to eq(0.8)
    end
  end

  describe ".empty" do
    it "creates empty stats for a tool" do
      stats = described_class.empty("my_tool")
      expect(stats.name).to eq("my_tool")
      expect(stats.call_count).to eq(0)
      expect(stats.error_count).to eq(0)
      expect(stats.total_duration).to eq(0.0)
    end
  end

  describe "#merge" do
    it "combines stats for the same tool" do
      stats1 = described_class.new(name: "search", call_count: 5, error_count: 1, total_duration: 1.0)
      stats2 = described_class.new(name: "search", call_count: 3, error_count: 2, total_duration: 0.5)

      merged = stats1.merge(stats2)

      expect(merged.name).to eq("search")
      expect(merged.call_count).to eq(8)
      expect(merged.error_count).to eq(3)
      expect(merged.total_duration).to eq(1.5)
    end

    it "raises error for different tool names" do
      stats1 = described_class.new(name: "search", call_count: 5, error_count: 1, total_duration: 1.0)
      stats2 = described_class.new(name: "visit", call_count: 3, error_count: 2, total_duration: 0.5)

      expect { stats1.merge(stats2) }.to raise_error(ArgumentError, /different tools/)
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      stats = described_class.new(name: "search", call_count: 10, error_count: 2, total_duration: 2.0)
      hash = stats.to_h

      expect(hash[:name]).to eq("search")
      expect(hash[:call_count]).to eq(10)
      expect(hash[:error_count]).to eq(2)
      expect(hash[:success_count]).to eq(8)
      expect(hash[:total_duration]).to eq(2.0)
      expect(hash[:avg_duration]).to eq(0.2)
      expect(hash[:error_rate]).to eq(0.2)
      expect(hash[:success_rate]).to eq(0.8)
    end
  end
end

RSpec.describe Smolagents::ToolStatsAggregator do
  describe "#record" do
    it "records tool calls" do
      aggregator = described_class.new
      aggregator.record("search", duration: 0.5, error: false)
      aggregator.record("search", duration: 0.3, error: false)
      aggregator.record("search", duration: 0.2, error: true)

      stats = aggregator["search"]
      expect(stats.call_count).to eq(3)
      expect(stats.error_count).to eq(1)
      expect(stats.total_duration).to eq(1.0)
    end
  end

  describe "#tools" do
    it "returns list of recorded tools" do
      aggregator = described_class.new
      aggregator.record("search", duration: 0.1)
      aggregator.record("visit", duration: 0.2)

      expect(aggregator.tools).to contain_exactly("search", "visit")
    end
  end

  describe "#to_a" do
    it "returns array of ToolStats" do
      aggregator = described_class.new
      aggregator.record("search", duration: 0.5)
      aggregator.record("visit", duration: 0.3)

      stats = aggregator.to_a
      expect(stats.size).to eq(2)
      expect(stats).to all(be_a(Smolagents::ToolStats))
    end
  end

  describe ".from_steps" do
    it "aggregates stats from action steps" do
      timing = Smolagents::Timing.new(start_time: Time.now - 1, end_time: Time.now)
      tool_call1 = Smolagents::ToolCall.new(name: "search", arguments: {}, id: "1")
      tool_call2 = Smolagents::ToolCall.new(name: "visit", arguments: {}, id: "2")

      steps = [
        Smolagents::ActionStep.new(step_number: 1, timing: timing, tool_calls: [tool_call1]),
        Smolagents::ActionStep.new(step_number: 2, timing: timing, tool_calls: [tool_call1, tool_call2]),
        Smolagents::ActionStep.new(step_number: 3, timing: timing, tool_calls: [tool_call2], error: "oops")
      ]

      aggregator = described_class.from_steps(steps)

      expect(aggregator.tools).to contain_exactly("search", "visit")
      expect(aggregator["search"].call_count).to eq(2)
      expect(aggregator["visit"].call_count).to eq(2)
      expect(aggregator["visit"].error_count).to eq(1)
    end

    it "handles steps without tool calls" do
      steps = [
        Smolagents::ActionStep.new(step_number: 1, tool_calls: nil),
        Smolagents::ActionStep.new(step_number: 2, tool_calls: [])
      ]

      aggregator = described_class.from_steps(steps)
      expect(aggregator.tools).to be_empty
    end
  end
end
