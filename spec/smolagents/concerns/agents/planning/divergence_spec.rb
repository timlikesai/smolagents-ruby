# -- Step/ToolCall are internal interfaces
RSpec.describe Smolagents::Concerns::Planning::Divergence do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Concerns::Planning::Divergence

      attr_accessor :planning_interval, :plan_context

      def initialize(planning_interval: nil, plan_context: nil)
        @planning_interval = planning_interval
        @plan_context = plan_context
        initialize_divergence_tracking
      end
    end
  end

  let(:plan_context) do
    Smolagents::Types::PlanContext.initial("1. Use search tool\n2. Process with calculator\n3. Return answer")
  end

  describe "#initialize_divergence_tracking" do
    it "initializes tracking state" do
      instance = test_class.new(planning_interval: 3, plan_context:)

      expect(instance.instance_variable_get(:@off_topic_steps)).to eq(0)
      expect(instance.instance_variable_get(:@last_plan_alignment)).to eq(1.0)
    end
  end

  describe "#estimate_step_alignment" do
    let(:instance) { test_class.new(planning_interval: 3, plan_context:) }

    context "when step has no tracking info" do
      it "returns 1.0" do
        step = double("step")
        expect(instance.send(:estimate_step_alignment, step)).to eq(1.0)
      end
    end

    context "when plan is nil" do
      it "returns 1.0" do
        nil_plan = Smolagents::Types::PlanContext.uninitialized
        nil_instance = test_class.new(planning_interval: 3, plan_context: nil_plan)
        step = double("step", tool_calls: [], observations: "obs")

        expect(nil_instance.send(:estimate_step_alignment, step)).to eq(1.0)
      end
    end

    context "when tool is mentioned in plan" do
      it "returns 1.0" do
        tool_call = double("tool_call", name: "search")
        step = double("step", tool_calls: [tool_call], observations: "result", is_final_answer: false)

        expect(instance.send(:estimate_step_alignment, step)).to eq(1.0)
      end
    end

    context "when step is final answer" do
      it "returns 1.0" do
        step = double("step", tool_calls: [], observations: "result", is_final_answer: true)

        expect(instance.send(:estimate_step_alignment, step)).to eq(1.0)
      end
    end

    context "when tool is not in plan" do
      it "returns 0.4" do
        tool_call = double("tool_call", name: "unrelated_tool")
        step = double("step", tool_calls: [tool_call], observations: "result", is_final_answer: false)

        expect(instance.send(:estimate_step_alignment, step)).to eq(0.4)
      end
    end
  end

  describe "#divergence_level" do
    let(:instance) { test_class.new(planning_interval: 3, plan_context:) }

    it "returns nil for 0 off-topic steps" do
      instance.instance_variable_set(:@off_topic_steps, 0)
      expect(instance.send(:divergence_level)).to be_nil
    end

    it "returns :mild for 1-2 off-topic steps" do
      instance.instance_variable_set(:@off_topic_steps, 1)
      expect(instance.send(:divergence_level)).to eq(:mild)

      instance.instance_variable_set(:@off_topic_steps, 2)
      expect(instance.send(:divergence_level)).to eq(:mild)
    end

    it "returns :moderate for 3-4 off-topic steps" do
      instance.instance_variable_set(:@off_topic_steps, 3)
      expect(instance.send(:divergence_level)).to eq(:moderate)

      instance.instance_variable_set(:@off_topic_steps, 4)
      expect(instance.send(:divergence_level)).to eq(:moderate)
    end

    it "returns :severe for 5+ off-topic steps" do
      instance.instance_variable_set(:@off_topic_steps, 5)
      expect(instance.send(:divergence_level)).to eq(:severe)

      instance.instance_variable_set(:@off_topic_steps, 10)
      expect(instance.send(:divergence_level)).to eq(:severe)
    end
  end

  describe "#track_plan_alignment" do
    let(:instance) { test_class.new(planning_interval: 3, plan_context:) }

    context "when planning is disabled" do
      it "does nothing" do
        disabled_instance = test_class.new(planning_interval: nil, plan_context:)
        step = double("step")

        expect { disabled_instance.send(:track_plan_alignment, step, "task") }.not_to raise_error
      end
    end

    context "when step aligns with plan" do
      it "decrements off_topic_steps counter" do
        tool_call = double("tool_call", name: "search")
        step = double("step", tool_calls: [tool_call], observations: "result", is_final_answer: false)

        instance.instance_variable_set(:@off_topic_steps, 2)
        instance.send(:track_plan_alignment, step, "task")

        expect(instance.instance_variable_get(:@off_topic_steps)).to eq(1)
      end
    end

    context "when step diverges from plan" do
      it "increments off_topic_steps counter" do
        tool_call = double("tool_call", name: "unrelated")
        step = double("step", tool_calls: [tool_call], observations: "result", is_final_answer: false)

        instance.send(:track_plan_alignment, step, "task")

        expect(instance.instance_variable_get(:@off_topic_steps)).to eq(1)
      end
    end
  end
end
