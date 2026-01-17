RSpec.describe Smolagents::Builders::AgentBuilder do
  let(:mock_model) { instance_double(Smolagents::OpenAIModel) }

  let(:search_tool) do
    Smolagents::Tools.define_tool(
      "test_search",
      description: "Search for something",
      inputs: { "query" => { type: "string", description: "Query" } },
      output_type: "string"
    ) { |query:| "Results for #{query}" }
  end

  before do
    allow(Smolagents::Tools).to receive(:get).with("google_search").and_return(search_tool)
    allow(Smolagents::Tools).to receive(:get).with("visit_webpage").and_return(search_tool)
    allow(Smolagents::Tools).to receive(:get).with("unknown_tool").and_return(nil)
    allow(Smolagents::Tools).to receive(:names).and_return(%w[google_search visit_webpage])
  end

  describe "#initialize" do
    it "creates a builder with default configuration" do
      builder = described_class.create

      expect(builder).to be_a(described_class)
      expect(builder.configuration).to be_a(Hash)
    end

    it "has immutable configuration by default" do
      builder1 = described_class.create
      builder2 = builder1.tools(:google_search)

      expect(builder1).not_to eq(builder2)
      expect(builder1.configuration[:tool_names]).to be_empty
      expect(builder2.configuration[:tool_names]).to include(:google_search)
    end
  end

  describe "#model" do
    it "stores the model block" do
      builder = described_class.create.model { mock_model }

      expect(builder.config[:model_block]).to be_a(Proc)
    end

    it "is immutable - returns new builder" do
      builder1 = described_class.create
      builder2 = builder1.model { mock_model }

      expect(builder1.config[:model_block]).to be_nil
      expect(builder2.config[:model_block]).not_to be_nil
    end

    context "with symbol" do
      before do
        Smolagents.configure do |c|
          c.models do |m|
            m = m.register(:test_model, -> { mock_model })
            m
          end
        end
      end

      after { Smolagents.reset_configuration! }

      it "references registered model" do
        builder = described_class.create.model(:test_model)
        expect(builder.config[:model_block]).to be_a(Proc)
      end

      it "defers model lookup to build time" do
        builder = described_class.create.model(:test_model)
        # The block is created but not yet called
        expect(builder.config[:model_block].call).to eq(mock_model)
      end
    end
  end

  describe "#tools" do
    it "adds tools by name" do
      builder = described_class.create.tools(:google_search, :visit_webpage)

      expect(builder.config[:tool_names]).to eq(%i[google_search visit_webpage])
    end

    it "adds tool instances" do
      builder = described_class.create.tools(search_tool)

      expect(builder.config[:tool_instances]).to eq([search_tool])
    end

    it "handles mixed names and instances" do
      builder = described_class.create.tools(:google_search, search_tool)

      expect(builder.config[:tool_names]).to eq([:google_search])
      expect(builder.config[:tool_instances]).to eq([search_tool])
    end

    it "accumulates tools across multiple calls" do
      builder = described_class.create
                               .tools(:google_search)
                               .tools(:visit_webpage)

      expect(builder.config[:tool_names]).to eq(%i[google_search visit_webpage])
    end
  end

  describe "#planning" do
    context "with no arguments (default)" do
      it "enables planning with default interval (3)" do
        builder = described_class.create.planning

        expect(builder.config[:planning_interval]).to eq(Smolagents::Config::DEFAULT_PLANNING_INTERVAL)
        expect(builder.config[:planning_interval]).to eq(3)
      end
    end

    context "with integer argument" do
      it "sets planning interval directly" do
        builder = described_class.create.planning(5)

        expect(builder.config[:planning_interval]).to eq(5)
      end
    end

    context "with boolean arguments" do
      it "enables planning with true" do
        builder = described_class.create.planning(true)

        expect(builder.config[:planning_interval]).to eq(3)
      end

      it "disables planning with false" do
        builder = described_class.create.planning(false)

        expect(builder.config[:planning_interval]).to be_nil
      end
    end

    context "with symbol arguments" do
      it "enables planning with :enabled" do
        builder = described_class.create.planning(:enabled)

        expect(builder.config[:planning_interval]).to eq(3)
      end

      it "enables planning with :on" do
        builder = described_class.create.planning(:on)

        expect(builder.config[:planning_interval]).to eq(3)
      end

      it "disables planning with :disabled" do
        builder = described_class.create.planning(:disabled)

        expect(builder.config[:planning_interval]).to be_nil
      end

      it "disables planning with :off" do
        builder = described_class.create.planning(:off)

        expect(builder.config[:planning_interval]).to be_nil
      end
    end

    context "with named parameters" do
      it "sets planning interval with interval:" do
        builder = described_class.create.planning(interval: 7)

        expect(builder.config[:planning_interval]).to eq(7)
      end

      it "sets planning templates" do
        templates = { initial_plan: "Custom template" }
        builder = described_class.create.planning(templates:)

        expect(builder.config[:planning_templates]).to eq(templates)
      end

      it "can set both interval and templates" do
        templates = { initial_plan: "Custom" }
        builder = described_class.create.planning(interval: 5, templates:)

        expect(builder.config[:planning_interval]).to eq(5)
        expect(builder.config[:planning_templates]).to eq(templates)
      end

      it "named interval takes precedence over positional" do
        builder = described_class.create.planning(10, interval: 7)

        expect(builder.config[:planning_interval]).to eq(7)
      end
    end

    context "with invalid arguments" do
      it "raises ArgumentError for invalid symbol" do
        expect { described_class.create.planning(:invalid) }
          .to raise_error(ArgumentError, /Invalid planning argument/)
      end

      it "raises ArgumentError for invalid type" do
        expect { described_class.create.planning("string") }
          .to raise_error(ArgumentError, /Invalid planning argument/)
      end
    end
  end

  describe "#can_spawn" do
    it "uses defaults with no arguments" do
      builder = described_class.create.can_spawn

      spawn_config = builder.config[:spawn_config]
      expect(spawn_config).to be_a(Smolagents::Types::SpawnConfig)
      expect(spawn_config.allowed_models).to eq([])
      expect(spawn_config.allowed_tools).to eq([:final_answer])
      expect(spawn_config.max_children).to eq(3)
      expect(spawn_config.inherit_scope.task_only?).to be true
    end

    it "restricts models with allow:" do
      builder = described_class.create.can_spawn(allow: %i[researcher fast])

      spawn_config = builder.config[:spawn_config]
      expect(spawn_config.allowed_models).to eq(%i[researcher fast])
      expect(spawn_config.model_allowed?(:researcher)).to be true
      expect(spawn_config.model_allowed?(:slow)).to be false
    end

    it "restricts tools with tools:" do
      builder = described_class.create.can_spawn(tools: %i[search final_answer])

      spawn_config = builder.config[:spawn_config]
      expect(spawn_config.allowed_tools).to eq(%i[search final_answer])
      expect(spawn_config.tool_allowed?(:search)).to be true
      expect(spawn_config.tool_allowed?(:web)).to be false
    end

    it "sets inherit scope with inherit:" do
      builder = described_class.create.can_spawn(inherit: :observations)

      spawn_config = builder.config[:spawn_config]
      expect(spawn_config.inherit_scope.observations?).to be true
    end

    it "sets max_children" do
      builder = described_class.create.can_spawn(max_children: 10)

      expect(builder.config[:spawn_config].max_children).to eq(10)
    end

    it "is immutable - returns new builder" do
      builder1 = described_class.create
      builder2 = builder1.can_spawn(max_children: 5)

      expect(builder1.config[:spawn_config]).to be_nil
      expect(builder2.config[:spawn_config].max_children).to eq(5)
    end
  end

  describe "#memory" do
    it "uses default config with no arguments" do
      builder = described_class.create.memory

      expect(builder.config[:memory_config]).to be_a(Smolagents::Types::MemoryConfig)
      expect(builder.config[:memory_config].full?).to be true
    end

    it "sets budget with mask strategy" do
      builder = described_class.create.memory(budget: 100_000)

      expect(builder.config[:memory_config].budget).to eq(100_000)
      expect(builder.config[:memory_config].mask?).to be true
    end

    it "allows full configuration" do
      builder = described_class.create.memory(budget: 50_000, strategy: :hybrid, preserve_recent: 3)
      config = builder.config[:memory_config]

      expect(config.budget).to eq(50_000)
      expect(config.hybrid?).to be true
      expect(config.preserve_recent).to eq(3)
    end

    it "preserves mask_placeholder default" do
      builder = described_class.create.memory(budget: 10_000)

      expect(builder.config[:memory_config].mask_placeholder).to eq("[Previous observation truncated]")
    end
  end

  describe "#max_steps" do
    it "sets max_steps" do
      builder = described_class.create.max_steps(15)

      expect(builder.config[:max_steps]).to eq(15)
    end
  end

  describe "#evaluation" do
    it "enables evaluation by default" do
      builder = described_class.create.evaluation

      expect(builder.config[:evaluation_enabled]).to be(true)
    end

    it "enables evaluation explicitly" do
      builder = described_class.create.evaluation(enabled: true)

      expect(builder.config[:evaluation_enabled]).to be(true)
    end

    it "disables evaluation when requested" do
      builder = described_class.create.evaluation(enabled: false)

      expect(builder.config[:evaluation_enabled]).to be(false)
    end
  end

  describe "#instructions" do
    it "sets custom instructions" do
      builder = described_class.create.instructions("Be concise")

      expect(builder.config[:custom_instructions]).to eq("Be concise")
    end
  end

  describe "#executor" do
    it "sets executor for code agents" do
      executor = instance_double(Smolagents::LocalRubyExecutor)
      builder = described_class.create.executor(executor)

      expect(builder.config[:executor]).to eq(executor)
    end
  end

  describe "#authorized_imports" do
    it "sets authorized imports" do
      builder = described_class.create.authorized_imports("HTTP", "JSON")

      expect(builder.config[:authorized_imports]).to eq(%w[HTTP JSON])
    end
  end

  describe "#on" do
    it "adds a handler" do
      handler = proc { |_event| :handled }
      builder = described_class.create.on(:step_complete, &handler)

      expect(builder.config[:handlers].size).to eq(1)
      expect(builder.config[:handlers].first[0]).to eq(:step_complete)
    end

    it "accumulates handlers" do
      builder = described_class.create
                               .on(:step_complete) { |_| :step }
                               .on(:task_complete) { |_| :task }

      expect(builder.config[:handlers].size).to eq(2)
    end
  end

  describe "#managed_agent" do
    it "adds a managed agent by instance" do
      sub_agent = instance_double(Smolagents::Agents::Agent)
      builder = described_class.create.managed_agent(sub_agent, as: "researcher")

      expect(builder.config[:managed_agents]["researcher"]).to eq(sub_agent)
    end

    it "builds agent from builder" do
      allow(mock_model).to receive(:is_a?).and_return(true)

      sub_builder = described_class.create.model { mock_model }.tools(search_tool)
      builder = described_class.create.managed_agent(sub_builder, as: "helper")

      # The managed agent should be built (not a builder)
      expect(builder.config[:managed_agents]["helper"]).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "#run" do
    let(:mock_result) { instance_double(Smolagents::Types::RunResult, output: "42") }

    it "builds and runs in one step" do
      mock_agent = instance_double(Smolagents::Agents::Agent)
      allow(Smolagents::Agents::Agent).to receive(:new).and_return(mock_agent)
      allow(mock_agent).to receive(:on)
      allow(mock_agent).to receive(:run).with("What is 2 + 2?").and_return(mock_result)

      result = described_class.create
                              .model { mock_model }
                              .tools(search_tool)
                              .run("What is 2 + 2?")

      expect(result).to eq(mock_result)
    end

    it "passes kwargs to agent.run" do
      mock_agent = instance_double(Smolagents::Agents::Agent)
      allow(Smolagents::Agents::Agent).to receive(:new).and_return(mock_agent)
      allow(mock_agent).to receive(:on)
      allow(mock_agent).to receive(:run).with("Hello", reset: false, stream: false).and_return(mock_result)

      result = described_class.create
                              .model { mock_model }
                              .tools(search_tool)
                              .run("Hello", reset: false, stream: false)

      expect(result).to eq(mock_result)
    end
  end

  describe "#run_fiber" do
    let(:mock_fiber) { Fiber.new { "result" } }

    it "builds and returns a fiber" do
      mock_agent = instance_double(Smolagents::Agents::Agent)
      allow(Smolagents::Agents::Agent).to receive(:new).and_return(mock_agent)
      allow(mock_agent).to receive(:on)
      allow(mock_agent).to receive(:run_fiber).with("Find Ruby features").and_return(mock_fiber)

      fiber = described_class.create
                             .model { mock_model }
                             .tools(search_tool)
                             .run_fiber("Find Ruby features")

      expect(fiber).to eq(mock_fiber)
    end

    it "passes kwargs to agent.run_fiber" do
      mock_agent = instance_double(Smolagents::Agents::Agent)
      allow(Smolagents::Agents::Agent).to receive(:new).and_return(mock_agent)
      allow(mock_agent).to receive(:on)
      allow(mock_agent).to receive(:run_fiber).with("Hello", reset: false).and_return(mock_fiber)

      fiber = described_class.create
                             .model { mock_model }
                             .tools(search_tool)
                             .run_fiber("Hello", reset: false)

      expect(fiber).to eq(mock_fiber)
    end
  end

  describe "#build" do
    it "creates an agent that writes Ruby code" do
      agent = described_class.create
                             .model { mock_model }
                             .tools(search_tool)
                             .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent).to respond_to(:run)
    end

    it "raises error without model" do
      builder = described_class.create.tools(search_tool)

      expect { builder.build }.to raise_error(ArgumentError, /Model required/)
    end

    it "raises error for unknown tool name" do
      builder = described_class.create
                               .model { mock_model }
                               .tools(:unknown_tool)

      expect { builder.build }.to raise_error(ArgumentError, /Unknown tool: unknown_tool/)
    end

    it "resolves tools from registry" do
      agent = described_class.create
                             .model { mock_model }
                             .tools(:google_search)
                             .build

      expect(agent.tools.values.first).to eq(search_tool)
    end

    it "registers handlers on built agent" do
      handler_called = false
      agent = described_class.create
                             .model { mock_model }
                             .tools(search_tool)
                             .on(:step_complete) { handler_called = true }
                             .build

      # Create and consume a step event to verify handler was registered
      event = Smolagents::Events::StepCompleted.create(step_number: 1, outcome: :success)
      agent.consume(event)

      expect(handler_called).to be true
    end

    it "passes max_steps to agent" do
      agent = described_class.create
                             .model { mock_model }
                             .tools(search_tool)
                             .max_steps(20)
                             .build

      expect(agent.max_steps).to eq(20)
    end

    it "passes planning config to agent" do
      agent = described_class.create
                             .model { mock_model }
                             .tools(search_tool)
                             .planning(interval: 5)
                             .build

      expect(agent.planning_interval).to eq(5)
    end
  end

  describe "#inspect" do
    it "shows builder state" do
      builder = described_class.create
                               .tools(:google_search, search_tool)
                               .on(:step_complete) { |_| :ok }

      inspect_str = builder.inspect

      expect(inspect_str).to include("AgentBuilder")
      expect(inspect_str).to include("google_search")
      expect(inspect_str).to include("handlers=1")
    end
  end

  describe "chaining" do
    it "supports full configuration chain" do
      agent = described_class.create
                             .model { mock_model }
                             .tools(:google_search)
                             .tools(search_tool)
                             .max_steps(10)
                             .planning(interval: 3)
                             .instructions("Be helpful")
                             .on(:after_step) { |s| s }
                             .on(:after_task) { |r| r }
                             .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent.max_steps).to eq(10)
      expect(agent.planning_interval).to eq(3)
    end
  end
end

RSpec.describe Smolagents do
  describe ".agent" do
    it "returns an AgentBuilder" do
      builder = described_class.agent

      expect(builder).to be_a(Smolagents::Builders::AgentBuilder)
    end

    it "can use .with(:code) which is now ignored (all agents write code)" do
      builder = described_class.agent.with(:code)

      expect(builder).to be_a(Smolagents::Builders::AgentBuilder)
      # .with(:code) is accepted but ignored since all agents write code now
    end

    it "can be chained to build an agent" do
      mock_model = instance_double(Smolagents::OpenAIModel)
      search_tool = Smolagents::Tools.define_tool(
        "search",
        description: "Search",
        inputs: { "q" => { type: "string", description: "Query" } },
        output_type: "string"
      ) { |q:| q }

      agent = described_class.agent
                             .with(:code)
                             .model { mock_model }
                             .tools(search_tool)
                             .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end
end
