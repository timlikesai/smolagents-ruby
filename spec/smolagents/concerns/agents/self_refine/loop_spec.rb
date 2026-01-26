require "smolagents/concerns/agents/self_refine/loop"

RSpec.describe Smolagents::Concerns::SelfRefine::Loop do
  # Use a simple object instead of Logger since the implementation
  # uses semantic logging with keyword arguments
  let(:mock_logger) do
    double("Logger").tap do |logger|
      allow(logger).to receive(:info)
      allow(logger).to receive(:debug)
    end
  end

  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::SelfRefine::Loop

      attr_accessor :refine_config, :model, :logger, :event_queue

      def initialize(logger: nil)
        @logger = logger
        @refine_config = Smolagents::Types::RefineConfig.default
      end

      # Stub feedback method
      def refinement_feedback_for(_output, _step, _task, iteration)
        Smolagents::Types::RefinementFeedback.new(
          iteration:,
          source: :execution,
          critique: "Needs improvement",
          actionable: iteration < 2,
          confidence: 0.7
        )
      end

      # Stub refinement method
      def apply_refinement(current, _feedback, _task)
        "refined_#{current}"
      end
    end
  end

  let(:instance) { test_class.new(logger: mock_logger) }

  describe "RefinementState" do
    it "creates from output" do
      state = described_class::RefinementState.from_output("initial")

      expect(state.original).to eq("initial")
      expect(state.current).to eq("initial")
      expect(state.feedback_history).to eq([])
      expect(state.iterations).to eq(0)
    end

    it "tracks improvement" do
      state = described_class::RefinementState.from_output("initial")
      state.current = "modified"

      expect(state.improved?).to be true
    end

    it "reports no improvement when unchanged" do
      state = described_class::RefinementState.from_output("initial")

      expect(state.improved?).to be false
    end

    it "calculates confidence from last feedback" do
      state = described_class::RefinementState.from_output("initial")
      feedback = Smolagents::Types::RefinementFeedback.new(
        iteration: 0, source: :self, critique: "Good", actionable: false, confidence: 0.85
      )
      state.feedback_history << feedback

      expect(state.confidence).to eq(0.85)
    end

    it "defaults confidence to 1.0 without feedback" do
      state = described_class::RefinementState.from_output("initial")

      expect(state.confidence).to eq(1.0)
    end
  end

  describe "#attempt_refinement" do
    let(:step) do
      Smolagents::Types::ActionStep.new(
        step_number: 1,
        error: nil,
        action_output: "initial output"
      )
    end

    it "returns no_refinement_needed when disabled" do
      instance.refine_config = Smolagents::Types::RefineConfig.disabled

      result = instance.send(:attempt_refinement, step, "task")

      expect(result).to be_a(Smolagents::Types::RefinementResult)
      expect(result.iterations).to eq(0)
      expect(result.improved).to be false
    end

    it "returns RefinementResult when enabled" do
      result = instance.send(:attempt_refinement, step, "task")

      expect(result).to be_a(Smolagents::Types::RefinementResult)
    end

    it "performs iterations up to max" do
      instance.refine_config = Smolagents::Types::RefineConfig.new(
        max_iterations: 2, feedback_source: :execution, min_confidence: 0.8, enabled: true
      )

      result = instance.send(:attempt_refinement, step, "task")

      expect(result.iterations).to be <= 2
    end
  end

  describe "#run_refinement_loop" do
    let(:step) do
      Smolagents::Types::ActionStep.new(
        step_number: 1,
        error: nil,
        action_output: "initial"
      )
    end

    it "collects feedback history" do
      state = described_class::RefinementState.from_output("initial")

      instance.send(:run_refinement_loop, state, step, "task")

      expect(state.feedback_history).not_to be_empty
    end

    it "updates current output when refined" do
      state = described_class::RefinementState.from_output("initial")

      instance.send(:run_refinement_loop, state, step, "task")

      expect(state.current).not_to eq("initial")
    end

    it "respects max iterations" do
      instance.refine_config = Smolagents::Types::RefineConfig.new(
        max_iterations: 1, feedback_source: :execution, min_confidence: 0.8, enabled: true
      )
      state = described_class::RefinementState.from_output("initial")

      instance.send(:run_refinement_loop, state, step, "task")

      expect(state.iterations).to be <= 1
    end

    it "stops when feedback is not actionable" do
      non_actionable_class = Class.new do
        include Smolagents::Concerns::SelfRefine::Loop

        attr_accessor :refine_config, :logger, :event_queue

        def initialize
          @refine_config = Smolagents::Types::RefineConfig.default
        end

        def refinement_feedback_for(_output, _step, _task, iteration)
          Smolagents::Types::RefinementFeedback.new(
            iteration:,
            source: :execution,
            critique: "Looks good",
            actionable: false,
            confidence: 0.9
          )
        end

        def apply_refinement(current, _feedback, _task)
          "refined_#{current}"
        end
      end

      non_actionable_instance = non_actionable_class.new
      state = described_class::RefinementState.from_output("initial")

      non_actionable_instance.send(:run_refinement_loop, state, step, "task")

      expect(state.iterations).to eq(0)
    end

    it "stops when refinement produces same output" do
      no_change_class = Class.new do
        include Smolagents::Concerns::SelfRefine::Loop

        attr_accessor :refine_config, :logger, :event_queue

        def initialize
          @refine_config = Smolagents::Types::RefineConfig.default
        end

        def refinement_feedback_for(_output, _step, _task, iteration)
          Smolagents::Types::RefinementFeedback.new(
            iteration:,
            source: :execution,
            critique: "Needs improvement",
            actionable: true,
            confidence: 0.7
          )
        end

        def apply_refinement(current, _feedback, _task) = current
      end

      no_change_instance = no_change_class.new
      state = described_class::RefinementState.from_output("initial")

      no_change_instance.send(:run_refinement_loop, state, step, "task")

      expect(state.iterations).to eq(1)
    end
  end

  describe "#build_refinement_result" do
    it "creates result from state" do
      state = described_class::RefinementState.from_output("original")
      state.current = "refined"
      state.iterations = 2
      state.feedback_history << Smolagents::Types::RefinementFeedback.new(
        iteration: 0, source: :self, critique: "Fix", actionable: true, confidence: 0.7
      )

      result = instance.send(:build_refinement_result, state)

      expect(result.original).to eq("original")
      expect(result.refined).to eq("refined")
      expect(result.iterations).to eq(2)
      expect(result.improved).to be true
    end
  end

  describe "#execute_refinement_if_needed" do
    let(:step) do
      Smolagents::Types::ActionStep.new(
        step_number: 1,
        error: nil,
        action_output: "output",
        final_answer: false
      )
    end

    it "returns nil when disabled" do
      instance.refine_config = Smolagents::Types::RefineConfig.disabled

      result = instance.send(:execute_refinement_if_needed, step, "task")

      expect(result).to be_nil
    end

    it "returns nil for final answer steps" do
      final_step = Smolagents::Types::ActionStep.new(
        step_number: 1,
        error: nil,
        action_output: "done",
        final_answer: true
      )

      result = instance.send(:execute_refinement_if_needed, final_step, "task")

      expect(result).to be_nil
    end

    it "returns RefinementResult when enabled" do
      result = instance.send(:execute_refinement_if_needed, step, "task")

      expect(result).to be_a(Smolagents::Types::RefinementResult)
    end

    it "yields result to block when given" do
      yielded = nil

      instance.send(:execute_refinement_if_needed, step, "task") do |result|
        yielded = result
      end

      expect(yielded).to be_a(Smolagents::Types::RefinementResult)
    end

    it "logs refinement results" do
      # This test verifies logging happens - since the result is improved,
      # we expect info to be called with the improvement message
      instance.send(:execute_refinement_if_needed, step, "task")

      expect(mock_logger).to have_received(:info).with("Refinement improved output", hash_including(:iterations))
    end
  end

  describe "#log_refinement_result" do
    it "logs info for improved results" do
      result = Smolagents::Types::RefinementResult.new(
        original: "a", refined: "b", iterations: 1,
        feedback_history: [], improved: true, confidence: 0.9
      )

      instance.send(:log_refinement_result, result)

      expect(mock_logger).to have_received(:info).with("Refinement improved output", iterations: 1)
    end

    it "logs debug for non-improved refined results" do
      result = Smolagents::Types::RefinementResult.new(
        original: "a", refined: "a", iterations: 1,
        feedback_history: [], improved: false, confidence: 0.9
      )

      instance.send(:log_refinement_result, result)

      expect(mock_logger).to have_received(:debug).with("Refinement attempted but no improvement", iterations: 1)
    end

    it "does nothing without logger" do
      no_logger_instance = test_class.new(logger: nil)
      result = Smolagents::Types::RefinementResult.new(
        original: "a", refined: "b", iterations: 1,
        feedback_history: [], improved: true, confidence: 0.9
      )

      expect { no_logger_instance.send(:log_refinement_result, result) }.not_to raise_error
    end
  end
end
