require "spec_helper"

# rubocop:disable RSpec/DescribeClass -- integration test for event emission

RSpec.describe "Code execution events" do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:event_queue) { Thread::Queue.new }

  before do
    Smolagents::Events::CreateFactory.reset_sequence!
  end

  def build_agent(capture_events: true)
    agent = Smolagents.agent.model { mock_model }.build
    agent.connect_to(event_queue) if capture_events
    agent
  end

  def drain_events
    events = []
    events << event_queue.pop until event_queue.empty?
    events
  end

  describe "CodeGenerated event" do
    describe "definition" do
      it "is defined in Events module" do
        expect(Smolagents::Events::CodeGenerated).to be_a(Class)
      end

      it "has required fields" do
        event = Smolagents::Events::CodeGenerated.create(
          code: "puts 'hello'",
          language: :ruby,
          step_number: 1,
          model_id: "gpt-4"
        )

        expect(event.code).to eq("puts 'hello'")
        expect(event.language).to eq(:ruby)
        expect(event.step_number).to eq(1)
        expect(event.model_id).to eq("gpt-4")
      end
    end

    describe "mapping" do
      it "is mapped as :code_generated" do
        event_class = Smolagents::Events::Mappings.resolve(:code_generated)
        expect(event_class).to eq(Smolagents::Events::CodeGenerated)
      end
    end

    describe "emission" do
      it "is emitted when agent generates code" do
        mock_model.queue_code_action("1 + 1")
        mock_model.queue_final_answer("Done")

        agent = build_agent
        agent.run("Calculate something")

        events = drain_events
        code_events = events.select { |e| e.is_a?(Smolagents::Events::CodeGenerated) }

        expect(code_events.size).to be >= 1
      end

      it "includes the generated code" do
        mock_model.queue_code_action("2 + 2")
        mock_model.queue_final_answer("Done")

        agent = build_agent
        agent.run("Calculate")

        events = drain_events
        code_event = events.find { |e| e.is_a?(Smolagents::Events::CodeGenerated) }

        expect(code_event.code).to eq("2 + 2")
      end

      it "includes step_number" do
        mock_model.queue_code_action("1 + 1")
        mock_model.queue_final_answer("Done")

        agent = build_agent
        agent.run("Calculate")

        events = drain_events
        code_event = events.find { |e| e.is_a?(Smolagents::Events::CodeGenerated) }

        expect(code_event.step_number).to eq(1)
      end
    end
  end

  describe "CodeExecutionStarted event" do
    describe "definition" do
      it "is defined in Events module" do
        expect(Smolagents::Events::CodeExecutionStarted).to be_a(Class)
      end

      it "has required fields" do
        event = Smolagents::Events::CodeExecutionStarted.create(
          code_hash: "abc12345",
          isolation_mode: :ractor
        )

        expect(event.code_hash).to eq("abc12345")
        expect(event.isolation_mode).to eq(:ractor)
      end
    end

    describe "mapping" do
      it "is mapped as :code_execution_started" do
        event_class = Smolagents::Events::Mappings.resolve(:code_execution_started)
        expect(event_class).to eq(Smolagents::Events::CodeExecutionStarted)
      end
    end

    describe "emission" do
      it "is emitted before code execution", :slow do
        mock_model.queue_code_action("1 + 1")
        mock_model.queue_final_answer("Done")

        agent = build_agent
        agent.run("Calculate")

        events = drain_events
        started_events = events.select { |e| e.is_a?(Smolagents::Events::CodeExecutionStarted) }

        expect(started_events.size).to be >= 1
      end

      it "includes code_hash for correlation" do
        mock_model.queue_code_action("3 + 3")
        mock_model.queue_final_answer("Done")

        agent = build_agent
        agent.run("Calculate")

        events = drain_events
        started = events.find { |e| e.is_a?(Smolagents::Events::CodeExecutionStarted) }

        expect(started.code_hash).to match(/^[a-f0-9]{8}$/)
      end

      it "is emitted before CodeExecutionFinished" do
        mock_model.queue_code_action("1 + 1")
        mock_model.queue_final_answer("Done")

        agent = build_agent
        agent.run("Calculate")

        events = drain_events
        started = events.find { |e| e.is_a?(Smolagents::Events::CodeExecutionStarted) }
        finished = events.find { |e| e.is_a?(Smolagents::Events::CodeExecutionFinished) }

        expect(started).not_to be_nil
        expect(finished).not_to be_nil
        expect(started.sequence).to be < finished.sequence
      end
    end
  end

  describe "CodeExecutionFinished event" do
    describe "definition" do
      it "is defined in Events module" do
        expect(Smolagents::Events::CodeExecutionFinished).to be_a(Class)
      end

      it "has required fields" do
        event = Smolagents::Events::CodeExecutionFinished.create(
          code_hash: "abc12345",
          outcome: :success,
          duration_ms: 42,
          output: "result",
          error_class: nil
        )

        expect(event.code_hash).to eq("abc12345")
        expect(event.outcome).to eq(:success)
        expect(event.duration_ms).to eq(42)
        expect(event.output).to eq("result")
        expect(event.error_class).to be_nil
      end

      it "has predicates for outcomes" do
        success = Smolagents::Events::CodeExecutionFinished.create(
          code_hash: "a", outcome: :success, duration_ms: 1
        )
        error = Smolagents::Events::CodeExecutionFinished.create(
          code_hash: "b", outcome: :error, duration_ms: 1
        )

        expect(success).to be_success
        expect(error).to be_error
      end
    end

    describe "mapping" do
      it "is mapped as :code_execution_finished" do
        event_class = Smolagents::Events::Mappings.resolve(:code_execution_finished)
        expect(event_class).to eq(Smolagents::Events::CodeExecutionFinished)
      end
    end

    describe "emission" do
      it "is emitted after code execution completes" do
        mock_model.queue_code_action("5 + 5")
        mock_model.queue_final_answer("Done")

        agent = build_agent
        agent.run("Calculate")

        events = drain_events
        event_types = events.map { |e| e.class.name.split("::").last }
        finished_events = events.select { |e| e.is_a?(Smolagents::Events::CodeExecutionFinished) }

        expect(finished_events.size).to be >= 1, "Events were: #{event_types.inspect}"
      end

      it "captures duration_ms" do
        mock_model.queue_code_action("sleep(0.001); 42")
        mock_model.queue_final_answer("Done")

        agent = build_agent
        agent.run("Calculate")

        events = drain_events
        finished = events.find { |e| e.is_a?(Smolagents::Events::CodeExecutionFinished) }

        expect(finished.duration_ms).to be_a(Integer)
      end

      it "has matching code_hash with started event" do
        mock_model.queue_code_action("1 + 1")
        mock_model.queue_final_answer("Done")

        agent = build_agent
        agent.run("Calculate")

        events = drain_events
        started = events.find { |e| e.is_a?(Smolagents::Events::CodeExecutionStarted) }
        finished = events.find { |e| e.is_a?(Smolagents::Events::CodeExecutionFinished) }

        expect(finished.code_hash).to eq(started.code_hash)
      end

      it "has success outcome for successful execution" do
        mock_model.queue_code_action("2 + 2")
        mock_model.queue_final_answer("Done")

        agent = build_agent
        agent.run("Calculate")

        events = drain_events
        finished = events.find { |e| e.is_a?(Smolagents::Events::CodeExecutionFinished) }

        expect(finished.outcome).to eq(:success)
        expect(finished.error_class).to be_nil
      end

      it "has error outcome for failed execution" do
        # Use code that triggers Ruby detection AND raises an error
        # The Ruby detector needs to see patterns like method calls or operators
        mock_model.queue_code_action("result = 1 / 0")
        mock_model.queue_final_answer("Done")

        agent = build_agent
        agent.run("Fail")

        events = drain_events
        finished = events.select { |e| e.is_a?(Smolagents::Events::CodeExecutionFinished) }

        # Expect at least one finished event (from the final_answer step)
        expect(finished.size).to be >= 1

        # The division by zero error should produce an error outcome
        error_event = finished.find { |e| e.outcome == :error }
        expect(error_event).not_to be_nil
        expect(error_event.error_class).not_to be_nil
      end
    end
  end

  describe "event correlation" do
    it "uses consistent code_hash across started and finished events" do
      mock_model.queue_code_action("puts 'test'")
      mock_model.queue_final_answer("Done")

      agent = build_agent
      agent.run("Test")

      events = drain_events
      started = events.find { |e| e.is_a?(Smolagents::Events::CodeExecutionStarted) }
      finished = events.find { |e| e.is_a?(Smolagents::Events::CodeExecutionFinished) }

      # Code hash should be 8 hex characters (first 8 of MD5)
      expect(started.code_hash).to match(/^[a-f0-9]{8}$/)
      expect(finished.code_hash).to eq(started.code_hash)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
