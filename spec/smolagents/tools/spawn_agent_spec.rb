RSpec.describe Smolagents::Tools::SpawnAgentTool do
  subject(:tool) do
    described_class.new(
      parent_model: model,
      spawn_config:
    )
  end

  let(:model) { Smolagents::Testing::MockModel.new }
  let(:spawn_config) do
    Smolagents::Types::SpawnConfig.create(
      allow: [],
      tools: %i[search web duckduckgo_search visit_webpage],
      inherit: :task_only,
      max_children: 3
    )
  end

  describe "#initialize" do
    it "creates tool with parent model and spawn config" do
      expect(tool.instance_variable_get(:@parent_model)).to eq(model)
      expect(tool.instance_variable_get(:@spawn_config)).to eq(spawn_config)
    end

    it "accepts inline tools" do
      inline = Smolagents::InlineTool.create(:custom, "Custom") { "result" }
      tool_with_inline = described_class.new(
        parent_model: model,
        spawn_config:,
        inline_tools: [inline]
      )
      expect(tool_with_inline.instance_variable_get(:@inline_tools)).to include(inline)
    end
  end

  describe "#execute", :integration do
    before do
      # The spawned agent needs responses queued
      model.queue_final_answer("Sub-agent completed the task")
    end

    it "creates and runs a sub-agent with the given persona" do
      result = tool.execute(task: "Research Ruby 4", persona: "researcher")

      expect(result).to include("researcher")
      expect(result).to include("Sub-agent completed the task")
    end

    it "works without extra tools" do
      result = tool.execute(task: "Analyze this", persona: "analyst")

      expect(result).to include("analyst")
    end

    it "accepts tools as array of strings" do
      result = tool.execute(task: "Search for info", persona: "researcher", tools: ["search"])

      expect(result).to include("researcher")
    end

    it "raises on unknown persona" do
      expect do
        tool.execute(task: "Do something", persona: "unknown_persona")
      end.to raise_error(Smolagents::SpawnError, /Unknown persona/)
    end

    it "raises when spawn is disabled" do
      disabled_config = Smolagents::Types::SpawnConfig.disabled
      disabled_tool = described_class.new(parent_model: model, spawn_config: disabled_config)

      expect do
        disabled_tool.execute(task: "Task", persona: "researcher")
      end.to raise_error(Smolagents::SpawnError, /disabled/)
    end

    it "raises when tool is not allowed" do
      restricted_config = Smolagents::Types::SpawnConfig.create(tools: [:final_answer])
      restricted_tool = described_class.new(parent_model: model, spawn_config: restricted_config)

      expect do
        restricted_tool.execute(task: "Task", persona: "researcher", tools: ["dangerous_tool"])
      end.to raise_error(Smolagents::SpawnError, /not allowed/)
    end

    it "allows toolkit names even if individual tools aren't listed" do
      # Toolkits get expanded, so :search should work even if only :search is in allowed
      toolkit_config = Smolagents::Types::SpawnConfig.create(tools: %i[search web])
      toolkit_tool = described_class.new(parent_model: model, spawn_config: toolkit_config)

      # This should not raise - :search is a toolkit
      result = toolkit_tool.execute(task: "Search", persona: "researcher", tools: ["search"])
      expect(result).to include("researcher")
    end
  end

  describe "tool metadata" do
    it "has correct name" do
      expect(tool.name).to eq("spawn_agent")
    end

    it "has description" do
      expect(tool.description).to include("sub-agent")
    end

    it "has inputs for task, persona, and tools" do
      expect(tool.inputs).to have_key(:task)
      expect(tool.inputs).to have_key(:persona)
      expect(tool.inputs).to have_key(:tools)
    end
  end
end

RSpec.describe Smolagents::Builders::AgentBuilder do
  let(:model) { Smolagents::Testing::MockModel.new }

  before do
    model.queue_final_answer("done")
  end

  it "adds spawn_agent tool when can_spawn is configured" do
    agent = Smolagents.agent
                      .model { model }
                      .can_spawn(allow: [:researcher], tools: [:search])
                      .build

    tool_names = agent.instance_variable_get(:@tools).keys
    expect(tool_names).to include("spawn_agent")
  end

  it "does not add spawn_agent when can_spawn is not configured" do
    agent = Smolagents.agent
                      .model { model }
                      .build

    tool_names = agent.instance_variable_get(:@tools).keys
    expect(tool_names).not_to include("spawn_agent")
  end

  it "passes inline tools to spawn tool" do
    agent = Smolagents.agent
                      .model { model }
                      .tool(:custom, "Custom tool") { "result" }
                      .can_spawn(allow: [:researcher], tools: [:search])
                      .build

    spawn_tool = agent.instance_variable_get(:@tools)["spawn_agent"]
    inline_tools = spawn_tool.instance_variable_get(:@inline_tools)

    expect(inline_tools.map(&:name)).to include("custom")
  end
end
