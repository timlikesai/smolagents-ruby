require "spec_helper"
require_relative "../../../examples_new/advanced/01_planning"

RSpec.describe "Example: Planning Mode", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe "create_agent_with_planning" do
    it "creates agent with planning enabled" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_planning(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "create_agent_with_planning_interval" do
    it "creates agent with custom planning interval" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_planning_interval(model, interval: 5)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it "accepts different interval values" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_planning_interval(model, interval: 10)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "create_agent_with_planning_shorthand" do
    it "creates agent using integer shorthand" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_planning_shorthand(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "create_agent_without_planning" do
    it "creates agent with planning disabled" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_without_planning(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "planning builder DSL" do
    it ".planning with no args enables with defaults" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .planning
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it ".planning(true) enables planning" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .planning(true)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it ".planning(false) disables planning" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .planning(false)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it ".planning(:enabled) enables planning" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .planning(:enabled)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it ".planning(:disabled) disables planning" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .planning(:disabled)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it ".planning accepts integer for interval" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .planning(5)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it ".planning accepts interval keyword" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .planning(interval: 7)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end
end
