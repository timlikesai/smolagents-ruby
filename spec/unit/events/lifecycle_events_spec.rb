require "spec_helper"

# rubocop:disable RSpec/DescribeClass -- integration test for event emission

RSpec.describe "Task lifecycle events" do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:event_queue) { Thread::Queue.new }

  before do
    Smolagents::Events::CreateFactory.reset_sequence!
  end

  # Helper to build an agent with the mock model
  def build_agent(capture_events: true, max_steps: 10)
    agent = Smolagents.agent
                      .model { mock_model }
                      .max_steps(max_steps)
                      .build

    agent.connect_to(event_queue) if capture_events
    agent
  end

  # Helper to drain events from queue
  def drain_events
    events = []
    events << event_queue.pop until event_queue.empty?
    events
  end

  describe "TaskStarted event" do
    describe "definition" do
      it "is defined in Events module" do
        expect(Smolagents::Events::TaskStarted).to be_a(Class)
      end

      it "has required fields" do
        event = Smolagents::Events::TaskStarted.create(
          task: "Test task",
          agent_name: "TestAgent",
          max_steps: 10
        )

        expect(event.task).to eq("Test task")
        expect(event.agent_name).to eq("TestAgent")
        expect(event.max_steps).to eq(10)
      end

      it "has standard event metadata" do
        event = Smolagents::Events::TaskStarted.create(
          task: "Test task",
          agent_name: "TestAgent",
          max_steps: 10
        )

        expect(event.id).not_to be_nil
        expect(event.created_at).not_to be_nil
      end
    end

    describe "mapping" do
      it "is mapped as :task_started" do
        event_class = Smolagents::Events::Mappings.resolve(:task_started)
        expect(event_class).to eq(Smolagents::Events::TaskStarted)
      end
    end

    describe "emission" do
      it "is emitted when agent.run() is called" do
        mock_model.queue_final_answer("Done")

        agent = build_agent
        agent.run("Test task")

        events = drain_events
        task_started_events = events.select { |e| e.is_a?(Smolagents::Events::TaskStarted) }

        expect(task_started_events.size).to eq(1)
      end

      it "has correct task field" do
        mock_model.queue_final_answer("Done")

        agent = build_agent
        agent.run("Find the answer to everything")

        events = drain_events
        task_started = events.find { |e| e.is_a?(Smolagents::Events::TaskStarted) }

        expect(task_started.task).to eq("Find the answer to everything")
      end

      it "has correct agent_name field" do
        mock_model.queue_final_answer("Done")

        agent = build_agent
        agent.run("Test task")

        events = drain_events
        task_started = events.find { |e| e.is_a?(Smolagents::Events::TaskStarted) }

        expect(task_started.agent_name).to eq("Smolagents::Agents::AgentRuntime")
      end

      it "has correct max_steps field" do
        mock_model.queue_final_answer("Done")

        agent = build_agent(max_steps: 15)
        agent.run("Test task")

        events = drain_events
        task_started = events.find { |e| e.is_a?(Smolagents::Events::TaskStarted) }

        expect(task_started.max_steps).to eq(15)
      end

      it "is emitted before the first step" do
        mock_model.queue_final_answer("Done")

        agent = build_agent
        agent.run("Test task")

        events = drain_events

        task_started = events.find { |e| e.is_a?(Smolagents::Events::TaskStarted) }
        first_step = events.find { |e| e.is_a?(Smolagents::Events::StepCompleted) }

        expect(task_started).not_to be_nil
        expect(first_step).not_to be_nil

        # TaskStarted should have a lower sequence number (emitted first)
        expect(task_started.sequence).to be < first_step.sequence
      end

      it "is emitted before TaskCompleted" do
        mock_model.queue_final_answer("Done")

        agent = build_agent
        agent.run("Test task")

        events = drain_events

        task_started = events.find { |e| e.is_a?(Smolagents::Events::TaskStarted) }
        task_completed = events.find { |e| e.is_a?(Smolagents::Events::TaskCompleted) }

        expect(task_started).not_to be_nil
        expect(task_completed).not_to be_nil
        expect(task_started.sequence).to be < task_completed.sequence
      end
    end

    describe "streaming mode" do
      it "is emitted in streaming mode" do
        mock_model.queue_final_answer("Done")

        agent = build_agent
        agent.run("Test task", stream: true).each { |_step| } # Consume enumerator

        events = drain_events
        task_started_events = events.select { |e| e.is_a?(Smolagents::Events::TaskStarted) }

        expect(task_started_events.size).to eq(1)
      end
    end

    describe "multiple runs" do
      it "is emitted for each run" do
        mock_model.queue_final_answer("First")
        mock_model.queue_final_answer("Second")

        agent = build_agent
        agent.run("First task")
        agent.run("Second task")

        events = drain_events
        task_started_events = events.select { |e| e.is_a?(Smolagents::Events::TaskStarted) }

        expect(task_started_events.size).to eq(2)
        expect(task_started_events[0].task).to eq("First task")
        expect(task_started_events[1].task).to eq("Second task")
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
