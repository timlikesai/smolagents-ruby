RSpec.describe Smolagents::Builders::TeamBuilder do
  let(:mock_model) { instance_double(Smolagents::OpenAIModel) }
  let(:mock_tools) { { "search" => double("tool") } }

  let(:researcher_agent) do
    instance_double(Smolagents::Agents::Code, model: mock_model, tools: mock_tools)
  end

  let(:writer_agent) do
    instance_double(Smolagents::Agents::Code, model: mock_model, tools: mock_tools)
  end

  let(:search_tool) do
    Smolagents::Tools.define_tool(
      "search",
      description: "Search",
      inputs: { "q" => { type: "string", description: "Query" } },
      output_type: "string"
    ) { |q:| q }
  end

  describe "#initialize" do
    it "creates an empty team builder" do
      builder = described_class.new

      expect(builder.config[:agents]).to eq({})
    end
  end

  describe "#model" do
    it "stores the model block" do
      builder = described_class.new.model { mock_model }

      expect(builder.config[:model_block]).to be_a(Proc)
    end

    it "is immutable" do
      builder1 = described_class.new
      builder2 = builder1.model { mock_model }

      expect(builder1.config[:model_block]).to be_nil
      expect(builder2.config[:model_block]).not_to be_nil
    end
  end

  describe "#agent" do
    it "adds an agent by instance" do
      builder = described_class.new.agent(researcher_agent, as: "researcher")

      expect(builder.config[:agents]["researcher"]).to eq(researcher_agent)
    end

    it "adds an agent with symbol name" do
      builder = described_class.new.agent(researcher_agent, as: :researcher)

      expect(builder.config[:agents]["researcher"]).to eq(researcher_agent)
    end

    it "accumulates multiple agents" do
      builder = described_class.new
                               .agent(researcher_agent, as: "researcher")
                               .agent(writer_agent, as: "writer")

      expect(builder.config[:agents].keys).to eq(%w[researcher writer])
    end

    it "builds agent from AgentBuilder" do
      agent_builder = Smolagents::Builders::AgentBuilder.new(:code)
                                                        .model { mock_model }
                                                        .tools(search_tool)

      builder = described_class.new.agent(agent_builder, as: "helper")

      expect(builder.config[:agents]["helper"]).to be_a(Smolagents::Agents::Code)
    end

    it "injects shared model into AgentBuilder without model" do
      agent_builder = Smolagents::Builders::AgentBuilder.new(:code).tools(search_tool)

      builder = described_class.new
                               .model { mock_model }
                               .agent(agent_builder, as: "helper")

      expect(builder.config[:agents]["helper"]).to be_a(Smolagents::Agents::Code)
    end
  end

  describe "#coordinate" do
    it "sets coordination instructions" do
      builder = described_class.new.coordinate("Research then write")

      expect(builder.config[:coordinator_instructions]).to eq("Research then write")
    end
  end

  describe "#coordinator" do
    it "sets coordinator type" do
      builder = described_class.new.coordinator(:tool_calling)

      expect(builder.config[:coordinator_type]).to eq(:tool_calling)
    end
  end

  describe "#max_steps" do
    it "sets max_steps for coordinator" do
      builder = described_class.new.max_steps(20)

      expect(builder.config[:max_steps]).to eq(20)
    end
  end

  describe "#planning" do
    it "sets planning interval" do
      builder = described_class.new.planning(interval: 5)

      expect(builder.config[:planning_interval]).to eq(5)
    end
  end

  describe "#on" do
    it "adds callbacks" do
      builder = described_class.new.on(:after_step) { |s| s }

      expect(builder.config[:callbacks].size).to eq(1)
    end
  end

  describe "#build" do
    it "creates a coordinator agent with managed agents" do
      team = described_class.new
                            .model { mock_model }
                            .agent(researcher_agent, as: "researcher")
                            .agent(writer_agent, as: "writer")
                            .coordinate("Coordinate the team")
                            .build

      expect(team).to be_a(Smolagents::Agents::Code)
      expect(team.managed_agents.keys).to contain_exactly("researcher", "writer")
    end

    it "raises error without agents" do
      builder = described_class.new.model { mock_model }

      expect { builder.build }.to raise_error(ArgumentError, /At least one agent required/)
    end

    it "uses first agent's model if no model specified" do
      team = described_class.new
                            .agent(researcher_agent, as: "researcher")
                            .build

      expect(team.model).to eq(mock_model)
    end

    it "uses tool_calling coordinator when specified" do
      team = described_class.new
                            .model { mock_model }
                            .agent(researcher_agent, as: "researcher")
                            .coordinator(:tool_calling)
                            .build

      expect(team).to be_a(Smolagents::Agents::ToolCalling)
    end

    it "passes max_steps to coordinator" do
      team = described_class.new
                            .model { mock_model }
                            .agent(researcher_agent, as: "researcher")
                            .max_steps(15)
                            .build

      expect(team.max_steps).to eq(15)
    end

    it "passes planning interval to coordinator" do
      team = described_class.new
                            .model { mock_model }
                            .agent(researcher_agent, as: "researcher")
                            .planning(interval: 3)
                            .build

      expect(team.planning_interval).to eq(3)
    end

    it "registers callbacks on coordinator" do
      callback_called = false
      team = described_class.new
                            .model { mock_model }
                            .agent(researcher_agent, as: "researcher")
                            .on(:after_step) { callback_called = true }
                            .build

      team.send(:trigger_callbacks, :after_step)

      expect(callback_called).to be true
    end
  end

  describe "#inspect" do
    it "shows team state" do
      builder = described_class.new
                               .agent(researcher_agent, as: "researcher")
                               .agent(writer_agent, as: "writer")

      expect(builder.inspect).to include("TeamBuilder")
      expect(builder.inspect).to include("researcher")
      expect(builder.inspect).to include("writer")
    end
  end

  describe "full composition example" do
    it "supports complete team configuration" do
      team = described_class.new
                            .model { mock_model }
                            .agent(researcher_agent, as: "researcher")
                            .agent(writer_agent, as: "writer")
                            .coordinate("Research the topic, then write a summary")
                            .coordinator(:code)
                            .max_steps(20)
                            .planning(interval: 5)
                            .on(:after_task) { |r| r }
                            .build

      expect(team).to be_a(Smolagents::Agents::Code)
      expect(team.managed_agents.size).to eq(2)
      expect(team.max_steps).to eq(20)
      expect(team.planning_interval).to eq(5)
    end
  end
end

RSpec.describe Smolagents do
  describe ".team" do
    it "returns a TeamBuilder" do
      builder = described_class.team

      expect(builder).to be_a(Smolagents::Builders::TeamBuilder)
    end

    it "can be chained to build a team" do
      mock_model = instance_double(Smolagents::OpenAIModel)
      mock_tools = { "search" => double("tool") }
      researcher = instance_double(Smolagents::Agents::Code, model: mock_model, tools: mock_tools)

      team = described_class.team
                            .agent(researcher, as: "researcher")
                            .build

      expect(team).to be_a(Smolagents::Agents::Code)
    end
  end
end
