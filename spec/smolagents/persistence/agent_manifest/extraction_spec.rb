require "spec_helper"

RSpec.describe Smolagents::Persistence::AgentManifestExtraction do
  let(:mock_model) do
    model = Smolagents::Model.new(model_id: "gpt-4")
    model.instance_variable_set(:@temperature, 0.7)
    model
  end

  let(:tools) { [Smolagents::FinalAnswerTool.new] }

  let(:agent) do
    planning = Smolagents::Types::PlanningConfig.create(interval: 3)
    behavioral = Smolagents::Types::BehavioralConfig.create(custom_instructions: "Be concise.")
    config = Smolagents::Types::AgentConfig.create(
      max_steps: 15,
      planning:,
      behavioral:
    )
    Smolagents::Agents::Agent.new(model: mock_model, tools:, config:)
  end

  describe ".extract_all" do
    it "combines core, tools, and metadata" do
      result = described_class.extract_all(agent, metadata: { author: "test" })

      expect(result).to include(:version, :agent_class, :model, :tools, :managed_agents, :metadata)
    end

    it "includes created_at timestamp in metadata" do
      result = described_class.extract_all(agent, metadata: {})

      expect(result[:metadata][:created_at]).to match(/\d{4}-\d{2}-\d{2}T/)
    end

    it "merges custom metadata" do
      result = described_class.extract_all(agent, metadata: { author: "Tim", version: "2.0" })

      expect(result[:metadata][:author]).to eq("Tim")
      expect(result[:metadata][:version]).to eq("2.0")
      expect(result[:metadata][:created_at]).to be_a(String)
    end
  end

  describe ".extract_core" do
    it "includes manifest version" do
      result = described_class.extract_core(agent)

      expect(result[:version]).to eq(Smolagents::Persistence::AgentManifestConstants::VERSION)
    end

    it "captures agent class name" do
      result = described_class.extract_core(agent)

      expect(result[:agent_class]).to eq("Smolagents::Agents::Agent")
    end

    it "includes model manifest" do
      result = described_class.extract_core(agent)

      expect(result[:model]).to be_a(Smolagents::Persistence::ModelManifest)
      expect(result[:model].model_id).to eq("gpt-4")
    end

    it "extracts config fields" do
      result = described_class.extract_core(agent)

      expect(result[:max_steps]).to eq(15)
      # planning_interval is stored on runtime, not agent, so extraction returns nil
      # custom_instructions is stored on runtime, not agent, so extraction returns nil
      expect(result).to have_key(:planning_interval)
      expect(result).to have_key(:custom_instructions)
    end
  end

  describe ".extract_tools" do
    it "captures regular tools as tool manifests" do
      result = described_class.extract_tools(agent)

      expect(result[:tools]).to be_an(Array)
      expect(result[:tools].first).to be_a(Smolagents::Persistence::ToolManifest)
    end

    it "excludes ManagedAgentTool from tools list" do
      # Create an agent with a managed agent
      managed = Smolagents::Agents::Agent.new(model: mock_model, tools:)
      agent_with_managed = Smolagents::Agents::Agent.new(
        model: mock_model,
        tools:,
        managed_agents: [managed]
      )

      result = described_class.extract_tools(agent_with_managed)

      tool_classes = result[:tools].map(&:class_name)
      expect(tool_classes).not_to include("Smolagents::ManagedAgentTool")
    end

    it "extracts managed agents recursively" do
      managed = Smolagents::Agents::Agent.new(model: mock_model, tools:)
      agent_with_managed = Smolagents::Agents::Agent.new(
        model: mock_model,
        tools:,
        managed_agents: [managed]
      )

      result = described_class.extract_tools(agent_with_managed)

      expect(result[:managed_agents]).to be_a(Hash)
      expect(result[:managed_agents].values.first).to include(:version, :agent_class, :model)
    end

    it "returns empty managed_agents hash when agent has no managed agents" do
      result = described_class.extract_tools(agent)

      expect(result[:managed_agents]).to eq({})
    end
  end
end
