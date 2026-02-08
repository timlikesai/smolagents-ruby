require "smolagents/concerns/agents/react_loop/execution/loop"

RSpec.describe Smolagents::Concerns::ReActLoop::Execution::Loop do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ReActLoop::Execution::Loop

      attr_accessor :max_steps, :logger, :memory, :ctx

      def finalize(outcome, output, ctx, memory:)
        Smolagents::Types::RunResult.success(output: output || "done", steps: [])
      end

      def finalize_error(error, ctx, memory:)
        Smolagents::Types::RunResult.error(output: error.message, steps: [])
      end

      def prepare_task(task, additional_prompting:, images:); end

      def execute_step_with_monitoring(task, ctx, memory:)
        step = Smolagents::Types::ActionStep.new(step_number: ctx.step_number)
        [step, ctx]
      end

      def check_and_handle_repetition(steps, memory:); end
    end
  end

  let(:instance) do
    obj = test_class.new
    obj.max_steps = 10
    obj.logger = double("logger", info: nil, debug: nil, warn: nil)
    obj.memory = double("memory", action_steps: [], add_step: nil)
    obj
  end

  describe "no-op stubs" do
    it "provides should_execute_initial_planning? stub" do
      result = instance.send(:should_execute_initial_planning?)

      expect(result).to be false
    end

    it "provides should_execute_planning_update? stub" do
      result = instance.send(:should_execute_planning_update?, 5)

      expect(result).to be false
    end

    it "provides execute_evaluation_if_needed stub" do
      result = instance.send(:execute_evaluation_if_needed, "task", double("step"), 1)

      expect(result).to be_nil
    end

    it "provides validate_completion stub" do
      result = instance.send(:validate_completion, double("step"), "task")

      expect(result).to be true
    end

    it "provides check_token_budget_if_enabled stub" do
      result = instance.send(:check_token_budget_if_enabled)

      expect(result).to be_nil
    end
  end

  describe "#with_fiber_context" do
    it "sets fiber context during block execution" do
      result = instance.send(:with_fiber_context) do
        Smolagents::Concerns::ReActLoop::Control::FiberControl.set_fiber_context(true)
        "inside block"
      end

      expect(result).to eq("inside block")
    end

    it "cleans up fiber context after block" do
      instance.send(:with_fiber_context) do
        Smolagents::Concerns::ReActLoop::Control::FiberControl.set_fiber_context(true)
      end

      # After block, context should be cleared
      expect(Thread.current.thread_variable_get(:smolagents_fiber_context)).to be_falsey
    end
  end

  describe "#after_step" do
    let(:step) { double("step") }
    let(:ctx) { double("context", step_number: 1, advance: double("next_ctx")) }

    it "advances the context" do
      result = instance.send(:after_step, "task", step, ctx)

      expect(result).to eq(ctx.advance)
    end
  end

  describe "#evaluation_answer" do
    let(:step) { double("step", action_output: "step output") }

    it "prefers step action_output over evaluator answer" do
      evaluation_result = double("eval", answer: "eval answer")

      result = instance.send(:evaluation_answer, step, evaluation_result)

      expect(result).to eq("step output")
    end

    it "falls back to evaluator answer when action_output is nil" do
      step_nil = double("step", action_output: nil)
      evaluation_result = double("eval", answer: "eval answer")

      result = instance.send(:evaluation_answer, step_nil, evaluation_result)

      expect(result).to eq("eval answer")
    end
  end
end
