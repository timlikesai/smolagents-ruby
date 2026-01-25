require "smolagents"

RSpec.describe Smolagents::Types::SetupConfig do
  describe ".create" do
    it "creates config with required parameters" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(tools:, model:)
      expect(config.tools).to eq(tools)
      expect(config.model).to eq(model)
    end

    it "defaults optional parameters to nil" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(tools:, model:)
      expect(config.max_steps).to be_nil
      expect(config.planning_interval).to be_nil
      expect(config.managed_agents).to be_nil
      expect(config.custom_instructions).to be_nil
      expect(config.logger).to be_nil
      expect(config.spawn_config).to be_nil
    end

    it "accepts all parameters" do
      tools = { "search" => double("tool") }
      model = double("model")
      logger = double("logger")
      managed = { "agent1" => double("agent") }
      spawn_cfg = double("spawn_config")

      config = described_class.create(
        tools:,
        model:,
        max_steps: 20,
        planning_interval: 5,
        planning_templates: { custom: "template" },
        managed_agents: managed,
        custom_instructions: "Be careful",
        logger:,
        spawn_config: spawn_cfg,
        evaluation_enabled: true
      )

      expect(config.max_steps).to eq(20)
      expect(config.planning_interval).to eq(5)
      expect(config.planning_templates).to eq({ custom: "template" })
      expect(config.managed_agents).to eq(managed)
      expect(config.custom_instructions).to eq("Be careful")
      expect(config.logger).to eq(logger)
      expect(config.spawn_config).to eq(spawn_cfg)
      expect(config.evaluation_enabled).to be true
    end

    it "defaults evaluation_enabled to false" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(tools:, model:)
      expect(config.evaluation_enabled).to be false
    end
  end

  describe "#with" do
    it "returns new config with changes" do
      tools = { "search" => double("tool") }
      model = double("model")
      original = described_class.create(tools:, model:)
      updated = original.with(max_steps: 15, planning_interval: 3)
      expect(updated.max_steps).to eq(15)
      expect(updated.planning_interval).to eq(3)
    end

    it "preserves other fields" do
      tools = { "search" => double("tool") }
      model = double("model")
      original = described_class.create(
        tools:,
        model:,
        max_steps: 10,
        custom_instructions: "test"
      )
      updated = original.with(max_steps: 20)
      expect(updated.max_steps).to eq(20)
      expect(updated.custom_instructions).to eq("test")
      expect(updated.tools).to eq(tools)
    end

    it "does not modify original" do
      tools = { "search" => double("tool") }
      model = double("model")
      original = described_class.create(tools:, model:)
      updated = original.with(max_steps: 15)
      expect(original.max_steps).to be_nil
      expect(updated.max_steps).to eq(15)
    end
  end

  describe "#planning?" do
    it "returns true when planning_interval is set" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(tools:, model:, planning_interval: 5)
      expect(config.planning?).to be true
    end

    it "returns false when planning_interval is nil" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(tools:, model:)
      expect(config.planning?).to be false
    end

    it "returns true for any positive interval" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(tools:, model:, planning_interval: 1)
      expect(config.planning?).to be true
    end
  end

  describe "#evaluation?" do
    it "returns true when evaluation_enabled is true" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(
        tools:,
        model:,
        evaluation_enabled: true
      )
      expect(config.evaluation?).to be true
    end

    it "returns false when evaluation_enabled is false" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(
        tools:,
        model:,
        evaluation_enabled: false
      )
      expect(config.evaluation?).to be false
    end
  end

  describe "#managed_agents?" do
    it "returns true when managed_agents are present" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(
        tools:,
        model:,
        managed_agents: { "agent1" => double("agent") }
      )
      expect(config.managed_agents?).to be true
    end

    it "returns false when managed_agents is nil" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(tools:, model:)
      expect(config.managed_agents?).to be false
    end

    it "returns false when managed_agents is empty" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(tools:, model:, managed_agents: {})
      expect(config.managed_agents?).to be false
    end
  end

  describe "field accessors" do
    it "returns tools" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(tools:, model:)
      expect(config.tools).to eq(tools)
    end

    it "returns model" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(tools:, model:)
      expect(config.model).to eq(model)
    end

    it "returns max_steps" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(tools:, model:, max_steps: 25)
      expect(config.max_steps).to eq(25)
    end

    it "returns planning_interval" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(tools:, model:, planning_interval: 7)
      expect(config.planning_interval).to eq(7)
    end

    it "returns custom_instructions" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(
        tools:,
        model:,
        custom_instructions: "Be helpful"
      )
      expect(config.custom_instructions).to eq("Be helpful")
    end

    it "returns logger" do
      tools = { "search" => double("tool") }
      model = double("model")
      logger = double("logger")
      config = described_class.create(tools:, model:, logger:)
      expect(config.logger).to eq(logger)
    end

    it "returns managed_agents" do
      tools = { "search" => double("tool") }
      model = double("model")
      agents = { "agent" => double("agent") }
      config = described_class.create(tools:, model:, managed_agents: agents)
      expect(config.managed_agents).to eq(agents)
    end

    it "returns spawn_config" do
      tools = { "search" => double("tool") }
      model = double("model")
      spawn_cfg = double("spawn_config")
      config = described_class.create(tools:, model:, spawn_config: spawn_cfg)
      expect(config.spawn_config).to eq(spawn_cfg)
    end

    it "returns planning_templates" do
      tools = { "search" => double("tool") }
      model = double("model")
      templates = { custom: "template" }
      config = described_class.create(tools:, model:, planning_templates: templates)
      expect(config.planning_templates).to eq(templates)
    end

    it "returns evaluation_enabled" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(tools:, model:, evaluation_enabled: true)
      expect(config.evaluation_enabled).to be true
    end
  end

  describe "immutability" do
    it "is frozen" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(tools:, model:)
      expect(config).to be_frozen
    end

    it "returns new instance from with" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(tools:, model:)
      new_config = config.with(max_steps: 10)
      expect(new_config).not_to equal(config)
      expect(new_config).to be_frozen
    end
  end

  describe "typical usage patterns" do
    it "handles minimal config" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(tools:, model:)
      expect(config.planning?).to be false
      expect(config.evaluation?).to be false
      expect(config.managed_agents?).to be false
    end

    it "handles full featured config" do
      tools = { "search" => double("tool"), "visit" => double("tool") }
      model = double("model")
      config = described_class.create(
        tools:,
        model:,
        max_steps: 20,
        planning_interval: 5,
        custom_instructions: "instructions",
        evaluation_enabled: true,
        managed_agents: { "agent1" => double("agent") }
      )
      expect(config.planning?).to be true
      expect(config.evaluation?).to be true
      expect(config.managed_agents?).to be true
    end

    it "allows incremental building with with() method" do
      tools = { "search" => double("tool") }
      model = double("model")
      config = described_class.create(tools:, model:)
                              .with(max_steps: 15)
                              .with(planning_interval: 3)
                              .with(evaluation_enabled: true)

      expect(config.max_steps).to eq(15)
      expect(config.planning_interval).to eq(3)
      expect(config.evaluation_enabled).to be true
    end
  end

  describe "equality" do
    it "equals identical configs" do
      tools = { "search" => double("tool") }
      model = double("model")
      c1 = described_class.create(tools:, model:, max_steps: 10)
      c2 = described_class.create(tools:, model:, max_steps: 10)
      expect(c1).to eq(c2)
    end
  end
end
