require "spec_helper"

# rubocop:disable RSpec/DescribeClass -- integration test for event emission

RSpec.describe "Planning Events" do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Tools::Registry
      include Smolagents::Concerns::Planning
      include Smolagents::Events::Consumer

      attr_accessor :model, :memory

      def initialize(model:, tools: [], planning_interval: nil)
        @model = model
        @tools = tools.to_h { |tool| [tool.name, tool] }
        @memory = Smolagents::AgentMemory.new("You are a helpful assistant.")
        initialize_planning(planning_interval:)
      end
    end
  end

  let(:mock_token_usage) { Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50) }

  let(:mock_model) do
    instance_double(Smolagents::Model, model_id: "test-model").tap do |m|
      allow(m).to receive(:generate).and_return(
        Smolagents::ChatMessage.assistant(
          "1. Search for information\n2. Analyze results\n3. Summarize findings",
          token_usage: mock_token_usage
        )
      )
    end
  end

  let(:mock_tool) do
    instance_double(Smolagents::Tool, name: "search", description: "Search the web")
  end

  before do
    Smolagents::Events::CreateFactory.reset_sequence!
  end

  describe "PlanEvent (phase: :generated)" do
    it "is emitted when initial plan is created" do
      agent = test_class.new(model: mock_model, tools: [mock_tool], planning_interval: 3)
      received = []
      agent.on(:plan_event) { |e| received << e if e.generated? }

      agent.send(:execute_initial_planning, "Find Ruby release notes")

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.size).to eq(1)
      event = received.first
      expect(event).to be_a(Smolagents::Events::PlanEvent)
    end

    it "includes the parsed plan content" do
      agent = test_class.new(model: mock_model, tools: [mock_tool], planning_interval: 3)
      received = []
      agent.on(:plan_event) { |e| received << e if e.generated? }

      agent.send(:execute_initial_planning, "Find Ruby release notes")

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      event = received.first
      expect(event.plan).to include("Search for information")
      expect(event.plan).to include("Analyze results")
    end

    it "includes the step count from the plan" do
      agent = test_class.new(model: mock_model, tools: [mock_tool], planning_interval: 3)
      received = []
      agent.on(:plan_event) { |e| received << e if e.generated? }

      agent.send(:execute_initial_planning, "Find Ruby release notes")

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      event = received.first
      expect(event.step_count).to eq(3)
    end

    it "includes the model_id" do
      agent = test_class.new(model: mock_model, tools: [mock_tool], planning_interval: 3)
      received = []
      agent.on(:plan_event) { |e| received << e if e.generated? }

      agent.send(:execute_initial_planning, "Find Ruby release notes")

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      event = received.first
      expect(event.model_id).to eq("test-model")
    end

    it "handles model without model_id method gracefully" do
      model_without_id = Object.new.tap do |m|
        def m.generate(_messages)
          Smolagents::ChatMessage.assistant(
            "1. Step one",
            token_usage: Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50)
          )
        end
      end

      agent = test_class.new(model: model_without_id, tools: [mock_tool], planning_interval: 3)
      received = []
      agent.on(:plan_event) { |e| received << e if e.generated? }

      agent.send(:execute_initial_planning, "Task")

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      event = received.first
      expect(event.model_id).to be_nil
    end
  end

  describe "PlanEvent (phase: :updated)" do
    let(:agent) { test_class.new(model: mock_model, tools: [mock_tool], planning_interval: 2) }

    before do
      agent.send(:execute_initial_planning, "Find Ruby release notes")
      Smolagents::Events::AsyncQueue.drain(timeout: 1)
    end

    it "is emitted when plan is updated on replan" do
      received = []
      agent.on(:plan_event) { |e| received << e if e.updated? }

      last_step = Smolagents::ActionStep.new(step_number: 1, observations: "Found results")
      agent.send(:execute_planning_update, "Find Ruby release notes", last_step, 2)

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.size).to eq(1)
      event = received.first
      expect(event).to be_a(Smolagents::Events::PlanEvent)
    end

    it "includes the new plan content" do
      received = []
      agent.on(:plan_event) { |e| received << e if e.updated? }

      last_step = Smolagents::ActionStep.new(step_number: 1, observations: "Found results")
      agent.send(:execute_planning_update, "Find Ruby release notes", last_step, 2)

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      event = received.first
      expect(event.plan).to include("Search for information")
    end

    it "includes the previous plan" do
      # Capture the original plan before update
      original_plan = agent.send(:current_plan)

      received = []
      agent.on(:plan_event) { |e| received << e if e.updated? }

      last_step = Smolagents::ActionStep.new(step_number: 1, observations: "Found results")
      agent.send(:execute_planning_update, "Find Ruby release notes", last_step, 2)

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      event = received.first
      expect(event.previous_plan).to eq(original_plan)
    end

    it "includes the step number" do
      received = []
      agent.on(:plan_event) { |e| received << e if e.updated? }

      last_step = Smolagents::ActionStep.new(step_number: 1, observations: "Found results")
      agent.send(:execute_planning_update, "Find Ruby release notes", last_step, 4)

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      event = received.first
      expect(event.step_number).to eq(4)
    end

    it "includes the reason for update" do
      received = []
      agent.on(:plan_event) { |e| received << e if e.updated? }

      last_step = Smolagents::ActionStep.new(step_number: 1, observations: "Found results")
      agent.send(:execute_planning_update, "Find Ruby release notes", last_step, 2)

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      event = received.first
      expect(event.reason).to eq("periodic_replan")
    end
  end

  describe "event mapping resolution" do
    it "resolves :plan_event to PlanEvent" do
      event_class = Smolagents::Events::Mappings.resolve(:plan_event)
      expect(event_class).to eq(Smolagents::Events::PlanEvent)
    end
  end

  describe "event creation via factory" do
    it "creates PlanEvent with phase: :generated and required fields" do
      event = Smolagents::Events::PlanEvent.create(
        plan: "1. Step one\n2. Step two",
        phase: :generated,
        step_count: 2,
        model_id: "gpt-4"
      )

      expect(event.plan).to eq("1. Step one\n2. Step two")
      expect(event.phase).to eq(:generated)
      expect(event.step_count).to eq(2)
      expect(event.model_id).to eq("gpt-4")
      expect(event.id).not_to be_nil
      expect(event.created_at).to be_a(Time)
    end

    it "creates PlanEvent with phase: :updated and required fields" do
      event = Smolagents::Events::PlanEvent.create(
        plan: "1. New step",
        phase: :updated,
        previous_plan: "1. Old step",
        reason: "periodic_replan",
        step_number: 5
      )

      expect(event.plan).to eq("1. New step")
      expect(event.phase).to eq(:updated)
      expect(event.previous_plan).to eq("1. Old step")
      expect(event.reason).to eq("periodic_replan")
      expect(event.step_number).to eq(5)
    end

    it "allows nil model_id in PlanEvent" do
      event = Smolagents::Events::PlanEvent.create(
        plan: "1. Step",
        phase: :generated,
        step_count: 1
      )

      expect(event.model_id).to be_nil
    end

    it "allows nil reason in PlanEvent" do
      event = Smolagents::Events::PlanEvent.create(
        plan: "1. New step",
        phase: :updated,
        previous_plan: "1. Old step",
        step_number: 5
      )

      expect(event.reason).to be_nil
    end
  end
end
# rubocop:enable RSpec/DescribeClass
