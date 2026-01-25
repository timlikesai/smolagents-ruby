require "smolagents/concerns/agents/self_refine/feedback"

RSpec.describe Smolagents::Concerns::SelfRefine::Feedback do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::SelfRefine::Feedback

      attr_accessor :refine_config

      def initialize
        @refine_config = Smolagents::Types::RefineConfig.default
      end
    end
  end

  let(:instance) { test_class.new }

  describe "FEEDBACK_SOURCES constant" do
    it "defines execution source" do
      expect(described_class::FEEDBACK_SOURCES).to have_key(:execution)
    end

    it "defines self source" do
      expect(described_class::FEEDBACK_SOURCES).to have_key(:self)
    end

    it "defines evaluation source" do
      expect(described_class::FEEDBACK_SOURCES).to have_key(:evaluation)
    end
  end

  describe "#refinement_feedback_for" do
    let(:step) do
      Smolagents::Types::ActionStep.new(
        step_number: 1,
        error: nil,
        action_output: "output"
      )
    end

    it "returns RefinementFeedback for execution source" do
      instance.refine_config = Smolagents::Types::RefineConfig.new(
        max_iterations: 3, feedback_source: :execution, min_confidence: 0.8, enabled: true
      )

      feedback = instance.send(:refinement_feedback_for, "output", step, "task", 0)

      expect(feedback).to be_a(Smolagents::Types::RefinementFeedback)
      expect(feedback.source).to eq(:execution)
    end

    it "returns feedback with unknown source message for invalid source" do
      instance.refine_config = Smolagents::Types::RefineConfig.new(
        max_iterations: 3, feedback_source: :invalid, min_confidence: 0.8, enabled: true
      )

      feedback = instance.send(:refinement_feedback_for, "output", step, "task", 0)

      expect(feedback.critique).to include("Unknown feedback source")
      expect(feedback.actionable).to be false
    end
  end

  describe "#execution_feedback" do
    it "returns error feedback when step has error" do
      step = Smolagents::Types::ActionStep.new(
        step_number: 1,
        error: "SyntaxError: unexpected end",
        action_output: nil
      )

      feedback = instance.send(:execution_feedback, "output", step, 0)

      expect(feedback.actionable).to be true
      expect(feedback.critique).to include("Execution error")
    end

    it "returns success feedback when step has no error" do
      step = Smolagents::Types::ActionStep.new(
        step_number: 1,
        error: nil,
        action_output: "result"
      )

      feedback = instance.send(:execution_feedback, "output", step, 0)

      expect(feedback.actionable).to be false
      expect(feedback.critique).to include("succeeded")
    end
  end

  describe "#error_feedback" do
    let(:step) do
      Smolagents::Types::ActionStep.new(
        step_number: 1,
        error: "NameError: undefined variable",
        action_output: nil
      )
    end

    it "creates actionable feedback from error" do
      feedback = instance.send(:error_feedback, step, 0)

      expect(feedback.actionable).to be true
      expect(feedback.source).to eq(:execution)
      expect(feedback.confidence).to eq(0.7)
    end
  end

  describe "#success_feedback" do
    it "creates non-actionable feedback" do
      feedback = instance.send(:success_feedback, 0)

      expect(feedback.actionable).to be false
      expect(feedback.confidence).to eq(0.9)
      expect(feedback.critique).to eq("Execution succeeded")
    end
  end

  describe "#refinement_feedback" do
    it "creates RefinementFeedback with all fields" do
      feedback = instance.send(:refinement_feedback, 1, :self, "Some critique", true, 0.75)

      expect(feedback.iteration).to eq(1)
      expect(feedback.source).to eq(:self)
      expect(feedback.critique).to eq("Some critique")
      expect(feedback.actionable).to be true
      expect(feedback.confidence).to eq(0.75)
    end
  end

  describe "#evaluation_feedback" do
    let(:step) do
      Smolagents::Types::ActionStep.new(
        step_number: 1,
        error: nil,
        action_output: "result"
      )
    end

    context "when evaluate_progress is not available" do
      it "returns unavailable feedback" do
        feedback = instance.send(:evaluation_feedback, "output", step, "task", 0)

        expect(feedback.source).to eq(:evaluation)
        expect(feedback.critique).to include("not available")
        expect(feedback.actionable).to be false
      end
    end

    context "when evaluate_progress is available" do
      let(:test_class_with_eval) do
        Class.new do
          include Smolagents::Concerns::SelfRefine::Feedback

          attr_accessor :refine_config

          def initialize
            @refine_config = Smolagents::Types::RefineConfig.default
          end

          def evaluate_progress(_task, _step, _iteration)
            Data.define(:reasoning, :answer, :confidence, :continue?, :stuck?)
                .new("Needs more work", nil, 0.6, true, false)
          end
        end
      end

      it "uses evaluate_progress result" do
        eval_instance = test_class_with_eval.new
        feedback = eval_instance.send(:evaluation_feedback, "output", step, "task", 0)

        expect(feedback.source).to eq(:evaluation)
        expect(feedback.critique).to include("Needs more work")
        expect(feedback.actionable).to be true
      end
    end
  end
end
