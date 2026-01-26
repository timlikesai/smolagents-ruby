require "spec_helper"

RSpec.describe Smolagents::Concerns::GoalDrivenLoop do
  # Mock action step
  let(:action_step) do
    Smolagents::ActionStep.new(
      step_number: 1,
      action_output: "Found 3 results for Ruby documentation"
    )
  end

  let(:empty_step) do
    Smolagents::ActionStep.new(step_number: 1, action_output: nil)
  end

  let(:goal) do
    Smolagents::Types::Goal.create(description: "Find Ruby documentation")
  end

  let(:completed_goal) do
    goal.complete(evidence: "Found the docs")
  end

  # Test class that includes the concern chain
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Concerns::GoalTracking
      include Smolagents::Concerns::GoalDrivenLoop

      attr_accessor :emitted_events

      def initialize
        initialize_goal_tracking
        @emitted_events = []
      end

      # Capture events for test assertions
      def emit(event)
        @emitted_events << event
        super
      end

      # Stub for super call
      def after_step_original(_task, _step, ctx) = ctx.advance

      # Override to call original
      def after_step(task, step, ctx)
        record_goal_progress(step) if respond_to?(:current_goal)
        after_step_original(task, step, ctx)
      end

      # Stub finalize
      def finalize(outcome, output, ctx, memory:)
        { outcome:, output:, ctx:, memory: }
      end
    end
  end

  let(:instance) { test_class.new }
  let(:ctx) { Smolagents::RunContext.start }
  let(:memory) { instance_double(Smolagents::AgentMemory) }

  describe "#after_step" do
    context "with active goal and output" do
      before do
        instance.goal_store.add(goal)
      end

      it "updates goal progress" do
        instance.after_step("Find docs", action_step, ctx)

        updated = instance.current_goal
        expect(updated.progress).to include("Found 3 results")
      end

      it "advances context" do
        new_ctx = instance.after_step("Find docs", action_step, ctx)

        expect(new_ctx.step_number).to eq(2)
      end
    end

    context "with empty step output" do
      before do
        instance.goal_store.add(goal)
      end

      it "does not update progress" do
        instance.after_step("Find docs", empty_step, ctx)

        updated = instance.current_goal
        expect(updated.progress).to be_nil
      end
    end

    context "without goal tracking" do
      let(:minimal_class) do
        Class.new do
          include Smolagents::Concerns::GoalDrivenLoop

          def after_step_original(_task, _step, ctx) = ctx.advance

          def after_step(task, step, ctx)
            record_goal_progress(step) if respond_to?(:current_goal)
            after_step_original(task, step, ctx)
          end
        end
      end

      it "works without goals" do
        minimal = minimal_class.new
        new_ctx = minimal.after_step("task", action_step, ctx)

        expect(new_ctx.step_number).to eq(2)
      end
    end
  end

  describe "#check_goal_completion" do
    context "when goal was completed during step" do
      before do
        # Add active goal, then complete it (simulating step execution)
        instance.goal_store.add(goal)
        instance.complete_goal(goal, evidence: "Found the docs")
      end

      it "returns finalize result" do
        result = instance.send(:check_goal_completion, ctx, memory)

        expect(result[:outcome]).to eq(:success)
        expect(result[:output]).to eq("Found the docs")
      end
    end

    context "when goal is still active" do
      before do
        instance.goal_store.add(goal)
      end

      it "returns nil to continue loop" do
        result = instance.send(:check_goal_completion, ctx, memory)

        expect(result).to be_nil
      end
    end

    context "without goals" do
      it "returns nil" do
        result = instance.send(:check_goal_completion, ctx, memory)

        expect(result).to be_nil
      end
    end
  end

  describe "#build_progress_note" do
    it "returns output for short strings" do
      note = instance.send(:build_progress_note, action_step)

      expect(note).to eq("Found 3 results for Ruby documentation")
    end

    it "truncates long output" do
      long_output = "x" * 150
      long_step = Smolagents::ActionStep.new(step_number: 1, action_output: long_output)

      note = instance.send(:build_progress_note, long_step)

      expect(note.length).to eq(100)
      expect(note).to end_with("...")
    end

    it "returns nil for empty output" do
      note = instance.send(:build_progress_note, empty_step)

      expect(note).to be_nil
    end
  end

  describe "event emission" do
    before do
      instance.goal_store.add(goal)
    end

    it "emits GoalProgress event after step with output" do
      instance.after_step("Find docs", action_step, ctx)

      expect(instance.emitted_events.size).to eq(1)
      expect(instance.emitted_events.first).to be_a(Smolagents::Events::GoalProgress)
    end

    it "does not emit when step has no output" do
      instance.after_step("Find docs", empty_step, ctx)

      expect(instance.emitted_events).to be_empty
    end
  end
end
