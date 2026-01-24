require "spec_helper"
require_relative "../../../examples/advanced/02_refinement"

RSpec.describe "Example: Self-Refinement", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe "create_agent_with_refinement" do
    it "creates agent with refinement enabled" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_refinement(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "create_agent_with_max_iterations" do
    it "creates agent with custom max iterations" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_max_iterations(model, iterations: 2)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "create_agent_with_refinement_shorthand" do
    it "creates agent using integer shorthand" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_refinement_shorthand(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "create_agent_with_execution_feedback" do
    it "creates agent with execution feedback source" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_execution_feedback(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "create_agent_with_confidence_threshold" do
    it "creates agent with confidence threshold" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_confidence_threshold(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "refinement builder DSL" do
    it ".refine with no args enables with defaults" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .refine
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it ".refine(true) enables refinement" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .refine(true)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it ".refine(false) disables refinement" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .refine(false)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it ".refine accepts integer for max_iterations" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .refine(3)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it ".refine accepts max_iterations keyword" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .refine(max_iterations: 5)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it ".refine accepts feedback keyword" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .refine(feedback: :execution)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it ".refine accepts min_confidence keyword" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .refine(min_confidence: 0.85)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it ".refine accepts all options together" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .refine(max_iterations: 2, feedback: :execution, min_confidence: 0.9)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "RefineConfig" do
    it "has expected defaults" do
      config = Smolagents::Types::RefineConfig.default

      expect(config.max_iterations).to eq(3)
      expect(config.feedback_source).to eq(:execution)
      expect(config.min_confidence).to eq(0.8)
    end

    it "can be customized via new()" do
      config = Smolagents::Types::RefineConfig.new(
        max_iterations: 5,
        feedback_source: :self,
        min_confidence: 0.95,
        enabled: true
      )

      expect(config.max_iterations).to eq(5)
      expect(config.feedback_source).to eq(:self)
      expect(config.min_confidence).to eq(0.95)
    end

    it "has disabled factory method" do
      config = Smolagents::Types::RefineConfig.disabled

      expect(config.enabled).to be false
    end
  end
end
