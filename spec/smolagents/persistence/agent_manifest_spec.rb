# frozen_string_literal: true

RSpec.describe Smolagents::Persistence::AgentManifest do
  let(:mock_model) do
    model = Smolagents::Model.new(model_id: "gpt-4")
    model.instance_variable_set(:@temperature, 0.7)
    model
  end

  let(:tools) { [Smolagents::FinalAnswerTool.new] }

  let(:agent) do
    Smolagents::Agents::ToolCalling.new(
      model: mock_model,
      tools: tools,
      max_steps: 15,
      custom_instructions: "Be concise."
    )
  end

  describe ".from_agent" do
    it "captures agent class" do
      manifest = described_class.from_agent(agent)

      expect(manifest.agent_class).to eq("Smolagents::Agents::ToolCalling")
    end

    it "captures model manifest" do
      manifest = described_class.from_agent(agent)

      expect(manifest.model).to be_a(Smolagents::Persistence::ModelManifest)
      expect(manifest.model.model_id).to eq("gpt-4")
    end

    it "captures tool manifests" do
      manifest = described_class.from_agent(agent)

      expect(manifest.tools).to be_an(Array)
      expect(manifest.tools.first).to be_a(Smolagents::Persistence::ToolManifest)
      expect(manifest.tools.first.name).to eq("final_answer")
    end

    it "captures configuration" do
      manifest = described_class.from_agent(agent)

      expect(manifest.max_steps).to eq(15)
      expect(manifest.custom_instructions).to eq("Be concise.")
    end

    it "includes version and metadata" do
      manifest = described_class.from_agent(agent)

      expect(manifest.version).to eq("1.0")
      expect(manifest.metadata[:created_at]).to be_a(String)
    end

    it "accepts custom metadata" do
      manifest = described_class.from_agent(agent, metadata: { author: "Tim" })

      expect(manifest.metadata[:author]).to eq("Tim")
      expect(manifest.metadata[:created_at]).to be_a(String)
    end
  end

  describe "#to_h" do
    it "returns fully serializable hash" do
      manifest = described_class.from_agent(agent)
      hash = manifest.to_h

      expect(hash[:version]).to eq("1.0")
      expect(hash[:agent_class]).to eq("Smolagents::Agents::ToolCalling")
      expect(hash[:model]).to be_a(Hash)
      expect(hash[:tools]).to be_an(Array)
      expect(hash[:max_steps]).to eq(15)
    end

    it "can be converted to JSON" do
      manifest = described_class.from_agent(agent)

      expect { JSON.generate(manifest.to_h) }.not_to raise_error
    end
  end

  describe ".from_h" do
    it "reconstructs from hash" do
      hash = {
        version: "1.0",
        agent_class: "Smolagents::Agents::ToolCalling",
        model: { class_name: "Smolagents::Model", model_id: "gpt-4", config: {} },
        tools: [{ name: "final_answer", class_name: "Smolagents::FinalAnswerTool", registry_key: "final_answer", config: {} }],
        managed_agents: {},
        max_steps: 10,
        planning_interval: nil,
        custom_instructions: "Test",
        metadata: { created_at: Time.now.iso8601 }
      }

      manifest = described_class.from_h(hash)

      expect(manifest.agent_class).to eq("Smolagents::Agents::ToolCalling")
      expect(manifest.max_steps).to eq(10)
      expect(manifest.custom_instructions).to eq("Test")
    end

    it "raises InvalidManifestError for missing required fields" do
      hash = { version: "1.0" }

      expect { described_class.from_h(hash) }.to raise_error(
        Smolagents::Persistence::InvalidManifestError,
        /missing agent_class.*missing model/
      )
    end

    it "raises VersionMismatchError for unsupported version" do
      hash = {
        version: "99.0",
        agent_class: "Smolagents::Agents::ToolCalling",
        model: { class_name: "Model", model_id: "gpt-4", config: {} }
      }

      expect { described_class.from_h(hash) }.to raise_error(
        Smolagents::Persistence::VersionMismatchError,
        /99.0 not supported/
      )
    end
  end

  describe "#instantiate" do
    it "raises MissingModelError when model not provided" do
      manifest = described_class.from_agent(agent)

      expect { manifest.instantiate }.to raise_error(
        Smolagents::Persistence::MissingModelError,
        /Model required/
      )
    end

    it "creates agent when model provided" do
      manifest = described_class.from_agent(agent)
      new_model = Smolagents::Model.new(model_id: "gpt-4-turbo")

      new_agent = manifest.instantiate(model: new_model)

      expect(new_agent).to be_a(Smolagents::Agents::ToolCalling)
      expect(new_agent.model).to eq(new_model)
      expect(new_agent.max_steps).to eq(15)
    end

    it "applies overrides" do
      manifest = described_class.from_agent(agent)
      new_model = Smolagents::Model.new(model_id: "gpt-4-turbo")

      new_agent = manifest.instantiate(model: new_model, max_steps: 30)

      expect(new_agent.max_steps).to eq(30)
    end
  end

  describe "round-trip serialization" do
    it "preserves manifest data through JSON" do
      original = described_class.from_agent(agent)
      json = JSON.generate(original.to_h)
      restored = described_class.from_h(JSON.parse(json))

      expect(restored.version).to eq(original.version)
      expect(restored.agent_class).to eq(original.agent_class)
      expect(restored.max_steps).to eq(original.max_steps)
      expect(restored.tools.length).to eq(original.tools.length)
    end
  end
end
