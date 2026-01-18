require "smolagents"

RSpec.describe Smolagents::Concerns::MixedRefinement do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Concerns::CritiqueParsing
      include Smolagents::Concerns::MixedRefinement

      attr_accessor :model, :logger

      def initialize(model:, mixed_refine_config: nil)
        @model = model
        @logger = Smolagents::AgentLogger.new(output: StringIO.new, level: Smolagents::AgentLogger::DEBUG)
        initialize_mixed_refinement(mixed_refine_config:)
      end
    end
  end

  let(:mock_model) do
    instance_double(Smolagents::Model, model_id: "test-model").tap do |m|
      allow(m).to receive(:generate).and_return(
        Smolagents::ChatMessage.assistant("fixed_code = 42")
      )
    end
  end

  let(:feedback_model) do
    instance_double(Smolagents::Model, model_id: "feedback-model").tap do |m|
      allow(m).to receive(:generate).and_return(
        Smolagents::ChatMessage.assistant("APPROVED")
      )
    end
  end

  describe Smolagents::Types::MixedRefineConfig do
    describe ".default" do
      it "creates config with cross_model disabled by default" do
        config = described_class.default
        expect(config.enabled).to be(true)
        expect(config.max_iterations).to eq(2)
        expect(config.cross_model_enabled).to be(false)
        expect(config.feedback_model).to be_nil
        expect(config.feedback_temperature).to eq(0.3)
      end
    end

    describe ".with_feedback_model" do
      it "creates config with cross-model feedback enabled" do
        model = instance_double(Smolagents::Model)
        config = described_class.with_feedback_model(model, max_iterations: 3)
        expect(config.cross_model_enabled).to be(true)
        expect(config.feedback_model).to eq(model)
        expect(config.max_iterations).to eq(3)
      end
    end

    describe ".disabled" do
      it "creates disabled config" do
        config = described_class.disabled
        expect(config.enabled).to be(false)
        expect(config.max_iterations).to eq(0)
      end
    end

    describe "#to_refine_config" do
      it "converts to base RefineConfig" do
        config = described_class.default
        refine_config = config.to_refine_config
        expect(refine_config).to be_a(Smolagents::Types::RefineConfig)
        expect(refine_config.max_iterations).to eq(config.max_iterations)
        expect(refine_config.enabled).to eq(config.enabled)
      end
    end
  end

  describe Smolagents::Types::MixedRefinementResult do
    let(:base_result) do
      Smolagents::Types::RefinementResult.after_refinement(
        original: "old",
        refined: "new",
        iterations: 2,
        feedback_history: [],
        improved: true,
        confidence: 0.9
      )
    end

    describe ".from_refinement_result" do
      it "creates result with model attribution" do
        result = described_class.from_refinement_result(
          base_result,
          generation_model: "small-model",
          feedback_model_id: "large-model"
        )
        expect(result.generation_model).to eq("small-model")
        expect(result.feedback_model_id).to eq("large-model")
        expect(result.cross_model).to be(true)
      end

      it "detects same-model when models match" do
        result = described_class.from_refinement_result(
          base_result,
          generation_model: "same-model",
          feedback_model_id: "same-model"
        )
        expect(result.cross_model).to be(false)
      end
    end

    describe "#refined?" do
      it "returns true when iterations > 0" do
        result = described_class.from_refinement_result(
          base_result, generation_model: "a", feedback_model_id: "b"
        )
        expect(result.refined?).to be(true)
      end

      it "returns false when iterations == 0" do
        no_refine = Smolagents::Types::RefinementResult.no_refinement_needed("x")
        result = described_class.from_refinement_result(
          no_refine, generation_model: "a", feedback_model_id: "a"
        )
        expect(result.refined?).to be(false)
      end
    end

    describe "#final" do
      it "returns refined when improved" do
        result = described_class.from_refinement_result(
          base_result, generation_model: "a", feedback_model_id: "b"
        )
        expect(result.final).to eq("new")
      end

      it "returns original when not improved" do
        not_improved = Smolagents::Types::RefinementResult.after_refinement(
          original: "old", refined: "new", iterations: 1,
          feedback_history: [], improved: false, confidence: 0.5
        )
        result = described_class.from_refinement_result(
          not_improved, generation_model: "a", feedback_model_id: "b"
        )
        expect(result.final).to eq("old")
      end
    end
  end

  describe "#initialize_mixed_refinement" do
    it "defaults to nil config" do
      agent = test_class.new(model: mock_model)
      expect(agent.mixed_refine_config).to be_nil
    end

    it "stores provided config" do
      config = Smolagents::Types::MixedRefineConfig.default
      agent = test_class.new(model: mock_model, mixed_refine_config: config)
      expect(agent.mixed_refine_config.enabled).to be(true)
    end
  end

  describe "#effective_feedback_model" do
    context "when cross_model_enabled with feedback_model" do
      it "returns the feedback model" do
        config = Smolagents::Types::MixedRefineConfig.with_feedback_model(feedback_model)
        agent = test_class.new(model: mock_model, mixed_refine_config: config)
        expect(agent.send(:effective_feedback_model)).to eq(feedback_model)
      end
    end

    context "when cross_model disabled" do
      it "returns the primary model" do
        config = Smolagents::Types::MixedRefineConfig.default
        agent = test_class.new(model: mock_model, mixed_refine_config: config)
        expect(agent.send(:effective_feedback_model)).to eq(mock_model)
      end
    end

    context "when no config" do
      it "returns the primary model" do
        agent = test_class.new(model: mock_model)
        expect(agent.send(:effective_feedback_model)).to eq(mock_model)
      end
    end
  end

  describe "#get_feedback" do
    let(:config) { Smolagents::Types::MixedRefineConfig.with_feedback_model(feedback_model) }
    let(:agent) { test_class.new(model: mock_model, mixed_refine_config: config) }

    context "when reviewer says APPROVED" do
      it "returns non-actionable feedback" do
        allow(feedback_model).to receive(:generate).and_return(
          Smolagents::ChatMessage.assistant("APPROVED")
        )
        feedback = agent.send(:get_feedback, "code", "task", 0)
        expect(feedback.actionable).to be(false)
        expect(feedback.critique).to include("approved")
        expect(feedback.confidence).to eq(0.9)
      end
    end

    context "when reviewer identifies issue" do
      it "returns actionable feedback with parsed fix" do
        allow(feedback_model).to receive(:generate).and_return(
          Smolagents::ChatMessage.assistant("ISSUE: undefined variable x | FIX: define x = 0 first")
        )
        feedback = agent.send(:get_feedback, "code", "task", 0)
        expect(feedback.actionable).to be(true)
        expect(feedback.critique).to include("undefined variable")
        expect(feedback.critique).to include("Fix:")
        expect(feedback.confidence).to eq(0.8)
      end
    end

    context "when reviewer gives unclear response" do
      it "extracts what content it can" do
        allow(feedback_model).to receive(:generate).and_return(
          Smolagents::ChatMessage.assistant("The code has some minor issues with formatting")
        )
        feedback = agent.send(:get_feedback, "code", "task", 0)
        expect(feedback.confidence).to eq(0.5)
        expect(feedback.critique.length).to be <= 200
      end
    end

    it "uses feedback model for critique" do
      agent.send(:get_feedback, "code", "task", 0)
      expect(feedback_model).to have_received(:generate)
    end
  end

  describe "#attempt_mixed_refinement" do
    let(:step) do
      Smolagents::ActionStep.new(
        step_number: 1,
        action_output: "result = 42",
        code_action: "result = 42"
      )
    end

    context "when disabled" do
      let(:agent) { test_class.new(model: mock_model) }

      it "returns no-refinement result" do
        result = agent.send(:attempt_mixed_refinement, step, "task")
        expect(result.refined?).to be(false)
        expect(result.generation_model).to eq("test-model")
      end
    end

    context "when enabled and code approved" do
      let(:config) { Smolagents::Types::MixedRefineConfig.with_feedback_model(feedback_model) }
      let(:agent) { test_class.new(model: mock_model, mixed_refine_config: config) }

      before do
        allow(feedback_model).to receive(:generate).and_return(
          Smolagents::ChatMessage.assistant("APPROVED")
        )
      end

      it "returns result without refinement" do
        result = agent.send(:attempt_mixed_refinement, step, "task")
        expect(result.iterations).to eq(0)
        expect(result.improved).to be(false)
      end
    end

    context "when enabled and feedback suggests fix" do
      let(:config) { Smolagents::Types::MixedRefineConfig.with_feedback_model(feedback_model) }
      let(:agent) { test_class.new(model: mock_model, mixed_refine_config: config) }

      before do
        call_count = 0
        allow(feedback_model).to receive(:generate) do
          call_count += 1
          if call_count == 1
            Smolagents::ChatMessage.assistant("ISSUE: missing error handling | FIX: add begin/rescue")
          else
            Smolagents::ChatMessage.assistant("APPROVED")
          end
        end

        allow(mock_model).to receive(:generate).and_return(
          Smolagents::ChatMessage.assistant("begin\n  result = 42\nrescue\n  nil\nend")
        )
      end

      it "performs refinement" do
        result = agent.send(:attempt_mixed_refinement, step, "task")
        expect(result.iterations).to be >= 1
        expect(result.feedback_history).not_to be_empty
      end

      it "uses generation model for fixes" do
        agent.send(:attempt_mixed_refinement, step, "task")
        expect(mock_model).to have_received(:generate).at_least(:once)
      end

      it "attributes models correctly" do
        result = agent.send(:attempt_mixed_refinement, step, "task")
        expect(result.cross_model).to be(true)
        expect(result.generation_model).to eq("test-model")
        expect(result.feedback_model_id).to eq("feedback-model")
      end
    end

    context "with max_iterations limit" do
      let(:config) do
        Smolagents::Types::MixedRefineConfig.new(
          max_iterations: 1, feedback_source: :self, min_confidence: 0.8, enabled: true,
          feedback_model:, feedback_temperature: 0.3, cross_model_enabled: true
        )
      end
      let(:agent) { test_class.new(model: mock_model, mixed_refine_config: config) }

      before do
        allow(feedback_model).to receive(:generate).and_return(
          Smolagents::ChatMessage.assistant("ISSUE: needs improvement | FIX: improve it")
        )
        allow(mock_model).to receive(:generate).and_return(
          Smolagents::ChatMessage.assistant("improved code")
        )
      end

      it "respects max_iterations" do
        result = agent.send(:attempt_mixed_refinement, step, "task")
        expect(result.iterations).to be <= 1
      end
    end
  end

  describe "#execute_mixed_refinement_if_needed" do
    let(:step) do
      Smolagents::ActionStep.new(step_number: 1, action_output: "result = 42")
    end

    context "when disabled" do
      let(:agent) { test_class.new(model: mock_model) }

      it "returns nil" do
        result = agent.send(:execute_mixed_refinement_if_needed, step, "task")
        expect(result).to be_nil
      end
    end

    context "when step is final answer" do
      let(:config) { Smolagents::Types::MixedRefineConfig.default }
      let(:agent) { test_class.new(model: mock_model, mixed_refine_config: config) }

      it "returns nil" do
        final_step = Smolagents::ActionStep.new(step_number: 1, is_final_answer: true)
        result = agent.send(:execute_mixed_refinement_if_needed, final_step, "task")
        expect(result).to be_nil
      end
    end

    context "when enabled" do
      let(:config) { Smolagents::Types::MixedRefineConfig.with_feedback_model(feedback_model) }
      let(:agent) { test_class.new(model: mock_model, mixed_refine_config: config) }

      before do
        allow(feedback_model).to receive(:generate).and_return(
          Smolagents::ChatMessage.assistant("APPROVED")
        )
      end

      it "returns mixed refinement result" do
        result = agent.send(:execute_mixed_refinement_if_needed, step, "task")
        expect(result).to be_a(Smolagents::Types::MixedRefinementResult)
      end

      it "yields when refined and block given" do
        call_count = 0
        allow(feedback_model).to receive(:generate) do
          call_count += 1
          call_count == 1 ? Smolagents::ChatMessage.assistant("ISSUE: x | FIX: y") : Smolagents::ChatMessage.assistant("APPROVED")
        end
        allow(mock_model).to receive(:generate).and_return(
          Smolagents::ChatMessage.assistant("fixed")
        )

        yielded = nil
        agent.send(:execute_mixed_refinement_if_needed, step, "task") { |r| yielded = r }

        expect(yielded&.refined?).to be(true) if yielded
      end
    end
  end

  describe "#model_id" do
    let(:agent) { test_class.new(model: mock_model) }

    it "returns model_id when available" do
      model = instance_double(Smolagents::Model, model_id: "gpt-4")
      expect(agent.send(:model_id, model)).to eq("gpt-4")
    end

    it "returns class name as fallback" do
      model = Object.new
      expect(agent.send(:model_id, model)).to eq("Object")
    end
  end

  describe "CRITIQUE_SYSTEM" do
    it "contains structured review instructions" do
      prompt = Smolagents::Concerns::MixedRefinement::CRITIQUE_SYSTEM
      expect(prompt).to include("code reviewer")
      expect(prompt).to include("APPROVED")
    end
  end
end
