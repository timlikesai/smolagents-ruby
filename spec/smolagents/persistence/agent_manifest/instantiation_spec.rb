require "spec_helper"

RSpec.describe Smolagents::Persistence::AgentManifestInstantiation do
  let(:model_manifest) do
    Smolagents::Persistence::ModelManifest.new(
      class_name: "Smolagents::OpenAIModel",
      model_id: "gpt-4",
      provider: :openai,
      config: { temperature: 0.7 }
    )
  end

  let(:tool_manifest) do
    Smolagents::Persistence::ToolManifest.new(
      name: "final_answer",
      class_name: "Smolagents::FinalAnswerTool",
      registry_key: "final_answer",
      config: {}
    )
  end

  let(:manifest) do
    Smolagents::Persistence::AgentManifest.new(
      version: "1.0",
      agent_class: "Smolagents::Agents::Agent",
      model: model_manifest,
      tools: [tool_manifest],
      managed_agents: {},
      max_steps: 15,
      planning_interval: 3,
      custom_instructions: "Be helpful.",
      metadata: { created_at: Time.now.iso8601 }
    )
  end

  let(:mock_model) { Smolagents::Model.new(model_id: "gpt-4-turbo") }

  describe ".instantiate" do
    it "creates an agent with provided model" do
      agent = described_class.instantiate(manifest, model: mock_model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent.model).to eq(mock_model)
    end

    it "applies max_steps from manifest" do
      agent = described_class.instantiate(manifest, model: mock_model)

      expect(agent.max_steps).to eq(15)
    end

    it "applies overrides over manifest values" do
      agent = described_class.instantiate(manifest, model: mock_model, max_steps: 30)

      expect(agent.max_steps).to eq(30)
    end

    it "raises MissingModelError when model cannot be resolved" do
      manifest_without_local = Smolagents::Persistence::AgentManifest.new(
        version: "1.0",
        agent_class: "Smolagents::Agents::Agent",
        model: model_manifest,
        tools: [],
        managed_agents: {},
        max_steps: 10,
        planning_interval: nil,
        custom_instructions: nil,
        metadata: {}
      )

      # Remove env var temporarily
      original_key = ENV.fetch("OPENAI_API_KEY", nil)
      ENV.delete("OPENAI_API_KEY")

      expect do
        described_class.instantiate(manifest_without_local)
      end.to raise_error(Smolagents::Persistence::MissingModelError)

      ENV["OPENAI_API_KEY"] = original_key if original_key
    end

    it "raises UntrustedClassError for non-allowlisted agent class" do
      untrusted_manifest = Smolagents::Persistence::AgentManifest.new(
        version: "1.0",
        agent_class: "SomeEvilAgent",
        model: model_manifest,
        tools: [],
        managed_agents: {},
        max_steps: 10,
        planning_interval: nil,
        custom_instructions: nil,
        metadata: {}
      )

      expect do
        described_class.instantiate(untrusted_manifest, model: mock_model)
      end.to raise_error(Smolagents::Persistence::UntrustedClassError) do |error|
        expect(error.class_name).to eq("SomeEvilAgent")
      end
    end

    it "instantiates tools from manifests" do
      agent = described_class.instantiate(manifest, model: mock_model)

      expect(agent.tools.keys).to include("final_answer")
      expect(agent.tools["final_answer"]).to be_a(Smolagents::FinalAnswerTool)
    end

    context "with managed agents" do
      let(:sub_manifest) do
        Smolagents::Persistence::AgentManifest.new(
          version: "1.0",
          agent_class: "Smolagents::Agents::Agent",
          model: model_manifest,
          tools: [tool_manifest],
          managed_agents: {},
          max_steps: 5,
          planning_interval: nil,
          custom_instructions: "Sub-agent instructions",
          metadata: {}
        )
      end

      let(:manifest_with_managed) do
        Smolagents::Persistence::AgentManifest.new(
          version: "1.0",
          agent_class: "Smolagents::Agents::Agent",
          model: model_manifest,
          tools: [tool_manifest],
          managed_agents: { "helper" => sub_manifest },
          max_steps: 10,
          planning_interval: nil,
          custom_instructions: nil,
          metadata: {}
        )
      end

      it "instantiates managed agents recursively" do
        agent = described_class.instantiate(manifest_with_managed, model: mock_model)

        expect(agent.managed_agents).not_to be_empty
      end
    end
  end
end
