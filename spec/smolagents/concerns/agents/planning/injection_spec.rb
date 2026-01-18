RSpec.describe Smolagents::Concerns::Planning::Injection do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Planning::Injection

      attr_accessor :planning_interval, :plan_context

      def initialize(planning_interval: nil, plan_context: nil)
        @planning_interval = planning_interval
        @plan_context = plan_context
      end
    end
  end

  let(:plan_context) do
    Smolagents::Types::PlanContext.initial("1. Search for data\n2. Process results\n3. Return answer")
  end

  describe "#build_plan_reminder_message" do
    context "when planning is disabled" do
      it "returns nil when planning_interval is nil" do
        instance = test_class.new(planning_interval: nil, plan_context:)
        expect(instance.send(:build_plan_reminder_message)).to be_nil
      end

      it "returns nil when planning_interval is zero" do
        instance = test_class.new(planning_interval: 0, plan_context:)
        expect(instance.send(:build_plan_reminder_message)).to be_nil
      end
    end

    context "when plan context is not initialized" do
      it "returns nil" do
        uninitialized = Smolagents::Types::PlanContext.uninitialized
        instance = test_class.new(planning_interval: 3, plan_context: uninitialized)
        expect(instance.send(:build_plan_reminder_message)).to be_nil
      end
    end

    context "when plan is empty" do
      it "returns nil" do
        empty_plan = Smolagents::Types::PlanContext.initial("")
        instance = test_class.new(planning_interval: 3, plan_context: empty_plan)
        expect(instance.send(:build_plan_reminder_message)).to be_nil
      end
    end

    context "when planning is enabled with valid plan" do
      it "returns a system message with plan content" do
        instance = test_class.new(planning_interval: 3, plan_context:)
        message = instance.send(:build_plan_reminder_message)

        expect(message).to be_a(Smolagents::Types::ChatMessage)
        expect(message.role).to eq(:system)
        expect(message.content).to include("CURRENT PLAN:")
        expect(message.content).to include("Search for data")
      end
    end
  end

  describe "#inject_plan_into_messages" do
    let(:instance) { test_class.new(planning_interval: 3, plan_context:) }
    let(:messages) do
      [
        Smolagents::Types::ChatMessage.system("You are an assistant"),
        Smolagents::Types::ChatMessage.user("Find some data")
      ]
    end

    context "when planning is enabled" do
      it "injects plan reminder before the last user message" do
        result = instance.send(:inject_plan_into_messages, messages)

        expect(result.length).to eq(3)
        expect(result[0].role).to eq(:system)
        expect(result[1].content).to include("CURRENT PLAN:")
        expect(result[2].role).to eq(:user)
      end
    end

    context "when planning is disabled" do
      it "returns messages unchanged" do
        disabled_instance = test_class.new(planning_interval: nil, plan_context:)
        result = disabled_instance.send(:inject_plan_into_messages, messages)

        expect(result).to eq(messages)
      end
    end
  end
end
