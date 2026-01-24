require "spec_helper"
require_relative "../../../examples_new/teams/02_team_building"

RSpec.describe "Example: Team Building", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe "create_basic_team" do
    it "creates a team with coordinator and sub-agents" do
      coord_model = mock_model { |m| m.queue_final_answer("coordinated") }
      research_model = mock_model { |m| m.queue_final_answer("researched") }
      analyst_model = mock_model { |m| m.queue_final_answer("analyzed") }

      team = create_basic_team(coord_model, research_model, analyst_model)

      expect(team).to be_a(Smolagents::Agents::Agent)
    end

    it "team has sub-agents as tools" do
      coord_model = mock_model { |m| m.queue_final_answer("done") }
      research_model = mock_model { |m| m.queue_final_answer("r") }
      analyst_model = mock_model { |m| m.queue_final_answer("a") }

      team = create_basic_team(coord_model, research_model, analyst_model)

      expect(team.tools.keys).to include("researcher", "analyst")
    end
  end

  describe "create_team_with_instructions" do
    it "creates team with coordination instructions" do
      coord_model = mock_model { |m| m.queue_final_answer("done") }
      research_model = mock_model { |m| m.queue_final_answer("r") }
      writer_model = mock_model { |m| m.queue_final_answer("w") }

      team = create_team_with_instructions(coord_model, research_model, writer_model)

      expect(team).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "create_team_with_limits" do
    it "creates team with max_steps limit" do
      coord_model = mock_model { |m| m.queue_final_answer("done") }
      helper_model = mock_model { |m| m.queue_final_answer("helped") }

      team = create_team_with_limits(coord_model, helper_model)

      expect(team).to be_a(Smolagents::Agents::Agent)
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

    it ".coordinate sets coordination instructions" do
      coord_model = mock_model { |m| m.queue_final_answer("done") }
      sub_model = mock_model { |m| m.queue_final_answer("sub") }
      sub_agent = Smolagents.agent.model { sub_model }.build

      team = Smolagents.team
                       .model { coord_model }
                       .agent(sub_agent, as: "worker")
                       .coordinate("Use worker for all tasks")
                       .build

      expect(team).to be_a(Smolagents::Agents::Agent)
    end

    it ".max_steps limits coordinator steps" do
      coord_model = mock_model { |m| m.queue_final_answer("done") }
      sub_model = mock_model { |m| m.queue_final_answer("sub") }
      sub_agent = Smolagents.agent.model { sub_model }.build

      team = Smolagents.team
                       .model { coord_model }
                       .agent(sub_agent, as: "worker")
                       .max_steps(5)
                       .build

      expect(team).to be_a(Smolagents::Agents::Agent)
    end

    it "model is shared with sub-agents without models" do
      shared_model = mock_model do |m|
        m.queue_final_answer("shared")
        m.queue_final_answer("done")
      end

      # Sub-agent without model
      sub_builder = Smolagents.agent

      team = Smolagents.team
                       .model { shared_model }
                       .agent(sub_builder, as: "worker")
                       .build

      expect(team).to be_a(Smolagents::Agents::Agent)
    end
  end
end
