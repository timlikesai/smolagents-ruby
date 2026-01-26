require "smolagents"

RSpec.describe Smolagents::Types::QueueStats do
  describe ".new" do
    it "creates queue stats" do
      stats = described_class.new(
        depth: 5,
        processing: true,
        total_processed: 100,
        avg_wait_time: 0.5,
        max_wait_time: 2.0
      )

      expect(stats.depth).to eq(5)
      expect(stats.processing).to be true
      expect(stats.total_processed).to eq(100)
      expect(stats.avg_wait_time).to eq(0.5)
      expect(stats.max_wait_time).to eq(2.0)
    end

    it "is immutable" do
      stats = described_class.new(
        depth: 0, processing: false, total_processed: 0,
        avg_wait_time: 0.0, max_wait_time: 0.0
      )
      expect(stats).to be_frozen
    end
  end

  describe ".empty" do
    it "creates empty/initial stats" do
      stats = described_class.empty

      expect(stats.depth).to eq(0)
      expect(stats.processing).to be false
      expect(stats.total_processed).to eq(0)
      expect(stats.avg_wait_time).to eq(0.0)
      expect(stats.max_wait_time).to eq(0.0)
    end
  end

  describe "#empty?" do
    it "returns true when depth is zero" do
      stats = described_class.empty
      expect(stats.empty?).to be true
    end

    it "returns false when depth is non-zero" do
      stats = described_class.new(
        depth: 5, processing: false, total_processed: 0,
        avg_wait_time: 0.0, max_wait_time: 0.0
      )
      expect(stats.empty?).to be false
    end
  end

  describe "#busy?" do
    it "returns true when processing" do
      stats = described_class.new(
        depth: 0, processing: true, total_processed: 0,
        avg_wait_time: 0.0, max_wait_time: 0.0
      )
      expect(stats.busy?).to be true
    end

    it "returns false when not processing" do
      stats = described_class.empty
      expect(stats.busy?).to be false
    end
  end

  describe "#idle?" do
    it "returns true when empty and not processing" do
      stats = described_class.empty
      expect(stats.idle?).to be true
    end

    it "returns false when processing" do
      stats = described_class.new(
        depth: 0, processing: true, total_processed: 0,
        avg_wait_time: 0.0, max_wait_time: 0.0
      )
      expect(stats.idle?).to be false
    end

    it "returns false when queue has items" do
      stats = described_class.new(
        depth: 5, processing: false, total_processed: 0,
        avg_wait_time: 0.0, max_wait_time: 0.0
      )
      expect(stats.idle?).to be false
    end
  end

  describe "#to_h" do
    it "returns serializable hash" do
      stats = described_class.new(
        depth: 5,
        processing: true,
        total_processed: 100,
        avg_wait_time: 0.567,
        max_wait_time: 2.123
      )

      hash = stats.to_h

      expect(hash[:depth]).to eq(5)
      expect(hash[:processing]).to be true
      expect(hash[:total_processed]).to eq(100)
      expect(hash[:avg_wait_time]).to eq(0.57) # rounded
      expect(hash[:max_wait_time]).to eq(2.12) # rounded
    end
  end

  describe "pattern matching" do
    it "supports deconstruct_keys" do
      stats = described_class.new(
        depth: 10, processing: true, total_processed: 50,
        avg_wait_time: 0.5, max_wait_time: 1.0
      )

      case stats
      in { depth:, processing: true }
        expect(depth).to eq(10)
      else
        raise "Pattern should match"
      end
    end
  end
end
