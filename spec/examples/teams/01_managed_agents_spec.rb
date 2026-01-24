require "spec_helper"
require_relative "../../../examples_new/teams/01_managed_agents"

RSpec.describe "Example: Managed Agents", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe "create_agent_with_helper (AgentBuilder DSL)" do
    it "creates parent agent with managed sub-agent" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      helper = mock_model { |m| m.queue_final_answer("helped") }

      agent = create_agent_with_helper(parent, helper)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it "registers the managed agent as a tool" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      helper = mock_model { |m| m.queue_final_answer("helped") }

      agent = create_agent_with_helper(parent, helper)

      expect(agent.tools.keys).to include("researcher")
    end

    it "managed_agents hash contains ManagedAgentTool" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      helper = mock_model { |m| m.queue_final_answer("helped") }

      agent = create_agent_with_helper(parent, helper)

      expect(agent.managed_agents).to have_key("researcher")
      expect(agent.managed_agents["researcher"]).to be_a(Smolagents::ManagedAgentTool)
    end

    it "sub-agent has its own tools" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      helper = mock_model { |m| m.queue_final_answer("helped") }

      agent = create_agent_with_helper(parent, helper)

      sub_agent = agent.managed_agents["researcher"].agent
      expect(sub_agent.tools).to have_key("lookup")
    end
  end

  describe "create_agent_with_specialists (multiple managed agents)" do
    it "creates agent with multiple managed agents" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      researcher = mock_model { |m| m.queue_final_answer("researched") }
      writer = mock_model { |m| m.queue_final_answer("written") }

      agent = create_agent_with_specialists(parent, researcher, writer)

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent.tools.keys).to include("researcher", "writer")
    end

    it "each managed agent has its own tools" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      researcher = mock_model { |m| m.queue_final_answer("r") }
      writer = mock_model { |m| m.queue_final_answer("w") }

      agent = create_agent_with_specialists(parent, researcher, writer)

      expect(agent.managed_agents["researcher"].agent.tools).to have_key("search")
      expect(agent.managed_agents["writer"].agent.tools).to have_key("format")
    end
  end

  describe "create_team_with_coordination (TeamBuilder)" do
    it "creates coordinator with managed sub-agent" do
      coordinator = mock_model { |m| m.queue_final_answer("done") }
      helper = mock_model { |m| m.queue_final_answer("helped") }

      team = create_team_with_coordination(coordinator, helper)

      expect(team).to be_a(Smolagents::Agents::Agent)
      expect(team.tools.keys).to include("researcher")
    end
  end

  describe "AgentBuilder.managed_agent DSL" do
    it "accepts symbol for as: parameter" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      child = mock_model { |m| m.queue_final_answer("child") }
      sub_agent = Smolagents.agent.model { child }.build

      agent = Smolagents.agent
                        .model { parent }
                        .managed_agent(sub_agent, as: :my_helper)
                        .build

      expect(agent.tools).to have_key("my_helper")
    end

    it "accepts string for as: parameter" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      child = mock_model { |m| m.queue_final_answer("child") }
      sub_agent = Smolagents.agent.model { child }.build

      agent = Smolagents.agent
                        .model { parent }
                        .managed_agent(sub_agent, as: "string_name")
                        .build

      expect(agent.tools).to have_key("string_name")
    end

    it "chains multiple managed_agent calls" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      child1 = mock_model { |m| m.queue_final_answer("a") }
      child2 = mock_model { |m| m.queue_final_answer("b") }

      agent1 = Smolagents.agent.model { child1 }.build
      agent2 = Smolagents.agent.model { child2 }.build

      agent = Smolagents.agent
                        .model { parent }
                        .managed_agent(agent1, as: :first)
                        .managed_agent(agent2, as: :second)
                        .build

      expect(agent.tools.keys).to include("first", "second")
    end

    it "accepts AgentBuilder (not just built agent)" do
      parent = mock_model { |m| m.queue_final_answer("done") }
      child = mock_model { |m| m.queue_final_answer("child") }

      # Pass builder, not built agent
      sub_builder = Smolagents.agent.model { child }

      agent = Smolagents.agent
                        .model { parent }
                        .managed_agent(sub_builder, as: :lazy_helper)
                        .build

      expect(agent.tools).to have_key("lazy_helper")
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

    it "has task as input parameter" do
      model = mock_model { |m| m.queue_final_answer("result") }
      agent = Smolagents.agent.model { model }.build

      tool = Smolagents::ManagedAgentTool.new(agent:, name: "worker")

      expect(tool.inputs).to have_key("task")
      expect(tool.inputs["task"][:type]).to eq("string")
    end
  end
end
