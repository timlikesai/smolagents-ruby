RSpec.describe Smolagents::Types::SpawnConfig do
  describe ".create" do
    it "creates a config with default values" do
      config = described_class.create
      expect(config.allowed_models).to eq([])
      expect(config.allowed_tools).to eq([:final_answer])
      expect(config.max_children).to eq(3)
      expect(config.inherit_scope.level).to eq(:task_only)
    end

    it "creates a config with custom values" do
      config = described_class.create(
        allow: %i[gpt4 claude],
        tools: %i[search web],
        inherit: :observations,
        max_children: 5
      )
      expect(config.allowed_models).to eq(%i[gpt4 claude])
      expect(config.allowed_tools).to eq(%i[search web])
      expect(config.max_children).to eq(5)
      expect(config.inherit_scope.level).to eq(:observations)
    end
  end

  describe ".disabled" do
    it "creates a config with zero max_children" do
      config = described_class.disabled
      expect(config.max_children).to eq(0)
      expect(config.enabled?).to be(false)
      expect(config.disabled?).to be(true)
    end
  end

  describe "#model_allowed?" do
    it "allows any model when allowed_models is empty" do
      config = described_class.create(allow: [])
      expect(config.model_allowed?(:any_model)).to be(true)
    end

    it "checks against allowed_models list" do
      config = described_class.create(allow: [:gpt4])
      expect(config.model_allowed?(:gpt4)).to be(true)
      expect(config.model_allowed?(:claude)).to be(false)
    end
  end

  describe "#tool_allowed?" do
    it "checks against allowed_tools list" do
      config = described_class.create(tools: %i[search web])
      expect(config.tool_allowed?(:search)).to be(true)
      expect(config.tool_allowed?(:browser)).to be(false)
    end
  end

  describe "#enabled? / #disabled?" do
    it "returns true for enabled when max_children > 0" do
      config = described_class.create(max_children: 3)
      expect(config.enabled?).to be(true)
      expect(config.disabled?).to be(false)
    end

    it "returns true for disabled when max_children == 0" do
      config = described_class.create(max_children: 0)
      expect(config.enabled?).to be(false)
      expect(config.disabled?).to be(true)
    end
  end
end
