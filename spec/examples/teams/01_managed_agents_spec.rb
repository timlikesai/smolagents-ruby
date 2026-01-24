require "spec_helper"
require_relative "../../../examples_new/teams/01_managed_agents"

RSpec.describe "Example: Managed Agents", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe "create_team_with_helper" do
    it "creates coordinator with managed sub-agent" do
      coordinator = mock_model { |m| m.queue_final_answer("done") }
      helper = mock_model { |m| m.queue_final_answer("helped") }

      team = create_team_with_helper(coordinator, helper)

      expect(team).to be_a(Smolagents::Agents::Agent)
    end

    it "registers the managed agent as a tool" do
      coordinator = mock_model { |m| m.queue_final_answer("done") }
      helper = mock_model { |m| m.queue_final_answer("helped") }

      team = create_team_with_helper(coordinator, helper)

      # Managed agents appear as tools
      expect(team.tools.keys).to include("researcher")
    end

    it "managed_agents hash contains ManagedAgentTool" do
      coordinator = mock_model { |m| m.queue_final_answer("done") }
      helper = mock_model { |m| m.queue_final_answer("helped") }

      team = create_team_with_helper(coordinator, helper)

      expect(team.managed_agents).to have_key("researcher")
      expect(team.managed_agents["researcher"]).to be_a(Smolagents::ManagedAgentTool)
    end
  end

  describe "create_team_with_specialists" do
    it "creates team with multiple managed agents" do
      coordinator = mock_model { |m| m.queue_final_answer("done") }
      researcher = mock_model { |m| m.queue_final_answer("researched") }
      writer = mock_model { |m| m.queue_final_answer("written") }

      team = create_team_with_specialists(coordinator, researcher, writer)

      expect(team).to be_a(Smolagents::Agents::Agent)
      expect(team.tools.keys).to include("researcher", "writer")
    end

    it "each managed agent has its own tools" do
      coordinator = mock_model { |m| m.queue_final_answer("done") }
      researcher = mock_model { |m| m.queue_final_answer("r") }
      writer = mock_model { |m| m.queue_final_answer("w") }

      team = create_team_with_specialists(coordinator, researcher, writer)

      # Sub-agents have their specialized tools
      researcher_agent = team.managed_agents["researcher"].agent
      writer_agent = team.managed_agents["writer"].agent

      expect(researcher_agent.tools).to have_key("search")
      expect(writer_agent.tools).to have_key("format")
    end
  end

  describe "TeamBuilder DSL" do
    it "Smolagents.team creates TeamBuilder" do
      builder = Smolagents.team

      expect(builder).to be_a(Smolagents::Builders::TeamBuilder)
    end

    it ".agent adds sub-agent to team" do
      coord_model = mock_model { |m| m.queue_final_answer("done") }
      sub_model = mock_model { |m| m.queue_final_answer("sub") }
      sub_agent = Smolagents.agent.model { sub_model }.build

      team = Smolagents.team
                       .model { coord_model }
                       .agent(sub_agent, as: "helper")
                       .build

      expect(team.tools).to have_key("helper")
    end

    it "sub-agents without model inherit team model" do
      shared_model = mock_model do |m|
        m.queue_final_answer("shared1")
        m.queue_final_answer("shared2")
      end

      # Sub-agent builder without model
      sub_builder = Smolagents.agent.tool(:greet, "Greet", name: String) { |name:| "Hi #{name}" }

      team = Smolagents.team
                       .model { shared_model }
                       .agent(sub_builder, as: "greeter")
                       .build

      # Sub-agent inherits the shared model
      expect(team.managed_agents["greeter"].agent.model).to eq(shared_model)
    end
  end

  describe "ManagedAgentTool" do
    it "wraps agent as callable tool" do
      model = mock_model { |m| m.queue_final_answer("result") }
      agent = Smolagents.agent.model { model }.build

      tool = Smolagents::ManagedAgentTool.new(agent:, name: "helper")

      expect(tool.tool_name).to eq("helper")
      expect(tool.description).to include("final_answer")
    end

    it "has task as input" do
      model = mock_model { |m| m.queue_final_answer("result") }
      agent = Smolagents.agent.model { model }.build

      tool = Smolagents::ManagedAgentTool.new(agent:, name: "worker")

      expect(tool.inputs).to have_key("task")
    end
  end
end
