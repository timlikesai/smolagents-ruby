RSpec.describe Smolagents::Types::AgentConfig do
  describe ".default" do
    it "creates config with nil values" do
      config = described_class.default

      expect(config.max_steps).to be_nil
      expect(config.planning_interval).to be_nil
      expect(config.planning_templates).to be_nil
      expect(config.custom_instructions).to be_nil
      expect(config.evaluation_enabled).to be true
      expect(config.authorized_imports).to be_nil
      expect(config.spawn_config).to be_nil
      expect(config.memory_config).to be_nil
    end
  end

  describe ".create" do
    it "accepts all configuration options" do
      spawn_config = Smolagents::Types::SpawnConfig.create
      memory_config = Smolagents::Types::MemoryConfig.default
      templates = { initial_plan: "Plan: %<task>s" }

      config = described_class.create(
        max_steps: 15,
        planning_interval: 3,
        planning_templates: templates,
        custom_instructions: "Be helpful",
        evaluation_enabled: true,
        authorized_imports: %w[json yaml],
        spawn_config:,
        memory_config:
      )

      expect(config.max_steps).to eq(15)
      expect(config.planning_interval).to eq(3)
      expect(config.planning_templates).to eq(templates)
      expect(config.custom_instructions).to eq("Be helpful")
      expect(config.evaluation_enabled).to be true
      expect(config.authorized_imports).to eq(%w[json yaml])
      expect(config.spawn_config).to eq(spawn_config)
      expect(config.memory_config).to eq(memory_config)
    end

    it "uses defaults for unspecified options" do
      config = described_class.create(max_steps: 20)

      expect(config.max_steps).to eq(20)
      expect(config.planning_interval).to be_nil
      expect(config.evaluation_enabled).to be true
    end
  end

  describe "#with" do
    it "returns new config with specified changes" do
      original = described_class.create(max_steps: 10, evaluation_enabled: false)
      modified = original.with(max_steps: 20)

      expect(modified.max_steps).to eq(20)
      expect(modified.evaluation_enabled).to be false
      expect(original.max_steps).to eq(10) # Original unchanged
    end

    it "supports changing multiple fields" do
      original = described_class.default
      modified = original.with(max_steps: 15, custom_instructions: "Updated")

      expect(modified.max_steps).to eq(15)
      expect(modified.custom_instructions).to eq("Updated")
    end
  end

  describe "#planning?" do
    it "returns true when planning_interval is set" do
      config = described_class.create(planning_interval: 3)

      expect(config.planning?).to be true
    end

    it "returns false when planning_interval is nil" do
      config = described_class.default

      expect(config.planning?).to be false
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
  end

  describe "#spawn?" do
    it "returns true when spawn_config is enabled" do
      spawn_config = Smolagents::Types::SpawnConfig.create(max_children: 5)
      config = described_class.create(spawn_config:)

      expect(config.spawn?).to be true
    end

    it "returns false when spawn_config is nil" do
      config = described_class.default

      expect(config.spawn?).to be false
    end

    it "returns false when spawn_config is disabled" do
      spawn_config = Smolagents::Types::SpawnConfig.disabled
      config = described_class.create(spawn_config:)

      expect(config.spawn?).to be false
    end
  end

  describe "#custom_instructions?" do
    it "returns true when custom_instructions is present" do
      config = described_class.create(custom_instructions: "Be helpful")

      expect(config.custom_instructions?).to be true
    end

    it "returns false when custom_instructions is nil" do
      config = described_class.default

      expect(config.custom_instructions?).to be false
    end

    it "returns false when custom_instructions is empty" do
      config = described_class.create(custom_instructions: "")

      expect(config.custom_instructions?).to be false
    end
  end

  describe "#to_runtime_args" do
    it "returns hash without nil values" do
      config = described_class.create(max_steps: 10, planning_interval: nil)

      args = config.to_runtime_args

      expect(args[:max_steps]).to eq(10)
      expect(args).not_to have_key(:planning_interval)
    end

    it "includes all non-nil values" do
      config = described_class.create(
        max_steps: 15,
        planning_interval: 3,
        evaluation_enabled: true
      )

      args = config.to_runtime_args

      expect(args[:max_steps]).to eq(15)
      expect(args[:planning_interval]).to eq(3)
      expect(args[:evaluation_enabled]).to be true
    end
  end

  describe "immutability" do
    it "is frozen after creation" do
      config = described_class.create(max_steps: 10)

      expect(config).to be_frozen
    end

    it "returns new instance from #with" do
      original = described_class.create(max_steps: 10)
      modified = original.with(max_steps: 20)

      expect(modified).not_to be(original)
    end
  end
end
