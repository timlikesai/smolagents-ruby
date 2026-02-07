require "spec_helper"

# rubocop:disable Lint/EmptyBlock -- testing registration
RSpec.describe Smolagents::Orchestrators::EventOrchestrator do
  subject(:orchestrator) { described_class.new }

  after { orchestrator.stop if orchestrator.running? }

  describe "#initialize" do
    it "creates with default configuration" do
      expect(orchestrator.config.queue_depth).to eq(500)
      expect(orchestrator.config.pool_size).to be_between(2, 8)
    end

    it "accepts custom configuration" do
      config = described_class::Config.new(
        queue_depth: 100,
        pool_size: 4,
        event_buffer_size: 500
      )
      custom = described_class.new(config:)
      expect(custom.config.queue_depth).to eq(100)
    end

    it "assigns a unique ID" do
      other = described_class.new
      expect(orchestrator.id).not_to eq(other.id)
    end
  end

  describe "lifecycle" do
    describe "#start" do
      it "starts the orchestrator" do
        orchestrator.start
        expect(orchestrator).to be_running
      end

      it "enables work queue" do
        orchestrator.start
        expect(orchestrator).to be_work_queue_enabled
      end

      it "returns self for chaining" do
        expect(orchestrator.start).to eq(orchestrator)
      end

      it "is idempotent", max_time: 0.15 do
        orchestrator.start
        orchestrator.start
        expect(orchestrator).to be_running
      end
    end

    describe "#stop" do
      before { orchestrator.start }

      it "stops the orchestrator" do
        orchestrator.stop
        expect(orchestrator).not_to be_running
      end

      it "disables work queue" do
        orchestrator.stop
        expect(orchestrator).not_to be_work_queue_enabled
      end

      it "returns self for chaining" do
        expect(orchestrator.stop).to eq(orchestrator)
      end
    end

    describe "#graceful_shutdown" do
      before { orchestrator.start }

      it "shuts down gracefully" do
        result = orchestrator.graceful_shutdown(timeout: 1)
        expect(result).to eq(orchestrator)
        expect(orchestrator).not_to be_running
      end
    end
  end

  describe "subscriptions" do
    describe "#subscribe" do
      it "registers a handler for an event type" do
        id = orchestrator.subscribe(:step_completed) { |_e| }
        expect(id).to be_a(String)
      end

      it "accepts event classes directly" do
        id = orchestrator.subscribe(Smolagents::Events::StepCompleted) { |_e| }
        expect(id).to be_a(String)
      end

      it "returns unique subscription IDs" do
        id1 = orchestrator.subscribe(:step_completed) { |_e| }
        id2 = orchestrator.subscribe(:step_completed) { |_e| }
        expect(id1).not_to eq(id2)
      end
    end

    describe "#unsubscribe" do
      it "removes a subscription" do
        id = orchestrator.subscribe(:step_completed) { |_e| }
        expect(orchestrator.unsubscribe(id)).to be true
      end

      it "returns false for unknown subscriptions" do
        expect(orchestrator.unsubscribe("unknown")).to be false
      end
    end

    describe "#subscriptions_for" do
      it "lists subscriptions for an event type" do
        id = orchestrator.subscribe(:step_completed) { |_e| }
        expect(orchestrator.subscriptions_for(:step_completed)).to include(id)
      end
    end

    describe "#clear_subscriptions" do
      it "removes all subscriptions" do
        orchestrator.subscribe(:step_completed) { |_e| }
        orchestrator.clear_subscriptions
        expect(orchestrator.subscriptions_for(:step_completed)).to be_empty
      end
    end
  end

  describe "event routing" do
    before { orchestrator.start }

    it "routes events to handlers", max_time: 0.15 do
      received = nil
      orchestrator.subscribe(:step_completed) { |e| received = e }

      event = Smolagents::Events::StepCompleted.create(
        step_number: 1, outcome: :success
      )
      orchestrator.submit_event(event)

      wait_for(timeout: 0.12) { received }
      expect(received).to eq(event)
    end

    it "invokes multiple handlers" do
      calls = []
      orchestrator.subscribe(:step_completed) { |_e| calls << 1 }
      orchestrator.subscribe(:step_completed) { |_e| calls << 2 }

      event = Smolagents::Events::StepCompleted.create(
        step_number: 1, outcome: :success
      )
      orchestrator.submit_event(event)

      wait_for { calls.size == 2 }
      expect(calls).to contain_exactly(1, 2)
    end
  end

  describe "work triggers" do
    before { orchestrator.start }

    describe "#trigger_work_on" do
      it "registers a work trigger for an event type" do
        orchestrator.trigger_work_on(Smolagents::Events::AgentStepRequested) do |event|
          Smolagents::Types::WorkItem.create(
            id: SecureRandom.uuid,
            type: :sub_agent,
            priority: :normal,
            payload: { task: event.task },
            context: {},
            created_at: Time.now
          )
        end

        expect(orchestrator).to respond_to(:trigger_work_on)
      end
    end

    describe "#remove_trigger" do
      it "removes a work trigger" do
        orchestrator.trigger_work_on(Smolagents::Events::AgentStepRequested) { nil }
        result = orchestrator.remove_trigger(Smolagents::Events::AgentStepRequested)
        expect(result).to eq(orchestrator)
      end
    end
  end

  describe "#stats" do
    before { orchestrator.start }

    it "returns combined statistics", max_time: 0.12 do
      stats = orchestrator.stats
      expect(stats).to include(:id, :running, :routing, :subscriptions, :work_queue, :worker_pool)
    end

    it "includes orchestrator ID" do
      expect(orchestrator.stats[:id]).to eq(orchestrator.id)
    end

    it "includes running status" do
      expect(orchestrator.stats[:running]).to be true
    end
  end
end
# rubocop:enable Lint/EmptyBlock
