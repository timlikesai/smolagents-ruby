require "smolagents"

RSpec.describe Smolagents::Concerns::ReActLoop do
  # Helper to drain events from Thread::Queue
  def drain_queue(queue)
    events = []
    while (event = begin
      queue.pop(true)
    rescue StandardError
      nil
    end)
      events << event
    end
    events
  end
  # Create a minimal class that includes ReActLoop for testing
  let(:react_agent_class) do
    Class.new do
      include Smolagents::Concerns::Monitorable
      include Smolagents::Concerns::Planning
      include Smolagents::Concerns::ManagedAgents
      include Smolagents::Concerns::ReActLoop
      # Opt-in Control for bidirectional fiber control tests
      include Smolagents::Concerns::ReActLoop::Control

      attr_accessor :step_results

      def initialize(model:, tools:, max_steps: 5)
        @step_results = []
        config = Smolagents::Types::SetupConfig.create(tools:, model:, max_steps:)
        setup_agent(config)
      end

      def system_prompt
        "You are a helpful assistant."
      end

      def step(_task, step_number:)
        @step_results[step_number - 1] || build_default_step(step_number)
      end

      private

      def build_default_step(step_number)
        Smolagents::ActionStep.new(
          step_number:,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: false,
          token_usage: Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 5)
        )
      end
    end
  end

  let(:mock_model) do
    # rubocop:disable RSpec/VerifiedDoubles -- mock includes close_connections from subclass
    double("Model").tap do |model|
      allow(model).to receive(:close_connections)
      allow(model).to receive(:generate).and_return(
        double("ChatMessage", content: "Plan: step 1", token_usage: Smolagents::TokenUsage.zero) # rubocop:disable RSpec/VerifiedDoubles
      )
    end
    # rubocop:enable RSpec/VerifiedDoubles
  end

  let(:mock_tool) do
    instance_double(Smolagents::Tool, name: "test_tool", description: "A test tool")
  end

  let(:tools) { [mock_tool] }
  let(:agent) { react_agent_class.new(model: mock_model, tools:, max_steps: 5) }

  describe "#setup_agent" do
    it "sets up the model" do
      expect(agent.model).to eq(mock_model)
    end

    it "sets up max_steps from parameter" do
      custom_agent = react_agent_class.new(model: mock_model, tools:, max_steps: 10)
      expect(custom_agent.max_steps).to eq(10)
    end

    it "initializes memory with system prompt" do
      expect(agent.memory).to be_a(Smolagents::AgentMemory)
      expect(agent.memory.system_prompt.system_prompt).to eq("You are a helpful assistant.")
    end

    it "initializes empty state" do
      expect(agent.state).to eq({})
    end

    it "sets up tools including final_answer" do
      expect(agent.tools.keys).to include("final_answer")
    end
  end

  describe "#run" do
    describe "synchronous execution" do
      it "returns a RunResult" do
        agent.step_results = [
          Smolagents::ActionStep.new(
            step_number: 1,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: true,
            action_output: "test output",
            token_usage: Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 5)
          )
        ]

        result = agent.run("test task")

        expect(result).to be_a(Smolagents::RunResult)
      end

      it "stops when step is_final_answer is true" do
        agent.step_results = [
          Smolagents::ActionStep.new(
            step_number: 1,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: true,
            action_output: "final result",
            token_usage: Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 5)
          )
        ]

        result = agent.run("test task")

        expect(result.output).to eq("final result")
        expect(result.state).to eq(:success)
      end

      it "returns max_steps_reached when max_steps exceeded" do
        agent.step_results = Array.new(6) do |i|
          Smolagents::ActionStep.new(
            step_number: i + 1,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: false,
            token_usage: Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 5)
          )
        end

        result = agent.run("test task")

        expect(result.state).to eq(:max_steps_reached)
      end

      it "accumulates token usage across steps" do
        agent.step_results = [
          Smolagents::ActionStep.new(
            step_number: 1,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: false,
            token_usage: Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50)
          ),
          Smolagents::ActionStep.new(
            step_number: 2,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: true,
            action_output: "done",
            token_usage: Smolagents::TokenUsage.new(input_tokens: 80, output_tokens: 40)
          )
        ]

        result = agent.run("test task")

        expect(result.token_usage.input_tokens).to eq(180)
        expect(result.token_usage.output_tokens).to eq(90)
      end

      it "resets state between runs when reset: true" do
        agent.step_results = [
          Smolagents::ActionStep.new(
            step_number: 1,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: true,
            action_output: "first",
            token_usage: Smolagents::TokenUsage.zero
          )
        ]

        agent.run("first task")
        memory_size_after_first = agent.memory.steps.size

        agent.run("second task", reset: true)
        memory_size_after_second = agent.memory.steps.size

        expect(memory_size_after_second).to be <= memory_size_after_first + 1
      end

      it "preserves state between runs when reset: false" do
        agent.step_results = [
          Smolagents::ActionStep.new(
            step_number: 1,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: true,
            action_output: "first",
            token_usage: Smolagents::TokenUsage.zero
          )
        ]

        agent.run("first task")
        memory_size_after_first = agent.memory.steps.size

        agent.run("second task", reset: false)

        expect(agent.memory.steps.size).to be > memory_size_after_first
      end
    end

    describe "streaming execution" do
      it "returns an Enumerator" do
        agent.step_results = [
          Smolagents::ActionStep.new(
            step_number: 1,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: true,
            action_output: "done",
            token_usage: Smolagents::TokenUsage.zero
          )
        ]

        result = agent.run("test task", stream: true)

        expect(result).to be_a(Enumerator)
      end

      it "yields each step" do
        agent.step_results = [
          Smolagents::ActionStep.new(
            step_number: 1,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: false,
            token_usage: Smolagents::TokenUsage.zero
          ),
          Smolagents::ActionStep.new(
            step_number: 2,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: true,
            action_output: "done",
            token_usage: Smolagents::TokenUsage.zero
          )
        ]

        steps = agent.run("test task", stream: true).to_a

        expect(steps.size).to eq(2)
        expect(steps.first.step_number).to eq(1)
        expect(steps.last.step_number).to eq(2)
      end

      it "stops when final answer reached" do
        agent.step_results = [
          Smolagents::ActionStep.new(
            step_number: 1,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: true,
            action_output: "done",
            token_usage: Smolagents::TokenUsage.zero
          ),
          Smolagents::ActionStep.new(
            step_number: 2,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: false,
            token_usage: Smolagents::TokenUsage.zero
          )
        ]

        steps = agent.run("test task", stream: true).to_a

        expect(steps.size).to eq(1)
      end

      it "respects max_steps" do
        short_agent = react_agent_class.new(model: mock_model, tools:, max_steps: 2)
        short_agent.step_results = Array.new(5) do |i|
          Smolagents::ActionStep.new(
            step_number: i + 1,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: false,
            token_usage: Smolagents::TokenUsage.zero
          )
        end

        steps = short_agent.run("test task", stream: true).to_a

        expect(steps.size).to eq(2)
      end
    end

    describe "error handling" do
      let(:error_agent_class) do
        Class.new(react_agent_class) do
          attr_accessor :should_error_at_step

          def step(_task, step_number:)
            raise "Intentional error at step #{step_number}" if @should_error_at_step == step_number

            super
          end
        end
      end

      it "returns error state when exception occurs" do
        error_agent = error_agent_class.new(model: mock_model, tools:, max_steps: 5)
        error_agent.should_error_at_step = 1

        result = error_agent.run("test task")

        expect(result.state).to eq(:error)
      end

      it "cleans up resources on error" do
        error_agent = error_agent_class.new(model: mock_model, tools:, max_steps: 5)
        error_agent.should_error_at_step = 1

        error_agent.run("test task")

        expect(mock_model).to have_received(:close_connections)
      end

      it "cleans up resources on success" do
        agent.step_results = [
          Smolagents::ActionStep.new(
            step_number: 1,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: true,
            action_output: "done",
            token_usage: Smolagents::TokenUsage.zero
          )
        ]

        agent.run("test task")

        expect(mock_model).to have_received(:close_connections)
      end
    end
  end

  describe "#run_fiber" do
    it "returns a Fiber" do
      agent.step_results = [
        Smolagents::ActionStep.new(
          step_number: 1,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: true,
          action_output: "done",
          token_usage: Smolagents::TokenUsage.zero
        )
      ]

      fiber = agent.run_fiber("test task")
      expect(fiber).to be_a(Fiber)
    end

    it "yields ActionSteps then RunResult" do
      agent.step_results = [
        Smolagents::ActionStep.new(
          step_number: 1,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: false,
          token_usage: Smolagents::TokenUsage.zero
        ),
        Smolagents::ActionStep.new(
          step_number: 2,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: true,
          action_output: "done",
          token_usage: Smolagents::TokenUsage.zero
        )
      ]

      fiber = agent.run_fiber("test task")
      results = []

      loop do
        result = fiber.resume
        results << result
        break if result.is_a?(Smolagents::RunResult)
      end

      expect(results[0]).to be_a(Smolagents::ActionStep)
      expect(results[1]).to be_a(Smolagents::ActionStep)
      expect(results[2]).to be_a(Smolagents::RunResult)
      expect(results[2].output).to eq("done")
    end

    it "respects max_steps limit" do
      short_agent = react_agent_class.new(model: mock_model, tools:, max_steps: 2)
      short_agent.step_results = Array.new(5) do |i|
        Smolagents::ActionStep.new(
          step_number: i + 1,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: false,
          token_usage: Smolagents::TokenUsage.zero
        )
      end

      fiber = short_agent.run_fiber("test task")
      step_count = 0
      final_result = nil

      loop do
        result = fiber.resume
        case result
        when Smolagents::ActionStep
          step_count += 1
        when Smolagents::RunResult
          final_result = result
          break
        end
      end

      expect(step_count).to eq(2)
      expect(final_result.state).to eq(:max_steps_reached)
    end

    it "sets fiber_context? to true during execution" do
      # Create a custom agent that captures the fiber_context? value during step execution
      capturing_agent_class = Class.new(react_agent_class) do
        attr_accessor :captured_context

        def step(_task, step_number:)
          @captured_context = fiber_context?
          super
        end
      end

      capturing_agent = capturing_agent_class.new(model: mock_model, tools:, max_steps: 5)
      capturing_agent.step_results = [
        Smolagents::ActionStep.new(
          step_number: 1,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: true,
          action_output: "done",
          token_usage: Smolagents::TokenUsage.zero
        )
      ]

      fiber = capturing_agent.run_fiber("test task")
      fiber.resume # Execute first step

      # fiber_context? was true during step execution
      expect(capturing_agent.captured_context).to be true
    end

    it "cleans up fiber_context? after completion" do
      agent.step_results = [
        Smolagents::ActionStep.new(
          step_number: 1,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: true,
          action_output: "done",
          token_usage: Smolagents::TokenUsage.zero
        )
      ]

      fiber = agent.run_fiber("test task")

      # Run to completion
      loop do
        result = fiber.resume
        break if result.is_a?(Smolagents::RunResult)
      end

      expect(agent.fiber_context?).to be false
    end
  end

  describe "#fiber_context?" do
    it "returns false when not in fiber context" do
      clear_fiber_context
      expect(agent.fiber_context?).to be false
    end

    it "returns true when thread-local is set" do
      set_fiber_context(true)
      expect(agent.fiber_context?).to be true
    ensure
      clear_fiber_context
    end
  end

  describe "Control methods" do
    describe "#request_input" do
      it "raises ControlFlowError outside Fiber context" do
        clear_fiber_context
        expect { agent.request_input("test") }.to raise_error(Smolagents::ControlFlowError)
      end
    end

    describe "#request_confirmation" do
      it "raises ControlFlowError outside Fiber context" do
        clear_fiber_context
        expect do
          agent.request_confirmation(action: "test", description: "test")
        end.to raise_error(Smolagents::ControlFlowError)
      end
    end

    describe "#escalate_query" do
      it "raises ControlFlowError outside Fiber context" do
        clear_fiber_context
        expect { agent.escalate_query("test") }.to raise_error(Smolagents::ControlFlowError)
      end
    end
  end

  describe "#write_memory_to_messages" do
    it "returns messages from memory" do
      agent.step_results = [
        Smolagents::ActionStep.new(
          step_number: 1,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: true,
          action_output: "done",
          token_usage: Smolagents::TokenUsage.zero
        )
      ]

      agent.run("test task")
      messages = agent.write_memory_to_messages

      expect(messages).to be_an(Array)
      expect(messages.first).to be_a(Smolagents::ChatMessage)
    end

    it "supports summary mode" do
      agent.step_results = [
        Smolagents::ActionStep.new(
          step_number: 1,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: true,
          action_output: "done",
          token_usage: Smolagents::TokenUsage.zero
        )
      ]

      agent.run("test task")
      regular = agent.write_memory_to_messages(summary_mode: false)
      summary = agent.write_memory_to_messages(summary_mode: true)

      expect(summary).to be_an(Array)
      expect(regular).to be_an(Array)
    end
  end

  describe "step sequencing" do
    it "executes steps in order" do
      agent.step_results = [
        Smolagents::ActionStep.new(
          step_number: 1,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: false,
          token_usage: Smolagents::TokenUsage.zero
        ),
        Smolagents::ActionStep.new(
          step_number: 2,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: false,
          token_usage: Smolagents::TokenUsage.zero
        ),
        Smolagents::ActionStep.new(
          step_number: 3,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: true,
          action_output: "done",
          token_usage: Smolagents::TokenUsage.zero
        )
      ]

      result = agent.run("test task")

      action_steps = agent.memory.action_steps.to_a
      expect(action_steps.map(&:step_number)).to eq([1, 2, 3])
      expect(result.state).to eq(:success)
    end

    it "adds steps to memory in order" do
      agent.step_results = [
        Smolagents::ActionStep.new(
          step_number: 1,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: false,
          observations: "Step 1 done",
          token_usage: Smolagents::TokenUsage.zero
        ),
        Smolagents::ActionStep.new(
          step_number: 2,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: true,
          action_output: "done",
          token_usage: Smolagents::TokenUsage.zero
        )
      ]

      agent.run("test task")

      action_steps = agent.memory.action_steps.to_a
      expect(action_steps.map(&:step_number)).to eq([1, 2])
    end
  end

  describe "timing" do
    it "records timing in result" do
      start_time = Time.now
      step_timing = Smolagents::Timing.new(start_time:, end_time: start_time + 0.5)

      agent.step_results = [
        Smolagents::ActionStep.new(
          step_number: 1,
          timing: step_timing,
          is_final_answer: true,
          action_output: "done",
          token_usage: Smolagents::TokenUsage.zero
        )
      ]

      result = agent.run("test task")

      # Verify structural properties: result has timing with duration
      expect(result.timing).to be_a(Smolagents::Timing)
      expect(result.timing.end_time).to be_a(Time)
      expect(result.timing.duration).to be_a(Float)
    end
  end

  describe "event emission" do
    let(:event_queue) { Thread::Queue.new }

    before do
      agent.connect_to(event_queue)
    end

    describe "step events" do
      it "emits StepCompleted event after each step" do
        agent.step_results = [
          Smolagents::ActionStep.new(
            step_number: 1,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: true,
            action_output: "done",
            token_usage: Smolagents::TokenUsage.zero
          )
        ]

        agent.run("test task")

        events = drain_queue(event_queue)
        step_events = events.select { |e| e.is_a?(Smolagents::Events::StepCompleted) }

        expect(step_events.size).to eq(1)
        expect(step_events.first.step_number).to eq(1)
        expect(step_events.first.outcome).to eq(:final_answer)
      end

      it "emits StepCompleted with :success outcome for non-final steps" do
        agent.step_results = [
          Smolagents::ActionStep.new(
            step_number: 1,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: false,
            token_usage: Smolagents::TokenUsage.zero
          ),
          Smolagents::ActionStep.new(
            step_number: 2,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: true,
            action_output: "done",
            token_usage: Smolagents::TokenUsage.zero
          )
        ]

        agent.run("test task")

        events = drain_queue(event_queue)
        step_events = events.select { |e| e.is_a?(Smolagents::Events::StepCompleted) }

        expect(step_events.size).to eq(2)
        expect(step_events.first.outcome).to eq(:success)
        expect(step_events.last.outcome).to eq(:final_answer)
      end
    end

    describe "task events" do
      it "emits TaskCompleted event on success" do
        agent.step_results = [
          Smolagents::ActionStep.new(
            step_number: 1,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: true,
            action_output: "final result",
            token_usage: Smolagents::TokenUsage.zero
          )
        ]

        agent.run("test task")

        events = drain_queue(event_queue)
        task_events = events.select { |e| e.is_a?(Smolagents::Events::TaskCompleted) }

        expect(task_events.size).to eq(1)
        expect(task_events.first.outcome).to eq(:success)
        expect(task_events.first.output).to eq("final result")
        expect(task_events.first.steps_taken).to eq(1)
      end

      it "emits TaskCompleted event on max_steps_reached" do
        agent.step_results = Array.new(6) do |i|
          Smolagents::ActionStep.new(
            step_number: i + 1,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: false,
            token_usage: Smolagents::TokenUsage.zero
          )
        end

        agent.run("test task")

        events = drain_queue(event_queue)
        task_events = events.select { |e| e.is_a?(Smolagents::Events::TaskCompleted) }

        expect(task_events.size).to eq(1)
        expect(task_events.first.outcome).to eq(:max_steps_reached)
        expect(task_events.first.steps_taken).to eq(5)
      end
    end

    describe "streaming with events" do
      it "emits events in streaming mode" do
        agent.step_results = [
          Smolagents::ActionStep.new(
            step_number: 1,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: true,
            action_output: "done",
            token_usage: Smolagents::TokenUsage.zero
          )
        ]

        agent.run("test task", stream: true).to_a

        events = drain_queue(event_queue)
        step_events = events.select { |e| e.is_a?(Smolagents::Events::StepCompleted) }
        task_events = events.select { |e| e.is_a?(Smolagents::Events::TaskCompleted) }

        expect(step_events.size).to eq(1)
        expect(task_events.size).to eq(1)
        expect(task_events.first.outcome).to eq(:success)
      end
    end

    describe "without event queue" do
      it "does not fail when no event queue connected" do
        disconnected_agent = react_agent_class.new(model: mock_model, tools:, max_steps: 5)
        disconnected_agent.step_results = [
          Smolagents::ActionStep.new(
            step_number: 1,
            timing: Smolagents::Timing.start_now.stop,
            is_final_answer: true,
            action_output: "done",
            token_usage: Smolagents::TokenUsage.zero
          )
        ]

        expect { disconnected_agent.run("test task") }.not_to raise_error
      end
    end
  end

  describe "event subscription via Consumer" do
    it "allows subscribing to step events" do
      received_steps = []
      agent.on(Smolagents::Events::StepCompleted) { |e| received_steps << e.step_number }

      agent.step_results = [
        Smolagents::ActionStep.new(
          step_number: 1,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: false,
          token_usage: Smolagents::TokenUsage.zero
        ),
        Smolagents::ActionStep.new(
          step_number: 2,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: true,
          action_output: "done",
          token_usage: Smolagents::TokenUsage.zero
        )
      ]

      # Events are emitted to queue, then consumed
      event_queue = Thread::Queue.new
      agent.connect_to(event_queue)
      agent.run("test task")

      # Process the events through the consumer
      drain_queue(event_queue).each { |e| agent.consume(e) }

      expect(received_steps).to eq([1, 2])
    end

    it "allows subscribing to task events" do
      received_outcome = nil
      agent.on(Smolagents::Events::TaskCompleted) { |e| received_outcome = e.outcome }

      agent.step_results = [
        Smolagents::ActionStep.new(
          step_number: 1,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: true,
          action_output: "done",
          token_usage: Smolagents::TokenUsage.zero
        )
      ]

      event_queue = Thread::Queue.new
      agent.connect_to(event_queue)
      agent.run("test task")

      drain_queue(event_queue).each { |e| agent.consume(e) }

      expect(received_outcome).to eq(:success)
    end

    it "allows subscribing with convenience names" do
      received_event = nil
      agent.on(:step_complete) { |e| received_event = e }

      agent.step_results = [
        Smolagents::ActionStep.new(
          step_number: 1,
          timing: Smolagents::Timing.start_now.stop,
          is_final_answer: true,
          action_output: "done",
          token_usage: Smolagents::TokenUsage.zero
        )
      ]

      event_queue = Thread::Queue.new
      agent.connect_to(event_queue)
      agent.run("test task")

      drain_queue(event_queue).each { |e| agent.consume(e) }

      expect(received_event).to be_a(Smolagents::Events::StepCompleted)
    end
  end
end
