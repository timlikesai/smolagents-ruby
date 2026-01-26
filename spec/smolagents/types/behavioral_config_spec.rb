RSpec.describe Smolagents::Types::BehavioralConfig do
  describe ".default" do
    it "creates config with evaluation enabled" do
      config = described_class.default

      expect(config.evaluation_enabled).to be true
    end

    it "creates config with nil custom_instructions" do
      config = described_class.default

      expect(config.custom_instructions).to be_nil
    end

    it "creates config with nil refine_config" do
      config = described_class.default

      expect(config.refine_config).to be_nil
    end

    it "creates config with sync_events disabled" do
      config = described_class.default

      expect(config.sync_events).to be false
    end

    it "is frozen" do
      config = described_class.default

      expect(config).to be_frozen
    end
  end

  describe ".create" do
    it "creates config with custom values" do
      config = described_class.create(
        evaluation_enabled: false,
        custom_instructions: "Be concise",
        sync_events: true
      )

      expect(config.evaluation_enabled).to be false
      expect(config.custom_instructions).to eq("Be concise")
      expect(config.sync_events).to be true
    end

    it "uses defaults for unspecified options" do
      config = described_class.create(custom_instructions: "Instructions")

      expect(config.evaluation_enabled).to be true
      expect(config.sync_events).to be false
    end

    it "is frozen" do
      config = described_class.create(evaluation_enabled: true)

      expect(config).to be_frozen
    end
  end

  describe "#evaluation?" do
    it "returns true when evaluation_enabled is true" do
      config = described_class.create(evaluation_enabled: true)

      expect(config.evaluation?).to be true
    end

    it "returns false when evaluation_enabled is false" do
      config = described_class.create(evaluation_enabled: false)

      expect(config.evaluation?).to be false
    end

    it "returns false when evaluation_enabled is nil" do
      config = described_class.new(
        evaluation_enabled: nil,
        custom_instructions: nil,
        refine_config: nil,
        sync_events: false
      )

      expect(config.evaluation?).to be false
    end
  end

  describe "#custom_instructions?" do
    it "returns true when custom_instructions is set" do
      config = described_class.create(custom_instructions: "Be helpful")

      expect(config.custom_instructions?).to be true
    end

    it "returns false when custom_instructions is nil" do
      config = described_class.default

      expect(config.custom_instructions?).to be false
    end

    it "returns false when custom_instructions is empty string" do
      config = described_class.create(custom_instructions: "")

      expect(config.custom_instructions?).to be false
    end
  end

  describe "#refine?" do
    it "returns true when refine_config is enabled" do
      refine_config = Smolagents::Types::RefineConfig.default
      config = described_class.new(
        evaluation_enabled: true,
        custom_instructions: nil,
        refine_config:,
        sync_events: false
      )

      expect(config.refine?).to be true
    end

    it "returns false when refine_config is nil" do
      config = described_class.default

      expect(config.refine?).to be false
    end

    it "returns false when refine_config is disabled" do
      refine_config = Smolagents::Types::RefineConfig.disabled
      config = described_class.new(
        evaluation_enabled: true,
        custom_instructions: nil,
        refine_config:,
        sync_events: false
      )

      expect(config.refine?).to be false
    end
  end

  describe "#sync_events?" do
    it "returns true when sync_events is true" do
      config = described_class.create(sync_events: true)

      expect(config.sync_events?).to be true
    end

    it "returns false when sync_events is false" do
      config = described_class.default

      expect(config.sync_events?).to be false
    end

    it "returns false when sync_events is nil" do
      config = described_class.new(
        evaluation_enabled: true,
        custom_instructions: nil,
        refine_config: nil,
        sync_events: nil
      )

      expect(config.sync_events?).to be false
    end
  end

  describe "pattern matching" do
    it "matches on evaluation_enabled" do
      config = described_class.create(evaluation_enabled: true)

      matched = case config
                in evaluation_enabled: true
                  "evaluation on"
                else
                  "other"
                end

      expect(matched).to eq("evaluation on")
    end

    it "matches on custom_instructions" do
      config = described_class.create(custom_instructions: "Be brief")

      matched = case config
                in custom_instructions: "Be brief"
                  "custom"
                else
                  "default"
                end

      expect(matched).to eq("custom")
    end
  end

  describe "immutability" do
    it "creates frozen instances" do
      config = described_class.create(evaluation_enabled: true)

      expect(config).to be_frozen
    end

    it "with method returns new frozen instance" do
      config = described_class.default
      updated = config.with(evaluation_enabled: false)

      expect(updated).to be_frozen
      expect(config.evaluation_enabled).to be true
    end
  end
end
