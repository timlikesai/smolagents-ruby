require "smolagents"

RSpec.describe Smolagents::Concerns::Planning do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Planning

      attr_accessor :model, :tools, :memory

      def initialize(model:, tools: [], planning_interval: nil, planning_templates: nil)
        @model = model
        @tools = tools
        @memory = Smolagents::AgentMemory.new("You are a helpful assistant.")
        initialize_planning(planning_interval: planning_interval, planning_templates: planning_templates)
      end
    end
  end

  let(:mock_token_usage) { Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50) }

  let(:mock_model) do
    instance_double(Smolagents::Model).tap do |m|
      allow(m).to receive(:generate).and_return(
        Smolagents::ChatMessage.assistant("1. Step one\n2. Step two\n3. Step three", token_usage: mock_token_usage)
      )
    end
  end

  let(:mock_tool) do
    instance_double(Smolagents::Tool, name: "search", description: "Search the web")
  end

  describe "TEMPLATES" do
    it "includes initial_plan template" do
      expect(described_class::TEMPLATES[:initial_plan]).to include("%<task>s")
      expect(described_class::TEMPLATES[:initial_plan]).to include("%<tools>s")
    end

    it "includes update_plan_pre template" do
      expect(described_class::TEMPLATES[:update_plan_pre]).to include("%<task>s")
    end

    it "includes update_plan_post template" do
      expect(described_class::TEMPLATES[:update_plan_post]).to include("%<steps>s")
      expect(described_class::TEMPLATES[:update_plan_post]).to include("%<observations>s")
      expect(described_class::TEMPLATES[:update_plan_post]).to include("%<plan>s")
    end

    it "includes planning_system template" do
      expect(described_class::TEMPLATES[:planning_system]).to be_a(String)
    end
  end

  describe ".configure_planning_templates" do
    it "allows overriding default templates" do
      custom_class = Class.new do
        include Smolagents::Concerns::Planning
      end

      custom_class.configure_planning_templates(
        initial_plan: "Custom plan: %<task>s"
      )

      expect(custom_class.default_planning_templates[:initial_plan]).to eq("Custom plan: %<task>s")
      expect(custom_class.default_planning_templates[:update_plan_pre]).to eq(described_class::TEMPLATES[:update_plan_pre])
    end
  end

  describe "#initialize_planning" do
    it "sets planning_interval" do
      agent = test_class.new(model: mock_model, planning_interval: 3)
      expect(agent.planning_interval).to eq(3)
    end

    it "uses default templates when none provided" do
      agent = test_class.new(model: mock_model)
      expect(agent.planning_templates).to eq(described_class::TEMPLATES)
    end

    it "accepts custom templates" do
      custom = { initial_plan: "Custom: %<task>s", planning_system: "Custom system" }
      agent = test_class.new(model: mock_model, planning_templates: custom)
      expect(agent.planning_templates[:initial_plan]).to eq("Custom: %<task>s")
    end

    it "freezes the templates" do
      agent = test_class.new(model: mock_model)
      expect(agent.planning_templates).to be_frozen
    end
  end

  describe "#execute_planning_step_if_needed" do
    let(:agent) { test_class.new(model: mock_model, tools: [mock_tool], planning_interval: 2) }

    context "when planning_interval is nil" do
      let(:agent) { test_class.new(model: mock_model) }

      it "does not execute planning" do
        expect(mock_model).not_to receive(:generate)
        agent.send(:execute_planning_step_if_needed, "task", nil, 2)
      end
    end

    context "when step is not at interval but plan is uninitialized" do
      it "executes initial planning" do
        expect(mock_model).to receive(:generate)
        agent.send(:execute_planning_step_if_needed, "task", nil, 1)
      end
    end

    context "when plan is initialized and step is not at interval" do
      before do
        agent.send(:execute_planning_step_if_needed, "task", nil, 2)
      end

      it "does not execute planning" do
        expect(mock_model).not_to receive(:generate)
        agent.send(:execute_planning_step_if_needed, "task", nil, 3)
      end
    end

    context "when step is at interval" do
      it "executes initial planning on first call" do
        expect(mock_model).to receive(:generate)
        agent.send(:execute_planning_step_if_needed, "task", nil, 2)
        expect(agent.memory.steps.last).to be_a(Smolagents::PlanningStep)
      end

      it "executes update planning on subsequent calls" do
        agent.send(:execute_planning_step_if_needed, "task", nil, 2)

        last_step = Smolagents::ActionStep.new(step_number: 1, observations: "Found results")
        agent.send(:execute_planning_step_if_needed, "task", last_step, 4)

        expect(agent.memory.steps.size).to eq(2)
      end

      it "yields token usage when block given" do
        yielded_usage = nil
        agent.send(:execute_planning_step_if_needed, "task", nil, 2) do |usage|
          yielded_usage = usage
        end
        expect(yielded_usage).not_to be_nil
      end
    end
  end

  describe "#execute_initial_planning_step" do
    let(:agent) { test_class.new(model: mock_model, tools: [mock_tool], planning_interval: 1) }

    it "generates initial plan with tools description" do
      expect(mock_model).to receive(:generate).with(
        array_including(
          having_attributes(role: Smolagents::MessageRole::SYSTEM),
          having_attributes(role: Smolagents::MessageRole::USER)
        )
      )

      agent.send(:execute_initial_planning_step, "Find information", 1)
    end

    it "returns a PlanningStep" do
      step = agent.send(:execute_initial_planning_step, "task", 1)
      expect(step).to be_a(Smolagents::PlanningStep)
      expect(step.plan).to include("Step one")
    end

    it "stores the current plan in plan_context" do
      agent.send(:execute_initial_planning_step, "task", 1)
      expect(agent.send(:current_plan)).to include("Step one")
      expect(agent.send(:plan_context)).to be_a(Smolagents::PlanContext)
    end
  end

  describe "#execute_update_planning_step" do
    let(:agent) { test_class.new(model: mock_model, tools: [mock_tool], planning_interval: 1) }

    before do
      agent.send(:execute_initial_planning_step, "task", 1)
    end

    it "includes previous steps in the update" do
      action_step = Smolagents::ActionStep.new(step_number: 1, observations: "Found 5 results")
      agent.memory.add_step(action_step)

      expect(mock_model).to receive(:generate).with(
        array_including(
          having_attributes(content: include("Found 5 results"))
        )
      )

      agent.send(:execute_update_planning_step, "task", action_step, 2)
    end

    it "includes current plan in the update" do
      action_step = Smolagents::ActionStep.new(step_number: 1, observations: "observations")

      expect(mock_model).to receive(:generate).with(
        array_including(
          having_attributes(content: include("Step one"))
        )
      )

      agent.send(:execute_update_planning_step, "task", action_step, 2)
    end
  end

  describe "#step_summaries" do
    let(:agent) { test_class.new(model: mock_model, planning_interval: 1) }

    it "returns a lazy enumerator" do
      expect(agent.send(:step_summaries)).to be_a(Enumerator::Lazy)
    end

    it "yields summaries lazily" do
      yielded_count = 0
      tracking_enumerator = Enumerator.new do |y|
        3.times do |i|
          yielded_count += 1
          y << Smolagents::ActionStep.new(step_number: i + 1, observations: "Obs #{i + 1}")
        end
      end

      allow(agent.memory).to receive(:action_steps).and_return(tracking_enumerator.lazy)

      summaries = agent.send(:step_summaries)
      first_summary = summaries.first

      expect(first_summary).to include("Step 1:")
      expect(yielded_count).to eq(1)
    end

    it "uses pattern matching to extract step data" do
      step = Smolagents::ActionStep.new(step_number: 5, observations: "Test observation")
      agent.memory.add_step(step)

      summary = agent.send(:step_summaries).first
      expect(summary).to eq("Step 5: Test observation...")
    end
  end

  describe "#summarize_steps" do
    let(:agent) { test_class.new(model: mock_model, planning_interval: 1) }

    it "returns empty string when no action steps" do
      expect(agent.send(:summarize_steps)).to eq("")
    end

    it "summarizes action steps" do
      step = Smolagents::ActionStep.new(step_number: 1, observations: "Found important data in the search results")
      agent.memory.add_step(step)

      summary = agent.send(:summarize_steps)
      expect(summary).to include("Step 1:")
      expect(summary).to include("Found important data")
    end

    it "truncates long observations" do
      long_obs = "x" * 200
      step = Smolagents::ActionStep.new(step_number: 1, observations: long_obs)
      agent.memory.add_step(step)

      summary = agent.send(:summarize_steps)
      expect(summary.length).to be < 150
      expect(summary).to include("...")
    end

    it "accepts a limit parameter" do
      5.times do |i|
        step = Smolagents::ActionStep.new(step_number: i + 1, observations: "Observation #{i + 1}")
        agent.memory.add_step(step)
      end

      summary = agent.send(:summarize_steps, limit: 2)
      expect(summary).to include("Step 1:")
      expect(summary).to include("Step 2:")
      expect(summary).not_to include("Step 3:")
    end

    it "processes only required steps with limit" do
      processed_count = 0
      tracking_enumerator = Enumerator.new do |y|
        10.times do |i|
          processed_count += 1
          y << Smolagents::ActionStep.new(step_number: i + 1, observations: "Obs #{i + 1}")
        end
      end

      allow(agent.memory).to receive(:action_steps).and_return(tracking_enumerator.lazy)

      agent.send(:summarize_steps, limit: 3)
      expect(processed_count).to eq(3)
    end
  end
end
