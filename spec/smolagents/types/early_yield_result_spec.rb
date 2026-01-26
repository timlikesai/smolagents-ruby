RSpec.describe Smolagents::Types::EarlyYieldResult do
  describe "attributes" do
    it "has results, early_result, pending_count, and collector" do
      collector = -> { ["remaining"] }
      result = described_class.new(
        results: ["first"],
        early_result: "first",
        pending_count: 2,
        collector: collector
      )

      expect(result.results).to eq(["first"])
      expect(result.early_result).to eq("first")
      expect(result.pending_count).to eq(2)
      expect(result.collector).to eq(collector)
    end
  end

  describe "#early?" do
    it "returns true when pending_count > 0" do
      result = described_class.new(
        results: ["first"],
        early_result: "first",
        pending_count: 2,
        collector: nil
      )

      expect(result.early?).to be true
    end

    it "returns false when pending_count == 0" do
      result = described_class.new(
        results: ["all", "done"],
        early_result: nil,
        pending_count: 0,
        collector: nil
      )

      expect(result.early?).to be false
    end
  end

  describe "#complete?" do
    it "returns true when pending_count == 0" do
      result = described_class.new(
        results: ["all", "done"],
        early_result: nil,
        pending_count: 0,
        collector: nil
      )

      expect(result.complete?).to be true
    end

    it "returns false when pending_count > 0" do
      result = described_class.new(
        results: ["first"],
        early_result: "first",
        pending_count: 1,
        collector: nil
      )

      expect(result.complete?).to be false
    end
  end

  describe "#collect_remaining" do
    it "returns results immediately when complete" do
      result = described_class.new(
        results: ["all", "done"],
        early_result: nil,
        pending_count: 0,
        collector: -> { raise "should not be called" }
      )

      expect(result.collect_remaining).to eq(["all", "done"])
    end

    it "calls collector when early" do
      collector_called = false
      collector = -> {
        collector_called = true
        ["first", "second", "third"]
      }

      result = described_class.new(
        results: ["first"],
        early_result: "first",
        pending_count: 2,
        collector: collector
      )

      collected = result.collect_remaining

      expect(collector_called).to be true
      expect(collected).to eq(["first", "second", "third"])
    end

    it "returns results when collector is nil" do
      result = described_class.new(
        results: ["first"],
        early_result: "first",
        pending_count: 1,
        collector: nil
      )

      expect(result.collect_remaining).to eq(["first"])
    end
  end

  describe "pattern matching" do
    it "matches on pending_count" do
      result = described_class.new(
        results: ["x"],
        early_result: "x",
        pending_count: 3,
        collector: nil
      )

      matched = case result
                in pending_count: 3
                  "3 pending"
                else
                  "other"
                end

      expect(matched).to eq("3 pending")
    end

    it "matches on early_result" do
      result = described_class.new(
        results: ["fast"],
        early_result: "fast",
        pending_count: 2,
        collector: nil
      )

      matched = case result
                in early_result: "fast"
                  "got fast result"
                else
                  "other"
                end

      expect(matched).to eq("got fast result")
    end
  end

  describe "immutability" do
    it "is frozen" do
      result = described_class.new(
        results: ["x"],
        early_result: "x",
        pending_count: 1,
        collector: nil
      )

      expect(result).to be_frozen
    end
  end

  describe "use case: early yield from parallel tools" do
    it "models early yield scenario" do
      # Simulate: 3 tools called, first one returns early
      all_results = []
      remaining_mutex = Mutex.new
      remaining_collected = false

      # First tool returns early
      early = "fast result"

      # Collector would block until all are done
      collector = -> {
        remaining_mutex.synchronize do
          return all_results if remaining_collected

          # Simulate blocking wait for slow tools
          all_results = ["fast result", "medium result", "slow result"]
          remaining_collected = true
          all_results
        end
      }

      result = described_class.new(
        results: [early],
        early_result: early,
        pending_count: 2,
        collector: collector
      )

      # Check early state
      expect(result.early?).to be true
      expect(result.complete?).to be false

      # Collect all
      final = result.collect_remaining
      expect(final).to eq(["fast result", "medium result", "slow result"])
    end
  end
end
