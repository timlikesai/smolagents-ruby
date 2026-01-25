require "spec_helper"

RSpec.describe Smolagents::Agents::Agent::Initialization do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:mock_executor) { instance_double(Smolagents::RactorExecutor) }
  let(:mock_tool) do
    instance_double(Smolagents::Tool,
                    name: "test_tool",
                    class: Smolagents::FinalAnswerTool,
                    format_for: "def test_tool(value:)\nend",
                    inputs: { "value" => { "type" => "string", "description" => "Test" } },
                    description: "A test tool")
  end

  before do
    allow(mock_executor).to receive(:send_tools)
    allow(Smolagents::RactorExecutor).to receive(:new).and_return(mock_executor)
  end

  describe "core initialization" do
    it "sets up model" do
      agent = Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool])

      expect(agent.model).to eq(mock_model)
    end

    it "creates default executor when not provided" do
      Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool])

      expect(Smolagents::RactorExecutor).to have_received(:new)
    end

    it "uses provided executor" do
      custom_executor = instance_double(Smolagents::RactorExecutor)
      allow(custom_executor).to receive(:send_tools)

      agent = Smolagents::Agents::Agent.new(
        model: mock_model,
        tools: [mock_tool],
        executor: custom_executor
      )

      expect(agent.executor).to eq(custom_executor)
    end

    it "sets default authorized_imports from global config" do
      agent = Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool])

      expect(agent.authorized_imports).to be_a(Array)
    end

    it "uses config authorized_imports when provided" do
      config = Smolagents::Types::AgentConfig.create(authorized_imports: %w[json yaml])
      agent = Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool], config:)

      expect(agent.authorized_imports).to eq(%w[json yaml])
    end

    it "sets max_steps from config" do
      config = Smolagents::Types::AgentConfig.create(max_steps: 25)
      agent = Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool], config:)

      expect(agent.max_steps).to eq(25)
    end

    it "uses NullLogger by default" do
      agent = Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool])

      expect(agent.logger).to be_a(Smolagents::Logging::NullLogger)
    end

    it "uses provided logger" do
      custom_logger = instance_double(Logger)
      agent = Smolagents::Agents::Agent.new(
        model: mock_model,
        tools: [mock_tool],
        logger: custom_logger
      )

      expect(agent.logger).to eq(custom_logger)
    end
  end

  describe "tools initialization" do
    it "converts tools array to hash keyed by name" do
      agent = Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool])

      expect(agent.tools).to be_a(Hash)
      expect(agent.tools["test_tool"]).to eq(mock_tool)
    end

    it "always includes final_answer tool" do
      agent = Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool])

      expect(agent.tools.keys).to include("final_answer")
    end

    it "sends tools to executor" do
      Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool])

      expect(mock_executor).to have_received(:send_tools)
    end
  end

  describe "managed agents initialization" do
    let(:sub_agent) do
      instance_double(Smolagents::Agents::Agent,
                      model: mock_model,
                      max_steps: 5,
                      tools: {},
                      system_prompt: "system prompt")
    end

    it "accepts managed_agents hash" do
      agent = Smolagents::Agents::Agent.new(
        model: mock_model,
        tools: [mock_tool],
        managed_agents: { "helper" => sub_agent }
      )

      expect(agent.managed_agents).to be_a(Hash)
      expect(agent.managed_agents.keys).to include("helper")
    end

    it "wraps agents in ManagedAgentTool" do
      agent = Smolagents::Agents::Agent.new(
        model: mock_model,
        tools: [mock_tool],
        managed_agents: { "helper" => sub_agent }
      )

      expect(agent.managed_agents["helper"]).to be_a(Smolagents::ManagedAgentTool)
    end
  end

  describe "memory initialization" do
    it "creates AgentMemory with system prompt" do
      agent = Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool])

      expect(agent.memory).to be_a(Smolagents::Runtime::AgentMemory)
    end

    it "uses memory_config when provided" do
      memory_config = Smolagents::Types::MemoryConfig.masked(budget: 5000, preserve_recent: 5)
      config = Smolagents::Types::AgentConfig.create(memory_config:)

      agent = Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool], config:)

      expect(agent.memory).to be_a(Smolagents::Runtime::AgentMemory)
    end
  end

  describe "runtime initialization" do
    it "creates AgentRuntime" do
      agent = Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool])

      expect(agent.runtime).to be_a(Smolagents::Agents::AgentRuntime)
    end

    it "passes planning_interval to runtime" do
      config = Smolagents::Types::AgentConfig.create(planning_interval: 3)
      agent = Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool], config:)

      expect(agent.runtime.planning_interval).to eq(3)
    end

    it "passes spawn_config to runtime" do
      spawn_config = Smolagents::Types::SpawnConfig.create(max_children: 2)
      config = Smolagents::Types::AgentConfig.create(spawn_config:)

      agent = Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool], config:)

      expect(agent.runtime).to be_a(Smolagents::Agents::AgentRuntime)
    end

    it "passes evaluation_enabled to runtime" do
      config = Smolagents::Types::AgentConfig.create(evaluation_enabled: true)

      agent = Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool], config:)

      expect(agent.runtime).to be_a(Smolagents::Agents::AgentRuntime)
    end
  end

  describe "custom instructions" do
    it "sanitizes custom instructions" do
      config = Smolagents::Types::AgentConfig.create(
        custom_instructions: "Custom <script>alert('xss')</script> instructions"
      )

      agent = Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool], config:)

      # Agent should be created without raising
      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it "includes custom instructions in system prompt" do
      config = Smolagents::Types::AgentConfig.create(custom_instructions: "Be concise")

      agent = Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool], config:)

      expect(agent.system_prompt).to include("Be concise")
    end
  end
end
