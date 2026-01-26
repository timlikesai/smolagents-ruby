RSpec.describe Smolagents::Types::PlanningConfig do
  describe ".default" do
    it "creates config with nil interval (disabled)" do
      config = described_class.default

      expect(config.interval).to be_nil
    end

    it "creates config with nil templates" do
      config = described_class.default

      expect(config.templates).to be_nil
    end

    it "is frozen" do
      config = described_class.default

      expect(config).to be_frozen
    end
  end

  describe ".create" do
    it "creates config with custom interval" do
      config = described_class.create(interval: 3)

      expect(config.interval).to eq(3)
    end

    it "creates config with custom templates" do
      templates = { initial: "Plan the task", update: "Update the plan" }
      config = described_class.create(templates:)

      expect(config.templates).to eq(templates)
    end

    it "uses nil defaults for unspecified options" do
      config = described_class.create

      expect(config.interval).to be_nil
      expect(config.templates).to be_nil
    end

    it "is frozen" do
      config = described_class.create(interval: 5)

      expect(config).to be_frozen
    end
  end

  describe "#enabled?" do
    it "returns true when interval is set" do
      config = described_class.create(interval: 3)

      expect(config.enabled?).to be true
    end

    it "returns false when interval is nil" do
      config = described_class.default

      expect(config.enabled?).to be false
    end

    it "returns true for interval of 1" do
      config = described_class.create(interval: 1)

      expect(config.enabled?).to be true
    end
  end

  describe "#disabled?" do
    it "returns true when interval is nil" do
      config = described_class.default

      expect(config.disabled?).to be true
    end

    it "returns false when interval is set" do
      config = described_class.create(interval: 5)

      expect(config.disabled?).to be false
    end
  end

  describe "#custom_templates?" do
    it "returns true when templates is set" do
      templates = { plan: "template" }
      config = described_class.create(templates:)

      expect(config.custom_templates?).to be true
    end

    it "returns false when templates is nil" do
      config = described_class.default

      expect(config.custom_templates?).to be false
    end
  end

  describe "pattern matching" do
    it "matches on interval" do
      config = described_class.create(interval: 3)

      matched = case config
                in interval: 3
                  "every 3 steps"
                else
                  "other"
                end

      expect(matched).to eq("every 3 steps")
    end

    it "matches on nil interval" do
      config = described_class.default

      matched = case config
                in interval: nil
                  "disabled"
                else
                  "enabled"
                end

      expect(matched).to eq("disabled")
    end
  end

  describe "immutability" do
    it "creates frozen instances" do
      config = described_class.create(interval: 3)

      expect(config).to be_frozen
    end

    it "with method returns new frozen instance" do
      config = described_class.default
      updated = config.with(interval: 5)

      expect(updated).to be_frozen
      expect(config.interval).to be_nil
    end
  end
end
