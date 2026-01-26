RSpec.describe Smolagents::Types::ObservabilityConfig do
  describe ".default" do
    it "creates config with :with_summary observe_mode" do
      config = described_class.default

      expect(config.observe_mode).to eq(:with_summary)
    end

    it "creates config with nil summarizer_model" do
      config = described_class.default

      expect(config.summarizer_model).to be_nil
    end

    it "is frozen" do
      config = described_class.default

      expect(config).to be_frozen
    end
  end

  describe ".create" do
    it "creates config with custom values" do
      model = double("Model")
      config = described_class.create(
        observe_mode: :raw,
        summarizer_model: model
      )

      expect(config.observe_mode).to eq(:raw)
      expect(config.summarizer_model).to eq(model)
    end

    it "uses default for unspecified observe_mode" do
      config = described_class.create

      expect(config.observe_mode).to eq(:with_summary)
    end

    it "validates observe_mode" do
      expect do
        described_class.create(observe_mode: :invalid)
      end.to raise_error(ArgumentError, /Invalid observe_mode/)
    end

    it "is frozen" do
      config = described_class.create(observe_mode: :minimal)

      expect(config).to be_frozen
    end
  end

  describe "valid observe modes" do
    it "accepts :with_summary" do
      expect { described_class.create(observe_mode: :with_summary) }.not_to raise_error
    end

    it "accepts :structure_only" do
      expect { described_class.create(observe_mode: :structure_only) }.not_to raise_error
    end

    it "accepts :raw" do
      expect { described_class.create(observe_mode: :raw) }.not_to raise_error
    end

    it "accepts :minimal" do
      expect { described_class.create(observe_mode: :minimal) }.not_to raise_error
    end
  end

  describe "#with_summary?" do
    it "returns true when observe_mode is :with_summary" do
      config = described_class.create(observe_mode: :with_summary)

      expect(config.with_summary?).to be true
    end

    it "returns false for other modes" do
      %i[structure_only raw minimal].each do |mode|
        config = described_class.create(observe_mode: mode)

        expect(config.with_summary?).to be false
      end
    end
  end

  describe "#structure_only?" do
    it "returns true when observe_mode is :structure_only" do
      config = described_class.create(observe_mode: :structure_only)

      expect(config.structure_only?).to be true
    end

    it "returns false for other modes" do
      %i[with_summary raw minimal].each do |mode|
        config = described_class.create(observe_mode: mode)

        expect(config.structure_only?).to be false
      end
    end
  end

  describe "#raw?" do
    it "returns true when observe_mode is :raw" do
      config = described_class.create(observe_mode: :raw)

      expect(config.raw?).to be true
    end

    it "returns false for other modes" do
      %i[with_summary structure_only minimal].each do |mode|
        config = described_class.create(observe_mode: mode)

        expect(config.raw?).to be false
      end
    end
  end

  describe "#minimal?" do
    it "returns true when observe_mode is :minimal" do
      config = described_class.create(observe_mode: :minimal)

      expect(config.minimal?).to be true
    end

    it "returns false for other modes" do
      %i[with_summary structure_only raw].each do |mode|
        config = described_class.create(observe_mode: mode)

        expect(config.minimal?).to be false
      end
    end
  end

  describe "#summarizer?" do
    it "returns true when summarizer_model is set" do
      model = double("Model")
      config = described_class.create(summarizer_model: model)

      expect(config.summarizer?).to be true
    end

    it "returns false when summarizer_model is nil" do
      config = described_class.default

      expect(config.summarizer?).to be false
    end
  end

  describe "pattern matching" do
    it "matches on observe_mode" do
      config = described_class.create(observe_mode: :raw)

      matched = case config
                in observe_mode: :raw
                  "raw mode"
                else
                  "other"
                end

      expect(matched).to eq("raw mode")
    end
  end

  describe "immutability" do
    it "creates frozen instances" do
      config = described_class.default

      expect(config).to be_frozen
    end

    it "with method returns new frozen instance" do
      config = described_class.default
      updated = config.with(observe_mode: :minimal)

      expect(updated).to be_frozen
      expect(config.observe_mode).to eq(:with_summary)
    end
  end
end
