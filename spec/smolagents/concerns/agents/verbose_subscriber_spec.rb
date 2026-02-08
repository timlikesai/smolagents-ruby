require "smolagents"

RSpec.describe Smolagents::Concerns::VerboseSubscriber do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Consumer
      include Smolagents::Concerns::VerboseSubscriber

      attr_reader :logger

      def initialize(logger: nil)
        @logger = logger
        initialize_verbose
      end
    end
  end

  let(:logger) { instance_double(Logger) }
  let(:subscriber) { test_class.new(logger:) }

  before do
    Smolagents::Events::CreateFactory.reset_sequence!
    allow(logger).to receive(:debug)
  end

  describe "#initialize_verbose" do
    it "registers handlers for user-tier events" do
      expect(subscriber.event_handlers).not_to be_empty
    end
  end

  describe "StepCompleted" do
    it "formats step outcome" do
      event = Smolagents::Events::StepCompleted.create(step_number: 1, outcome: :success)
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with("[Step 1] success")
    end

    it "formats error outcome" do
      event = Smolagents::Events::StepCompleted.create(step_number: 3, outcome: :error)
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with("[Step 3] error")
    end
  end

  describe "ToolCallRequested" do
    it "formats tool call with arguments" do
      event = Smolagents::Events::ToolCallRequested.create(
        tool_name: "search", args: { query: "Ruby 4.0" }
      )
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with(include("[Tool] Calling search"))
      expect(logger).to have_received(:debug).with(include("query:"))
    end

    it "handles nil args" do
      event = Smolagents::Events::ToolCallRequested.create(tool_name: "clock", args: nil)
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with("[Tool] Calling clock()")
    end
  end

  describe "ToolCallCompleted" do
    it "formats tool result" do
      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "r1", tool_name: "search", result: "Found data", observation: "ok"
      )
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with("[Tool] search returned: Found data")
    end

    it "truncates long results" do
      long_result = "x" * 300
      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "r1", tool_name: "search", result: long_result, observation: "ok"
      )
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with(match(/\.\.\./))
    end
  end

  describe "ToolCallParsed" do
    it "formats parsed tool call" do
      event = Smolagents::Events::ToolCallParsed.create(
        model_id: "gemma", tool_name: "search", arguments: { q: "test" }, call_id: "c1"
      )
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with(include("[Parsed] gemma -> search"))
    end
  end

  describe "ModelGeneration" do
    it "formats requested phase" do
      event = Smolagents::Events::ModelGeneration.create(
        model_id: "gemma-3n", phase: :requested
      )
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with("[Model] gemma-3n generation requested")
    end

    it "formats completed phase with tokens" do
      event = Smolagents::Events::ModelGeneration.create(
        model_id: "gemma-3n", phase: :completed,
        duration_ms: 250, token_usage: { output_tokens: 145 }
      )
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with("[Model] gemma-3n generated 145 tokens (250ms)")
    end

    it "handles missing token usage" do
      event = Smolagents::Events::ModelGeneration.create(
        model_id: "gemma-3n", phase: :completed, duration_ms: 100
      )
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with(include("?"))
    end
  end

  describe "TaskLifecycle" do
    it "formats task started" do
      event = Smolagents::Events::TaskLifecycle.create(
        phase: :started, task: "Find Ruby info", max_steps: 10
      )
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with(include("[Task] Started:"))
      expect(logger).to have_received(:debug).with(include("max 10 steps"))
    end

    it "formats task completed" do
      event = Smolagents::Events::TaskLifecycle.create(
        phase: :completed, outcome: :success, steps_taken: 3
      )
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with("[Task] Completed: success (3 steps)")
    end
  end

  describe "ErrorOccurred" do
    it "formats recoverable error" do
      event = Smolagents::Events::ErrorOccurred.create(
        error: RuntimeError.new("Connection refused"), recoverable: true
      )
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with(
        "[Error] RuntimeError: Connection refused (recoverable)"
      )
    end

    it "formats fatal error" do
      event = Smolagents::Events::ErrorOccurred.create(
        error: ArgumentError.new("bad input"), recoverable: false
      )
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with(include("(fatal)"))
    end
  end

  describe "SubAgentLaunched" do
    it "formats sub-agent launch" do
      event = Smolagents::Events::SubAgentLaunched.create(
        agent_name: "researcher", task: "Search for papers"
      )
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with(
        "[SubAgent] Launched researcher: Search for papers"
      )
    end
  end

  describe "SubAgentCompleted" do
    it "formats sub-agent completion" do
      event = Smolagents::Events::SubAgentCompleted.create(
        launch_id: "l1", agent_name: "researcher", outcome: :success
      )
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with("[SubAgent] researcher success")
    end
  end

  describe "ControlYielded" do
    it "formats control yield" do
      event = Smolagents::Events::ControlYielded.create(
        request_type: :user_input, request_id: "req1", prompt: "Enter value:"
      )
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with(
        "[Control] Yielded user_input: Enter value:"
      )
    end
  end

  describe "ControlResumed" do
    it "formats control resume" do
      event = Smolagents::Events::ControlResumed.create(
        request_id: "req1", approved: true, value: "yes"
      )
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with(
        "[Control] Resumed req1 (approved: true)"
      )
    end
  end

  describe "with no logger" do
    it "does not raise when logger is nil" do
      sub = test_class.new(logger: nil)
      event = Smolagents::Events::StepCompleted.create(step_number: 1, outcome: :success)

      expect { sub.consume(event) }.not_to raise_error
    end
  end

  describe "truncation" do
    it "truncates long task descriptions" do
      long_task = "a" * 300
      event = Smolagents::Events::TaskLifecycle.create(
        phase: :started, task: long_task, max_steps: 5
      )
      subscriber.consume(event)

      expect(logger).to have_received(:debug).with(match(/a{200}.../))
    end
  end
end
