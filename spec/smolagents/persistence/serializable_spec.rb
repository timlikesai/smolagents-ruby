require "tmpdir"
require "fileutils"

RSpec.describe Smolagents::Persistence::Serializable do
  let(:tmpdir) { Dir.mktmpdir }
  let(:mock_model) do
    model = Smolagents::Model.new(model_id: "gpt-4")
    model.instance_variable_set(:@temperature, 0.7)
    model
  end
  let(:agent) do
    config = Smolagents::Types::AgentConfig.create(max_steps: 15)
    Smolagents::Agents::Agent.new(
      model: mock_model,
      tools: [Smolagents::FinalAnswerTool.new],
      config:
    )
  end

  after { FileUtils.rm_rf(tmpdir) }

  describe "#save" do
    it "saves agent to directory" do
      agent.save(tmpdir)

      expect(File.exist?(File.join(tmpdir, "agent.json"))).to be true
    end

    it "accepts metadata" do
      agent.save(tmpdir, metadata: { version: "1.0.0" })

      json = JSON.parse(File.read(File.join(tmpdir, "agent.json")))
      expect(json["metadata"]["version"]).to eq("1.0.0")
    end
  end

  describe "#to_manifest" do
    it "returns AgentManifest" do
      manifest = agent.to_manifest

      expect(manifest).to be_a(Smolagents::Persistence::AgentManifest)
      expect(manifest.agent_class).to eq("Smolagents::Agents::Agent")
    end

    it "accepts metadata" do
      manifest = agent.to_manifest(metadata: { author: "Tim" })

      expect(manifest.metadata[:author]).to eq("Tim")
    end
  end

  describe ".from_folder" do
    before { agent.save(tmpdir) }

    it "loads agent from directory" do
      new_model = Smolagents::Model.new(model_id: "gpt-4-turbo")

      loaded = Smolagents::Agents::Agent.from_folder(tmpdir, model: new_model)

      expect(loaded).to be_a(Smolagents::Agents::Agent)
      expect(loaded.max_steps).to eq(15)
    end

    it "works with base Agent class" do
      new_model = Smolagents::Model.new(model_id: "gpt-4")

      loaded = Smolagents::Agents::Agent.from_folder(tmpdir, model: new_model)

      expect(loaded).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe ".from_manifest" do
    it "creates agent from manifest" do
      manifest = agent.to_manifest
      new_model = Smolagents::Model.new(model_id: "gpt-4-turbo")

      loaded = Smolagents::Agents::Agent.from_manifest(manifest, model: new_model)

      expect(loaded).to be_a(Smolagents::Agents::Agent)
      expect(loaded.model).to eq(new_model)
    end
  end

  describe "full round-trip" do
    it "preserves agent configuration through save and load" do
      agent_path = File.join(tmpdir, "my_agent")

      agent.save(agent_path)
      new_model = Smolagents::Model.new(model_id: "gpt-4")
      loaded = Smolagents::Agents::Agent.from_folder(agent_path, model: new_model)

      expect(loaded.class).to eq(agent.class)
      expect(loaded.max_steps).to eq(agent.max_steps)
      expect(loaded.tools.keys).to eq(agent.tools.keys)
    end
  end
end
