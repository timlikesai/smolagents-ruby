require "spec_helper"
require_relative "../../../examples/advanced/03_evaluation"

RSpec.describe "Example: Evaluation", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe "create_agent_with_default_evaluation" do
    it "creates agent with evaluation enabled by default" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_default_evaluation(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "create_agent_with_evaluation" do
    it "creates agent with explicit evaluation" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_evaluation(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "create_agent_without_evaluation" do
    it "creates agent with evaluation disabled" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_without_evaluation(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "create_advanced_agent" do
    it "creates agent with all advanced features" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_advanced_agent(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "evaluation builder DSL" do
    it ".evaluation with no args enables evaluation" do
      model = mock_model { |m| m.queue_final_answer("done") }

      builder = Smolagents.agent
                          .model { model }
                          .evaluation

      expect(builder.config[:evaluation_enabled]).to be true
    end

    it ".evaluation(true) enables with positional" do
      model = mock_model { |m| m.queue_final_answer("done") }

      builder = Smolagents.agent
                          .model { model }
                          .evaluation(true)

      expect(builder.config[:evaluation_enabled]).to be true
    end

    it ".evaluation(false) disables with positional" do
      model = mock_model { |m| m.queue_final_answer("done") }

      builder = Smolagents.agent
                          .model { model }
                          .evaluation(false)

      expect(builder.config[:evaluation_enabled]).to be false
    end

    it ".evaluation(enabled: true) enables evaluation" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .evaluation(enabled: true)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it ".evaluation(enabled: false) disables evaluation" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .evaluation(enabled: false)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "combined advanced features" do
    it "planning + refinement + evaluation work together" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .planning(interval: 5)
                        .refine(max_iterations: 2)
                        .evaluation(enabled: true)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it "order of DSL calls doesn't matter" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .evaluation(enabled: true)
                        .refine(3)
                        .planning(5)
                        .model { model }
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "EvaluationResult" do
    it "has status, answer, and confidence" do
      result = Smolagents::Types::EvaluationResult.new(
        status: :goal_achieved,
        answer: "42",
        reasoning: "Task completed",
        confidence: 0.95,
        token_usage: 50
      )

      expect(result.status).to eq(:goal_achieved)
      expect(result.answer).to eq("42")
      expect(result.confidence).to eq(0.95)
    end

    it "confident? checks threshold" do
      result = Smolagents::Types::EvaluationResult.new(
        status: :goal_achieved,
        answer: "done",
        reasoning: "Complete",
        confidence: 0.8,
        token_usage: 50
      )

      expect(result.confident?(threshold: 0.7)).to be true
      expect(result.confident?(threshold: 0.9)).to be false
    end
  end
end
