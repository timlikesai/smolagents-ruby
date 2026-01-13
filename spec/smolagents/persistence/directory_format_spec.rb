require "tmpdir"
require "fileutils"

RSpec.describe Smolagents::Persistence::DirectoryFormat do
  let(:tmpdir) { Dir.mktmpdir }
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

  after { FileUtils.rm_rf(tmpdir) }

  describe ".save" do
    it "creates agent.json" do
      described_class.save(agent, tmpdir)

      expect(File.exist?(File.join(tmpdir, "agent.json"))).to be true
    end

    it "creates tools directory with tool manifests" do
      described_class.save(agent, tmpdir)

      tools_dir = File.join(tmpdir, "tools")
      expect(File.directory?(tools_dir)).to be true
      expect(File.exist?(File.join(tools_dir, "final_answer.json"))).to be true
    end

    it "writes valid JSON" do
      described_class.save(agent, tmpdir)

      json = File.read(File.join(tmpdir, "agent.json"))
      parsed = JSON.parse(json)

      expect(parsed["version"]).to eq("1.0")
      expect(parsed["agent_class"]).to eq("Smolagents::Agents::ToolCalling")
      expect(parsed["max_steps"]).to eq(15)
    end

    it "returns the path" do
      result = described_class.save(agent, tmpdir)

      expect(result).to eq(Pathname(tmpdir))
    end

    it "accepts custom metadata" do
      described_class.save(agent, tmpdir, metadata: { author: "Tim" })

      json = JSON.parse(File.read(File.join(tmpdir, "agent.json")))
      expect(json["metadata"]["author"]).to eq("Tim")
    end
  end

  describe ".load" do
    before { described_class.save(agent, tmpdir) }

    it "requires model argument" do
      expect { described_class.load(tmpdir) }.to raise_error(
        Smolagents::Persistence::MissingModelError
      )
    end

    it "reconstructs agent with model" do
      new_model = Smolagents::Model.new(model_id: "gpt-4-turbo")

      loaded = described_class.load(tmpdir, model: new_model)

      expect(loaded).to be_a(Smolagents::Agents::ToolCalling)
      expect(loaded.model).to eq(new_model)
    end

    it "restores configuration" do
      new_model = Smolagents::Model.new(model_id: "gpt-4")

      loaded = described_class.load(tmpdir, model: new_model)

      expect(loaded.max_steps).to eq(15)
    end

    it "restores tools" do
      new_model = Smolagents::Model.new(model_id: "gpt-4")

      loaded = described_class.load(tmpdir, model: new_model)

      expect(loaded.tools.keys).to include("final_answer")
      expect(loaded.tools["final_answer"]).to be_a(Smolagents::FinalAnswerTool)
    end

    it "applies overrides" do
      new_model = Smolagents::Model.new(model_id: "gpt-4")

      loaded = described_class.load(tmpdir, model: new_model, max_steps: 30)

      expect(loaded.max_steps).to eq(30)
    end

    it "raises error for non-existent directory" do
      expect { described_class.load("/nonexistent/path", model: mock_model) }.to raise_error(Errno::ENOENT)
    end

    it "raises error for missing agent.json" do
      empty_dir = File.join(tmpdir, "empty")
      FileUtils.mkdir_p(empty_dir)

      expect { described_class.load(empty_dir, model: mock_model) }.to raise_error(
        Errno::ENOENT,
        /agent.json/
      )
    end
  end

  describe "round-trip with multiple tools" do
    let(:tools) do
      [
        Smolagents::FinalAnswerTool.new,
        Smolagents::DuckDuckGoSearchTool.new
      ]
    end

    it "preserves all tools" do
      described_class.save(agent, tmpdir)
      new_model = Smolagents::Model.new(model_id: "gpt-4")

      loaded = described_class.load(tmpdir, model: new_model)

      expect(loaded.tools.keys).to contain_exactly("final_answer", "duckduckgo_search")
    end
  end

  describe "Code agent support" do
    let(:code_agent) do
      Smolagents::Agents::Code.new(
        model: mock_model,
        tools: [Smolagents::FinalAnswerTool.new],
        max_steps: 20
      )
    end

    it "saves and loads Code agents" do
      described_class.save(code_agent, tmpdir)
      new_model = Smolagents::Model.new(model_id: "gpt-4")

      loaded = described_class.load(tmpdir, model: new_model)

      expect(loaded).to be_a(Smolagents::Agents::Code)
      expect(loaded.max_steps).to eq(20)
    end
  end
end
