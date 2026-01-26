require "smolagents/concerns/agents/completion_validation"

RSpec.describe Smolagents::Concerns::CompletionValidation do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::CompletionValidation

      attr_accessor :max_steps, :plan_context, :custom_validators

      def initialize
        @max_steps = 10
        @plan_context = nil
        @custom_validators = []
      end

      def plan_steps_complete? = true

      def calculate_plan_incomplete_steps
        []
      end

      def run_custom_validators(step, task) = nil

      def inject_completion_rejection(rejection, memory:)
        # No-op for testing
      end

      def validate_goal_alignment(step, task) = nil
    end
  end

  let(:instance) { test_class.new }
  let(:step) { double("step", answer: "test answer") }
  let(:task) { "Complete the task" }
  let(:memory) { double("memory") }

  describe Smolagents::Types::ValidationRejection do
    it "has reason and guidance fields" do
      rejection = described_class.new(reason: "test reason", guidance: "test guidance")
      expect(rejection.reason).to eq("test reason")
      expect(rejection.guidance).to eq("test guidance")
    end
  end

  describe "#validate_completion" do
    context "when validators return nil (no rejection)" do
      it "returns true" do
        result = instance.send(:validate_completion, step, task, memory:)
        expect(result).to be true
      end
    end

    context "when plan validation fails" do
      before do
        instance.plan_context = double("context", initialized?: true)
        allow(instance).to receive(:plan_steps_complete?).and_return(false)
      end

      it "returns false" do
        result = instance.send(:validate_completion, step, task, memory:)
        expect(result).to be false
      end

      it "injects rejection feedback" do
        allow(instance).to receive(:inject_completion_rejection)
        instance.send(:validate_completion, step, task, memory:)
        expect(instance).to have_received(:inject_completion_rejection).with(
          instance_of(Smolagents::Types::ValidationRejection),
          memory:
        )
      end
    end

    context "when custom validators fail" do
      before do
        allow(instance).to receive(:run_custom_validators).and_return(
          Smolagents::Types::ValidationRejection.new(
            reason: "Custom validation failed",
            guidance: "Try again"
          )
        )
      end

      it "returns false" do
        result = instance.send(:validate_completion, step, task, memory:)
        expect(result).to be false
      end
    end
  end

  describe "#run_completion_validators" do
    it "chains validators returning first rejection or nil" do
      allow(instance).to receive_messages(validate_plan_complete: nil, validate_goal_alignment: nil,
                                          run_custom_validators: nil)

      result = instance.send(:run_completion_validators, step, task)
      expect(result).to be_nil
    end

    it "returns first rejection from any validator" do
      rejection = Smolagents::Types::ValidationRejection.new(
        reason: "test",
        guidance: "fix it"
      )
      allow(instance).to receive_messages(validate_plan_complete: rejection, validate_goal_alignment: nil)

      result = instance.send(:run_completion_validators, step, task)
      expect(result).to eq(rejection)
    end
  end

  describe "#validate_plan_complete" do
    context "when planning is not enabled" do
      before do
        instance.plan_context = nil
      end

      it "returns nil" do
        result = instance.send(:validate_plan_complete, step, task)
        expect(result).to be_nil
      end
    end

    context "when plan context exists but is not initialized" do
      before do
        instance.plan_context = double("context", initialized?: false)
      end

      it "returns nil" do
        result = instance.send(:validate_plan_complete, step, task)
        expect(result).to be_nil
      end
    end

    context "when all plan steps are complete" do
      before do
        instance.plan_context = double("context", initialized?: true)
        allow(instance).to receive(:plan_steps_complete?).and_return(true)
      end

      it "returns nil" do
        result = instance.send(:validate_plan_complete, step, task)
        expect(result).to be_nil
      end
    end

    context "when plan steps are incomplete" do
      before do
        instance.plan_context = double("context", initialized?: true)
        allow(instance).to receive(:plan_steps_complete?).and_return(false)
      end

      it "returns rejection" do
        result = instance.send(:validate_plan_complete, step, task)
        expect(result).to be_a(Smolagents::Types::ValidationRejection)
        expect(result.reason).to eq("Plan has incomplete steps")
      end
    end
  end

  describe "validation flow" do
    it "calls validators in order: plan, goal, custom" do
      call_order = []
      allow(instance).to receive(:validate_plan_complete) {
        call_order << :plan
        nil
      }
      allow(instance).to receive(:validate_goal_alignment) {
        call_order << :goal
        nil
      }
      allow(instance).to receive(:run_custom_validators) {
        call_order << :custom
        nil
      }

      instance.send(:run_completion_validators, step, task)
      expect(call_order).to eq(%i[plan goal custom])
    end
  end
end
