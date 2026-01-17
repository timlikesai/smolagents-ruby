require "smolagents"

RSpec.describe Smolagents::Concerns::SelfRefine do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Concerns::SelfRefine
      include Smolagents::Concerns::ExecutionOracle

      attr_accessor :model, :logger

      def initialize(model:, refine_config: nil)
        @model = model
        @logger = Smolagents::AgentLogger.new(output: StringIO.new, level: Smolagents::AgentLogger::DEBUG)
        initialize_self_refine(refine_config:)
      end
    end
  end

  let(:mock_model) do
    instance_double(Smolagents::Model).tap do |m|
      allow(m).to receive(:generate).and_return(
        Smolagents::ChatMessage.assistant("fixed_code = 42")
      )
    end
  end

  describe Smolagents::Concerns::SelfRefine::RefineConfig do
    describe ".default" do
      it "creates enabled config with sensible defaults" do
        config = described_class.default
        expect(config.enabled).to be(true)
        expect(config.max_iterations).to eq(3)
        expect(config.feedback_source).to eq(:execution)
        expect(config.min_confidence).to eq(0.8)
      end
    end

    describe ".disabled" do
      it "creates disabled config" do
        config = described_class.disabled
        expect(config.enabled).to be(false)
        expect(config.max_iterations).to eq(0)
      end
    end
  end

  describe Smolagents::Concerns::SelfRefine::RefinementResult do
    describe ".no_refinement_needed" do
      it "creates result with zero iterations" do
        result = described_class.no_refinement_needed("output", confidence: 0.95)
        expect(result.iterations).to eq(0)
        expect(result.refined?).to be(false)
        expect(result.improved).to be(false)
        expect(result.original).to eq("output")
        expect(result.refined).to eq("output")
        expect(result.confidence).to eq(0.95)
      end
    end

    describe ".after_refinement" do
      it "creates result with refinement details" do
        feedback = Smolagents::Concerns::SelfRefine::RefinementFeedback.new(
          iteration: 1,
          source: :execution,
          critique: "Fix the error",
          actionable: true,
          confidence: 0.7
        )

        result = described_class.after_refinement(
          original: "broken",
          refined: "fixed",
          iterations: 1,
          feedback_history: [feedback],
          improved: true,
          confidence: 0.9
        )

        expect(result.refined?).to be(true)
        expect(result.improved).to be(true)
        expect(result.final).to eq("fixed")
        expect(result.feedback_history.size).to eq(1)
      end
    end

    describe "#final" do
      it "returns refined if improved" do
        result = described_class.after_refinement(
          original: "old", refined: "new", iterations: 1,
          feedback_history: [], improved: true, confidence: 0.9
        )
        expect(result.final).to eq("new")
      end

      it "returns original if not improved" do
        result = described_class.after_refinement(
          original: "old", refined: "new", iterations: 1,
          feedback_history: [], improved: false, confidence: 0.5
        )
        expect(result.final).to eq("old")
      end
    end

    describe "#maxed_out?" do
      it "returns true when iterations equal max" do
        result = described_class.after_refinement(
          original: "x", refined: "y", iterations: 3,
          feedback_history: [], improved: true, confidence: 0.9
        )
        expect(result.maxed_out?(3)).to be(true)
        expect(result.maxed_out?(5)).to be(false)
      end
    end
  end

  describe Smolagents::Concerns::SelfRefine::RefinementFeedback do
    describe "#suggests_improvement?" do
      it "returns true when actionable with high confidence" do
        feedback = described_class.new(
          iteration: 0,
          source: :execution,
          critique: "Fix this",
          actionable: true,
          confidence: 0.7
        )
        expect(feedback.suggests_improvement?).to be(true)
      end

      it "returns false when not actionable" do
        feedback = described_class.new(
          iteration: 0,
          source: :execution,
          critique: "Looks good",
          actionable: false,
          confidence: 0.9
        )
        expect(feedback.suggests_improvement?).to be(false)
      end

      it "returns false when low confidence" do
        feedback = described_class.new(
          iteration: 0,
          source: :self,
          critique: "Maybe fix this",
          actionable: true,
          confidence: 0.3
        )
        expect(feedback.suggests_improvement?).to be(false)
      end
    end
  end

  describe "#initialize_self_refine" do
    it "defaults to disabled when no config provided" do
      agent = test_class.new(model: mock_model)
      expect(agent.refine_config.enabled).to be(false)
    end

    it "uses provided config" do
      config = Smolagents::Concerns::SelfRefine::RefineConfig.default
      agent = test_class.new(model: mock_model, refine_config: config)
      expect(agent.refine_config.enabled).to be(true)
      expect(agent.refine_config.max_iterations).to eq(3)
    end
  end

  describe "#attempt_refinement" do
    let(:config) { Smolagents::Concerns::SelfRefine::RefineConfig.default }
    let(:agent) { test_class.new(model: mock_model, refine_config: config) }

    context "when step has no error" do
      let(:step) do
        Smolagents::ActionStep.new(
          step_number: 1,
          action_output: "42",
          error: nil
        )
      end

      it "returns no refinement needed" do
        result = agent.send(:attempt_refinement, step, "compute result")
        expect(result.refined?).to be(false)
        expect(result.iterations).to eq(0)
      end
    end

    context "when step has error" do
      let(:step) do
        Smolagents::ActionStep.new(
          step_number: 1,
          action_output: nil,
          error: "undefined local variable or method `foo'",
          code_action: "result = foo + 1"
        )
      end

      it "attempts refinement" do
        result = agent.send(:attempt_refinement, step, "compute result")
        expect(result.iterations).to be >= 1
        expect(result.feedback_history).not_to be_empty
      end

      it "calls model to generate refinement" do
        agent.send(:attempt_refinement, step, "compute result")
        expect(mock_model).to have_received(:generate).at_least(:once)
      end
    end

    context "when disabled" do
      let(:disabled_agent) { test_class.new(model: mock_model) }
      let(:step) do
        Smolagents::ActionStep.new(
          step_number: 1,
          action_output: nil,
          error: "some error"
        )
      end

      it "returns no refinement needed" do
        result = disabled_agent.send(:attempt_refinement, step, "task")
        expect(result.refined?).to be(false)
      end
    end
  end

  describe "#execution_feedback" do
    let(:config) { Smolagents::Concerns::SelfRefine::RefineConfig.default }
    let(:agent) { test_class.new(model: mock_model, refine_config: config) }

    context "when step has error" do
      let(:step) do
        Smolagents::ActionStep.new(
          step_number: 1,
          error: "undefined local variable or method `x'"
        )
      end

      it "returns actionable feedback" do
        feedback = agent.send(:execution_feedback, nil, step, 0)
        expect(feedback.actionable).to be(true)
        expect(feedback.source).to eq(:execution)
        expect(feedback.critique).to include("error")
      end
    end

    context "when step succeeded" do
      let(:step) do
        Smolagents::ActionStep.new(
          step_number: 1,
          action_output: "42",
          error: nil
        )
      end

      it "returns non-actionable feedback" do
        feedback = agent.send(:execution_feedback, "42", step, 0)
        expect(feedback.actionable).to be(false)
        expect(feedback.confidence).to be >= 0.8
      end
    end
  end

  describe "#self_critique_feedback" do
    let(:config) do
      Smolagents::Concerns::SelfRefine::RefineConfig.new(
        max_iterations: 3,
        feedback_source: :self,
        min_confidence: 0.8,
        enabled: true
      )
    end
    let(:agent) { test_class.new(model: mock_model, refine_config: config) }

    context "when model says LGTM" do
      before do
        allow(mock_model).to receive(:generate).and_return(
          Smolagents::ChatMessage.assistant("LGTM - code looks good")
        )
      end

      it "returns non-actionable feedback" do
        feedback = agent.send(:self_critique_feedback, "code", "task", 0)
        expect(feedback.actionable).to be(false)
        expect(feedback.source).to eq(:self)
      end
    end

    context "when model identifies issue" do
      before do
        allow(mock_model).to receive(:generate).and_return(
          Smolagents::ChatMessage.assistant("ISSUE: undefined variable | FIX: define x first")
        )
      end

      it "returns actionable feedback with parsed issue" do
        feedback = agent.send(:self_critique_feedback, "code", "task", 0)
        expect(feedback.actionable).to be(true)
        expect(feedback.critique).to include("undefined variable")
        expect(feedback.critique).to include("Fix:")
      end
    end
  end

  describe "#execute_refinement_if_needed" do
    let(:config) { Smolagents::Concerns::SelfRefine::RefineConfig.default }
    let(:agent) { test_class.new(model: mock_model, refine_config: config) }

    context "when disabled" do
      let(:disabled_agent) { test_class.new(model: mock_model) }

      it "returns nil" do
        step = Smolagents::ActionStep.new(step_number: 1)
        result = disabled_agent.send(:execute_refinement_if_needed, step, "task")
        expect(result).to be_nil
      end
    end

    context "when step is final answer" do
      it "returns nil" do
        step = Smolagents::ActionStep.new(step_number: 1, is_final_answer: true)
        result = agent.send(:execute_refinement_if_needed, step, "task")
        expect(result).to be_nil
      end
    end

    context "when refinement occurs" do
      let(:step) do
        Smolagents::ActionStep.new(
          step_number: 1,
          error: "some error",
          action_output: nil
        )
      end

      it "returns refinement result" do
        result = agent.send(:execute_refinement_if_needed, step, "task")
        expect(result).to be_a(Smolagents::Concerns::SelfRefine::RefinementResult)
      end

      it "yields result when block given" do
        yielded = nil
        agent.send(:execute_refinement_if_needed, step, "task") { |r| yielded = r }
        expect(yielded).to be_a(Smolagents::Concerns::SelfRefine::RefinementResult)
      end
    end
  end

  describe "FEEDBACK_SOURCES" do
    it "includes expected sources" do
      expect(Smolagents::Concerns::SelfRefine::FEEDBACK_SOURCES).to include(:execution)
      expect(Smolagents::Concerns::SelfRefine::FEEDBACK_SOURCES).to include(:self)
      expect(Smolagents::Concerns::SelfRefine::FEEDBACK_SOURCES).to include(:evaluation)
    end
  end
end
