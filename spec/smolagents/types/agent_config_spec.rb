RSpec.describe Smolagents::Types::AgentConfig do
  describe ".default" do
    it "creates config with nil core values and default sub-configs" do
      config = described_class.default

      expect(config.max_steps).to be_nil
      expect(config.authorized_imports).to be_nil
      expect(config.spawn_config).to be_nil
      expect(config.memory_config).to be_nil
      expect(config.planning).to be_a(Smolagents::Types::PlanningConfig)
      expect(config.behavioral).to be_a(Smolagents::Types::BehavioralConfig)
      expect(config.observability).to be_a(Smolagents::Types::ObservabilityConfig)
    end

    it "has planning disabled by default" do
      config = described_class.default

      expect(config.planning.enabled?).to be false
    end

    it "has evaluation enabled by default" do
      config = described_class.default

      expect(config.behavioral.evaluation?).to be true
    end
  end

  describe ".create" do
    it "accepts all configuration options" do
      spawn_config = Smolagents::Types::SpawnConfig.create
      memory_config = Smolagents::Types::MemoryConfig.default
      planning = Smolagents::Types::PlanningConfig.create(interval: 3)
      behavioral = Smolagents::Types::BehavioralConfig.create(custom_instructions: "Be helpful")
      observability = Smolagents::Types::ObservabilityConfig.create(observe_mode: :raw)

      config = described_class.create(
        max_steps: 15,
        authorized_imports: %w[json yaml],
        spawn_config:,
        memory_config:,
        planning:,
        behavioral:,
        observability:
      )

      expect(config.max_steps).to eq(15)
      expect(config.authorized_imports).to eq(%w[json yaml])
      expect(config.spawn_config).to eq(spawn_config)
      expect(config.memory_config).to eq(memory_config)
      expect(config.planning.interval).to eq(3)
      expect(config.behavioral.custom_instructions).to eq("Be helpful")
      expect(config.observability.observe_mode).to eq(:raw)
    end

    it "uses default sub-configs for unspecified options" do
      config = described_class.create(max_steps: 20)

      expect(config.max_steps).to eq(20)
      expect(config.planning).to eq(Smolagents::Types::PlanningConfig.default)
      expect(config.behavioral.evaluation?).to be true
    end
  end

  describe "#with" do
    it "returns new config with specified changes" do
      original = described_class.create(max_steps: 10)
      modified = original.with(max_steps: 20)

      expect(modified.max_steps).to eq(20)
      expect(original.max_steps).to eq(10) # Original unchanged
    end

    it "supports changing sub-configs" do
      original = described_class.default
      new_planning = Smolagents::Types::PlanningConfig.create(interval: 5)
      modified = original.with(planning: new_planning)

      expect(modified.planning.interval).to eq(5)
      expect(original.planning.enabled?).to be false
    end
  end

  describe "#planning?" do
    it "returns true when planning is enabled" do
      planning = Smolagents::Types::PlanningConfig.create(interval: 3)
      config = described_class.create(planning:)

      expect(config.planning?).to be true
    end

    it "returns false when planning is disabled" do
      config = described_class.default

      expect(config.planning?).to be false
    end
  end

  describe "#evaluation?" do
    it "returns true when evaluation is enabled" do
      behavioral = Smolagents::Types::BehavioralConfig.create(evaluation_enabled: true)
      config = described_class.create(behavioral:)

      expect(config.evaluation?).to be true
    end

    it "returns false when evaluation is disabled" do
      behavioral = Smolagents::Types::BehavioralConfig.create(evaluation_enabled: false)
      config = described_class.create(behavioral:)

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
      behavioral = Smolagents::Types::BehavioralConfig.create(custom_instructions: "Be helpful")
      config = described_class.create(behavioral:)

      expect(config.custom_instructions?).to be true
    end

    it "returns false when custom_instructions is nil" do
      config = described_class.default

      expect(config.custom_instructions?).to be false
    end

    it "returns false when custom_instructions is empty" do
      behavioral = Smolagents::Types::BehavioralConfig.create(custom_instructions: "")
      config = described_class.create(behavioral:)

      expect(config.custom_instructions?).to be false
    end
  end

  describe "#to_runtime_args" do
    it "returns hash without nil values" do
      config = described_class.create(max_steps: 10)

      args = config.to_runtime_args

      expect(args[:max_steps]).to eq(10)
      expect(args).not_to have_key(:authorized_imports)
    end

    it "includes sub-configs" do
      planning = Smolagents::Types::PlanningConfig.create(interval: 3)
      config = described_class.create(max_steps: 15, planning:)

      args = config.to_runtime_args

      expect(args[:max_steps]).to eq(15)
      expect(args[:planning].interval).to eq(3)
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
