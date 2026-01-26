RSpec.describe Smolagents::Types::ExecutionStage do
  describe ".parallel" do
    it "creates a parallel stage" do
      stage = described_class.parallel(:a, :b, :c)

      expect(stage.parallel?).to be true
      expect(stage.sequential?).to be false
      expect(stage.agents).to eq(%w[a b c])
    end

    it "accepts symbols and strings" do
      stage = described_class.parallel("broad", :deep)

      expect(stage.agents).to eq(%w[broad deep])
    end

    it "flattens arrays" do
      stage = described_class.parallel(%i[a b], :c)

      expect(stage.agents).to eq(%w[a b c])
    end

    it "freezes agents array" do
      stage = described_class.parallel(:a)

      expect(stage.agents).to be_frozen
    end
  end

  describe ".sequential" do
    it "creates a sequential stage" do
      stage = described_class.sequential(:synthesizer)

      expect(stage.sequential?).to be true
      expect(stage.parallel?).to be false
      expect(stage.agents).to eq(["synthesizer"])
    end
  end

  describe "#validate!" do
    it "returns self when valid" do
      stage = described_class.parallel(:a)

      expect(stage.validate!).to eq(stage)
    end

    it "raises on empty agents" do
      stage = described_class.new(agents: [], mode: :parallel)

      expect { stage.validate! }.to raise_error(ArgumentError, /at least one agent/)
    end

    it "raises on invalid mode" do
      stage = described_class.new(agents: ["a"], mode: :invalid)

      expect { stage.validate! }.to raise_error(ArgumentError, /Invalid mode/)
    end
  end

  describe "immutability" do
    it "is frozen" do
      stage = described_class.parallel(:a)

      expect(stage).to be_frozen
    end
  end
end
