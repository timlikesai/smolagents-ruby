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
    it "creates a builder with the given type" do
      builder = described_class.new(:code)

      expect(builder.agent_type).to eq(:code)
    end

    it "accepts string type and converts to symbol" do
      builder = described_class.new("tool_calling")

      expect(builder.agent_type).to eq(:tool_calling)
    end
  end

  describe "#model" do
    it "stores the model block" do
      builder = described_class.new(:code).model { mock_model }

      expect(builder.config[:model_block]).to be_a(Proc)
    end

    it "is immutable - returns new builder" do
      builder1 = described_class.new(:code)
      builder2 = builder1.model { mock_model }

      expect(builder1.config[:model_block]).to be_nil
      expect(builder2.config[:model_block]).not_to be_nil
    end
  end

  describe "#tools" do
    it "adds tools by name" do
      builder = described_class.new(:code).tools(:google_search, :visit_webpage)

      expect(builder.config[:tool_names]).to eq(%i[google_search visit_webpage])
    end

    it "adds tool instances" do
      builder = described_class.new(:code).tools(search_tool)

      expect(builder.config[:tool_instances]).to eq([search_tool])
    end

    it "handles mixed names and instances" do
      builder = described_class.new(:code).tools(:google_search, search_tool)

      expect(builder.config[:tool_names]).to eq([:google_search])
      expect(builder.config[:tool_instances]).to eq([search_tool])
    end

    it "accumulates tools across multiple calls" do
      builder = described_class.new(:code)
                               .tools(:google_search)
                               .tools(:visit_webpage)

      expect(builder.config[:tool_names]).to eq(%i[google_search visit_webpage])
    end
  end

  describe "#planning" do
    it "sets planning interval" do
      builder = described_class.new(:code).planning(interval: 3)

      expect(builder.config[:planning_interval]).to eq(3)
    end

    it "sets planning templates" do
      templates = { initial_plan: "Custom template" }
      builder = described_class.new(:code).planning(templates: templates)

      expect(builder.config[:planning_templates]).to eq(templates)
    end

    it "can set both" do
      templates = { initial_plan: "Custom" }
      builder = described_class.new(:code).planning(interval: 5, templates: templates)

      expect(builder.config[:planning_interval]).to eq(5)
      expect(builder.config[:planning_templates]).to eq(templates)
    end
  end

  describe "#max_steps" do
    it "sets max_steps" do
      builder = described_class.new(:code).max_steps(15)

      expect(builder.config[:max_steps]).to eq(15)
    end
  end

  describe "#instructions" do
    it "sets custom instructions" do
      builder = described_class.new(:code).instructions("Be concise")

      expect(builder.config[:custom_instructions]).to eq("Be concise")
    end
  end

  describe "#executor" do
    it "sets executor for code agents" do
      executor = instance_double(Smolagents::LocalRubyExecutor)
      builder = described_class.new(:code).executor(executor)

      expect(builder.config[:executor]).to eq(executor)
    end
  end

  describe "#authorized_imports" do
    it "sets authorized imports" do
      builder = described_class.new(:code).authorized_imports("HTTP", "JSON")

      expect(builder.config[:authorized_imports]).to eq(%w[HTTP JSON])
    end
  end

  describe "#on" do
    it "adds a callback" do
      callback = proc { |step| puts step }
      builder = described_class.new(:code).on(:step_complete, &callback)

      expect(builder.config[:callbacks].size).to eq(1)
      expect(builder.config[:callbacks].first[0]).to eq(:step_complete)
    end

    it "accumulates callbacks" do
      builder = described_class.new(:code)
                               .on(:step_complete) { |s| puts s }
                               .on(:task_complete) { |r| log(r) }

      expect(builder.config[:callbacks].size).to eq(2)
    end
  end

  describe "#managed_agent" do
    it "adds a managed agent by instance" do
      sub_agent = instance_double(Smolagents::Agents::Code)
      builder = described_class.new(:code).managed_agent(sub_agent, as: "researcher")

      expect(builder.config[:managed_agents]["researcher"]).to eq(sub_agent)
    end

    it "builds agent from builder" do
      allow(mock_model).to receive(:is_a?).and_return(true)

      sub_builder = described_class.new(:code).model { mock_model }.tools(search_tool)
      builder = described_class.new(:code).managed_agent(sub_builder, as: "helper")

      # The managed agent should be built (not a builder)
      expect(builder.config[:managed_agents]["helper"]).to be_a(Smolagents::Agents::Code)
    end
  end

  describe "#build" do
    it "creates a code agent" do
      agent = described_class.new(:code)
                             .model { mock_model }
                             .tools(search_tool)
                             .build

      expect(agent).to be_a(Smolagents::Agents::Code)
    end

    it "creates a tool_calling agent" do
      agent = described_class.new(:tool_calling)
                             .model { mock_model }
                             .tools(search_tool)
                             .build

      expect(agent).to be_a(Smolagents::Agents::ToolCalling)
    end

    it "raises error without model" do
      builder = described_class.new(:code).tools(search_tool)

      expect { builder.build }.to raise_error(ArgumentError, /Model required/)
    end

    it "raises error for unknown agent type" do
      builder = described_class.new(:unknown).model { mock_model }

      expect { builder.build }.to raise_error(ArgumentError, /Unknown agent type/)
    end

    it "raises error for unknown tool name" do
      builder = described_class.new(:code)
                               .model { mock_model }
                               .tools(:unknown_tool)

      expect { builder.build }.to raise_error(ArgumentError, /Unknown tool: unknown_tool/)
    end

    it "resolves tools from registry" do
      agent = described_class.new(:code)
                             .model { mock_model }
                             .tools(:google_search)
                             .build

      expect(agent.tools.values.first).to eq(search_tool)
    end

    it "registers callbacks on built agent" do
      callback_called = false
      agent = described_class.new(:code)
                             .model { mock_model }
                             .tools(search_tool)
                             .on(:step_complete) { callback_called = true }
                             .build

      # Trigger the callback manually to verify it was registered
      agent.send(:trigger_callbacks, :step_complete)

      expect(callback_called).to be true
    end

    it "passes max_steps to agent" do
      agent = described_class.new(:code)
                             .model { mock_model }
                             .tools(search_tool)
                             .max_steps(20)
                             .build

      expect(agent.max_steps).to eq(20)
    end

    it "passes planning config to agent" do
      agent = described_class.new(:code)
                             .model { mock_model }
                             .tools(search_tool)
                             .planning(interval: 5)
                             .build

      expect(agent.planning_interval).to eq(5)
    end
  end

  describe "#inspect" do
    it "shows builder state" do
      builder = described_class.new(:code)
                               .tools(:google_search, search_tool)
                               .on(:step_complete) {}

      inspect_str = builder.inspect

      expect(inspect_str).to include("AgentBuilder")
      expect(inspect_str).to include("type=code")
      expect(inspect_str).to include("google_search")
      expect(inspect_str).to include("callbacks=1")
    end
  end

  describe "chaining" do
    it "supports full configuration chain" do
      agent = described_class.new(:code)
                             .model { mock_model }
                             .tools(:google_search)
                             .tools(search_tool)
                             .max_steps(10)
                             .planning(interval: 3)
                             .instructions("Be helpful")
                             .on(:step_complete) { |s| s }
                             .on(:task_complete) { |r| r }
                             .build

      expect(agent).to be_a(Smolagents::Agents::Code)
      expect(agent.max_steps).to eq(10)
      expect(agent.planning_interval).to eq(3)
    end
  end
end

RSpec.describe Smolagents do
  describe ".agent" do
    it "returns an AgentBuilder" do
      builder = described_class.agent(:code)

      expect(builder).to be_a(Smolagents::Builders::AgentBuilder)
      expect(builder.agent_type).to eq(:code)
    end

    it "can be chained to build an agent" do
      mock_model = instance_double(Smolagents::OpenAIModel)
      search_tool = Smolagents::Tools.define_tool(
        "search",
        description: "Search",
        inputs: { "q" => { type: "string", description: "Query" } },
        output_type: "string"
      ) { |q:| q }

      agent = described_class.agent(:code)
                             .model { mock_model }
                             .tools(search_tool)
                             .build

      expect(agent).to be_a(Smolagents::Agents::Code)
    end
  end
end
