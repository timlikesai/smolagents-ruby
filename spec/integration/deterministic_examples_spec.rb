# Deterministic Examples Integration Tests
#
# Tests practical use cases from comprehensive_examples_spec.rb WITHOUT requiring
# a live model. Uses MockModel for deterministic, fast testing.
#
# All tests are:
# - Deterministic (same result every run)
# - Fast (no sleeps or network calls)
# - Isolated (using MockModel and mocked executor)
#
# For live model integration tests, see spec/integration/comprehensive_examples_spec.rb

RSpec.describe "Deterministic Examples", :integration do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:captured_events) { [] }
  let(:event_queue) { Thread::Queue.new }

  # Helper to drain events from queue
  def drain_events
    events = []
    events << event_queue.pop until event_queue.empty?
    events
  end

  # ============================================================
  # Tool Creation Patterns
  # ============================================================

  describe "Tool Creation Patterns" do
    describe "DSL-based tools (define_tool)" do
      it "creates simple calculator tool" do
        calculator = Smolagents::Tools.define_tool(
          "calculator",
          description: "Evaluate math expressions",
          inputs: { expression: { type: "string", description: "Math expression" } },
          output_type: "number"
        ) { |expression:| eval(expression).to_f } # rubocop:disable Security/Eval -- test demo with controlled input

        result = calculator.call(expression: "2 + 3 * 4")

        expect(result).to be_a(Smolagents::ToolResult)
        expect(result.data).to eq(14.0)
        expect(result.tool_name).to eq("calculator")
      end

      it "creates tool with optional parameters" do
        greeter = Smolagents::Tools.define_tool(
          "greet",
          description: "Generate greeting",
          inputs: {
            name: { type: "string", description: "Name to greet" },
            formal: { type: "boolean", description: "Use formal greeting", nullable: true }
          },
          output_type: "string"
        ) do |name:, formal: false|
          formal ? "Good day, #{name}." : "Hey #{name}!"
        end

        casual = greeter.call(name: "Alice")
        formal = greeter.call(name: "Bob", formal: true)

        expect(casual.data).to eq("Hey Alice!")
        expect(formal.data).to eq("Good day, Bob.")
      end

      it "creates tool returning array data" do
        list_tool = Smolagents::Tools.define_tool(
          "list_items",
          description: "Returns list of items",
          inputs: {},
          output_type: "array"
        ) { %w[apple banana cherry] }

        result = list_tool.call

        expect(result.data).to eq(%w[apple banana cherry])
        expect(result.size).to eq(3)
      end
    end

    describe "Class-based tools with state" do
      let(:counter_class) do
        Class.new(Smolagents::Tool) do
          self.tool_name = "counter"
          self.description = "Increment and return counter"
          self.inputs = {}
          self.output_type = "integer"

          def setup
            @count = 0
            super
          end

          def execute
            @count += 1
          end
        end
      end

      it "maintains state across calls" do
        counter = counter_class.new

        expect(counter.call.data).to eq(1)
        expect(counter.call.data).to eq(2)
        expect(counter.call.data).to eq(3)
      end

      it "has independent state per instance" do
        counter1 = counter_class.new
        counter2 = counter_class.new

        expect(counter1.call.data).to eq(1)
        expect(counter1.call.data).to eq(2)
        expect(counter2.call.data).to eq(1) # Independent counter
      end
    end
  end

  # ============================================================
  # Agent Builder Patterns
  # ============================================================

  describe "Agent Builder Patterns" do
    it "builds agent with minimal configuration" do
      mock_model.queue_final_answer("done")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent.tools.keys).to include("final_answer")
    end

    it "builds agent with custom instructions" do
      mock_model.queue_final_answer("concise answer")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .instructions("Be concise and direct")
                        .build

      result = agent.run("Test task")

      expect(result).to be_success
      # Verify instructions were included in system prompt
      first_call = mock_model.calls.first
      system_message = first_call[:messages].find { |m| m.role == :system }
      expect(system_message.content).to include("Be concise and direct")
    end

    it "verifies builder immutability" do
      base = Smolagents.agent.with(:code).model { mock_model }

      agent1 = base.max_steps(10).build
      agent2 = base.max_steps(15).build

      expect(agent1.max_steps).to eq(10)
      expect(agent2.max_steps).to eq(15)
    end

    it "configures planning" do
      mock_model.queue_planning_response("Plan: 1. Think 2. Answer")
      mock_model.queue_final_answer("planned result")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .planning(interval: 3)
                        .build

      expect(agent.planning_interval).to eq(3)

      result = agent.run("Task requiring planning")
      expect(result).to be_success
    end

    it "accepts memory configuration in builder" do
      # NOTE: Memory config is accepted by builder but currently uses default config
      # This test verifies the builder API works, not that memory config is applied
      mock_model.queue_final_answer("done")

      builder = Smolagents.agent
                          .model { mock_model }
                          .tools(:final_answer)
                          .memory(budget: 50_000, strategy: :mask, preserve_recent: 3)

      # Builder stores the memory config
      expect(builder.config[:memory_config]).not_to be_nil
      expect(builder.config[:memory_config].budget).to eq(50_000)
      expect(builder.config[:memory_config].mask?).to be true

      # Build the agent
      agent = builder.build
      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it "configures spawn capability" do
      mock_model.queue_final_answer("done")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .can_spawn(allow: [:helper_model], tools: %i[search final_answer], max_children: 5)
                        .build

      spawn_config = agent.instance_variable_get(:@spawn_config)
      expect(spawn_config).not_to be_nil
      expect(spawn_config.model_allowed?(:helper_model)).to be true
      expect(spawn_config.model_allowed?(:unauthorized)).to be false
      expect(spawn_config.max_children).to eq(5)
    end
  end

  # ============================================================
  # Callbacks and Events
  # ============================================================

  describe "Callbacks and Events" do
    # NOTE: Events are only emitted when agent.connect_to(queue) is called.
    # The builder .on() method registers handlers but they only fire when
    # events are consumed from a connected queue.

    it "emits step_complete events via event queue" do
      mock_model.queue_final_answer("done")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      agent.connect_to(event_queue)
      agent.run("Test task")

      events = drain_events
      step_events = events.select { |e| e.is_a?(Smolagents::Events::StepCompleted) }

      expect(step_events).not_to be_empty
      expect(step_events.first.step_number).to eq(1)
    end

    it "emits task_complete event with outcome" do
      mock_model.queue_final_answer("complete")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      agent.connect_to(event_queue)
      agent.run("Test task")

      events = drain_events
      task_events = events.select { |e| e.is_a?(Smolagents::Events::TaskCompleted) }

      expect(task_events.size).to eq(1)
      expect(task_events.first.outcome).to eq(:success)
    end

    it "verifies event sequence with step_complete and task_complete" do
      mock_model.queue_code_action("x = 1")
      mock_model.queue_final_answer("done")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      agent.connect_to(event_queue)
      agent.run("Test task")

      events = drain_events
      step_events = events.select { |e| e.is_a?(Smolagents::Events::StepCompleted) }
      task_events = events.select { |e| e.is_a?(Smolagents::Events::TaskCompleted) }

      expect(step_events.size).to eq(2) # Two steps: code action + final answer
      expect(task_events.size).to eq(1)
      expect(events.last).to be_a(Smolagents::Events::TaskCompleted)
    end

    it "captures step outcome including errors from events" do
      mock_model.queue_code_action("undefined_method_xyz()")
      mock_model.queue_evaluation_continue # Evaluation after error step
      mock_model.queue_final_answer("Recovered")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      agent.connect_to(event_queue)
      agent.run("Test task")

      events = drain_events
      step_events = events.select { |e| e.is_a?(Smolagents::Events::StepCompleted) }
      outcomes = step_events.map(&:outcome)

      expect(outcomes).to include(:error)
      expect(outcomes).to include(:final_answer)
    end

    it "registers handlers via builder on() method" do
      # The builder API accepts handlers, even if events need a queue to fire
      handler_calls = []

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .on(:step_complete) { |e| handler_calls << e }
                        .on(:task_complete) { |e| handler_calls << e }
                        .build

      # Handlers are registered
      expect(agent.event_handlers).not_to be_empty

      # Consume events manually to trigger handlers
      mock_model.queue_final_answer("done")
      agent.connect_to(event_queue)
      agent.run("Test task")

      # Drain and manually consume
      events = drain_events
      events.each { |e| agent.consume(e) }

      expect(handler_calls.size).to eq(events.size)
    end
  end

  # ============================================================
  # Tool Result Chaining
  # ============================================================

  describe "Tool Result Chaining" do
    let(:sample_tool) do
      Smolagents::Tools.define_tool(
        "sample",
        description: "Returns sample data",
        inputs: {},
        output_type: "array"
      ) { [{ name: "Alice", age: 30 }, { name: "Bob", age: 25 }, { name: "Charlie", age: 35 }] }
    end

    it "supports method chaining" do
      result = sample_tool.call

      chained = result.select { |person| person[:age] >= 30 }
                      .sort_by { |person| person[:age] }
                      .pluck(:name)

      expect(chained.data).to eq(%w[Alice Charlie])
    end

    it "supports enumerable operations" do
      result = sample_tool.call

      names = result.map { |person| person[:name] }
      expect(names.data).to eq(%w[Alice Bob Charlie])

      oldest = result.max_by { |person| person[:age] }
      expect(oldest[:name]).to eq("Charlie")
    end

    it "supports pluck operation" do
      result = sample_tool.call

      names = result.pluck(:name)
      expect(names.data).to eq(%w[Alice Bob Charlie])

      ages = result.pluck(:age)
      expect(ages.data).to eq([30, 25, 35])
    end

    it "supports select and filter" do
      result = sample_tool.call

      young = result.select { |person| person[:age] < 30 }
      expect(young.size).to eq(1)
      expect(young.first[:name]).to eq("Bob")
    end

    it "preserves tool_name through chain" do
      result = sample_tool.call
                          .select { |person| person[:age] >= 30 }
                          .pluck(:name)

      expect(result.tool_name).to eq("sample")
    end

    it "supports take and drop" do
      result = sample_tool.call

      first_two = result.take(2)
      expect(first_two.size).to eq(2)

      last_one = result.drop(2)
      expect(last_one.size).to eq(1)
    end
  end

  # ============================================================
  # Multi-Step Execution
  # ============================================================

  describe "Multi-Step Execution" do
    let(:mock_tool) do
      tool = instance_double(Smolagents::Tool)
      allow(tool).to receive_messages(
        name: "mock_tool",
        description: "A mock tool for testing",
        inputs: { query: { type: "string", description: "Query" } },
        output_type: "string",
        to_code_prompt: "mock_tool(query:): A mock tool for testing"
      )
      tool
    end

    it "handles tool call then final answer" do
      allow(mock_tool).to receive(:call).with(query: "test").and_return("Tool result")

      mock_model.queue_code_action('final_answer(mock_tool(query: "test"))')

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(mock_tool)
                        .build

      result = agent.run("Use the tool")

      expect(result).to be_success
      expect(result.output).to eq("Tool result")
      expect(mock_tool).to have_received(:call).with(query: "test")
    end

    it "handles multiple sequential tool calls" do
      tool1 = instance_double(Smolagents::Tool)
      allow(tool1).to receive_messages(
        name: "first_tool",
        description: "First tool",
        inputs: {},
        output_type: "string",
        to_code_prompt: "first_tool(): First tool"
      )
      allow(tool1).to receive(:call).and_return("first result")

      tool2 = instance_double(Smolagents::Tool)
      allow(tool2).to receive_messages(
        name: "second_tool",
        description: "Second tool",
        inputs: {},
        output_type: "string",
        to_code_prompt: "second_tool(): Second tool"
      )
      allow(tool2).to receive(:call).and_return("second result")

      # Call both tools in same code block
      mock_model.queue_code_action("final_answer(\"\#{first_tool()} and \#{second_tool()}\")")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(tool1, tool2)
                        .build

      result = agent.run("Use both tools")

      expect(result).to be_success
      expect(result.output).to include("first result")
      expect(result.output).to include("second result")
    end

    it "handles error recovery scenario" do
      call_count = 0
      allow(mock_tool).to receive(:call) do
        call_count += 1
        raise StandardError, "Tool failed temporarily" if call_count == 1

        "Success on retry"
      end

      # First call fails
      mock_model.queue_code_action('mock_tool(query: "test")')
      mock_model.queue_evaluation_continue # Evaluation after error step
      # Second call succeeds after seeing error
      mock_model.queue_code_action('final_answer(mock_tool(query: "test"))')

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(mock_tool)
                        .build

      result = agent.run("Try the tool")

      expect(result).to be_success
      expect(result.output).to eq("Success on retry")
      expect(call_count).to eq(2)
    end

    it "reaches max_steps when no final answer" do
      3.times do
        mock_model.queue_code_action("x = 1")
        mock_model.queue_evaluation_continue  # Evaluation after non-final step
      end

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .max_steps(3)
                        .build

      result = agent.run("Long running task")

      expect(result.state).to eq(:max_steps_reached)
      expect(result.success?).to be false
      expect(mock_model.call_count).to eq(6)  # 3 action + 3 evaluation
    end
  end

  # ============================================================
  # Full DSL Showcase
  # ============================================================

  describe "Full DSL Showcase" do
    before do
      Smolagents.configure do |c|
        c.models do |m|
          m = m.register(:main_model, -> { mock_model })
          m = m.register(:helper_model, -> { mock_model })
          m
        end
      end
    end

    after { Smolagents.reset_configuration! }

    it "builds agent with all features combined" do
      mock_model.queue_planning_response("Plan: 1. Process data 2. Return answer")
      mock_model.queue_final_answer("complete")

      builder = Smolagents.agent
                          .model(:main_model)
                          .tools(:final_answer)
                          .planning(interval: 3)
                          .memory(budget: 100_000, strategy: :mask)
                          .instructions("Be helpful and concise")
                          .can_spawn(allow: [:helper_model], tools: [:final_answer], inherit: :observations)
                          .max_steps(10)

      # Verify builder configuration
      expect(builder.config[:memory_config]).not_to be_nil
      expect(builder.config[:memory_config].budget).to eq(100_000)

      agent = builder.build

      # Verify agent configuration was applied
      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent.planning_interval).to eq(3)
      expect(agent.max_steps).to eq(10)

      spawn_config = agent.instance_variable_get(:@spawn_config)
      expect(spawn_config).not_to be_nil
      expect(spawn_config.model_allowed?(:helper_model)).to be true

      # Run and verify success
      result = agent.run("Task with all features")
      expect(result).to be_success
      expect(result.output).to eq("complete")

      # Verify instructions were included in the action call (not planning call)
      # With planning enabled, first call is planning, second is action
      action_call = mock_model.calls.last
      system_message = action_call[:messages].find { |m| m.role == :system }
      expect(system_message.content).to include("Be helpful and concise")
    end

    it "retrieves model via Smolagents.get_model" do
      retrieved = Smolagents.get_model(:main_model)
      expect(retrieved).to eq(mock_model)
    end

    it "builds agent using model reference" do
      mock_model.queue_final_answer("done")

      agent = Smolagents.agent
                        .model(:main_model)
                        .tools(:final_answer)
                        .build

      result = agent.run("Task")
      expect(result).to be_success
    end
  end

  # ============================================================
  # RunResult Analysis
  # ============================================================

  describe "RunResult Analysis" do
    it "provides step count" do
      mock_model.queue_code_action("x = 1")
      mock_model.queue_final_answer("done")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      result = agent.run("Multi-step task")

      expect(result.steps.size).to be >= 2
      action_steps = result.steps.select { |s| s.is_a?(Smolagents::Types::ActionStep) }
      expect(action_steps.size).to eq(2)
    end

    it "provides token usage" do
      mock_model.queue_response(
        "<code>\nfinal_answer(\"done\")\n</code>",
        input_tokens: 100,
        output_tokens: 50
      )

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      result = agent.run("Token usage task")

      expect(result.token_usage).to be_a(Smolagents::TokenUsage)
      expect(result.token_usage.input_tokens).to eq(100)
      expect(result.token_usage.output_tokens).to eq(50)
    end

    it "provides timing information" do
      mock_model.queue_final_answer("done")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      result = agent.run("Timed task")

      expect(result.timing).to respond_to(:duration)
      expect(result.timing.duration).to be_a(Float)
    end

    it "has correct state for successful completion" do
      mock_model.queue_final_answer("done")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      result = agent.run("Task")

      expect(result.state).to eq(:success)
      expect(result.success?).to be true
      expect(result.failure?).to be false
    end

    it "includes all expected fields" do
      mock_model.queue_final_answer("complete")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      result = agent.run("Task")

      expect(result).to respond_to(:output)
      expect(result).to respond_to(:state)
      expect(result).to respond_to(:steps)
      expect(result).to respond_to(:token_usage)
      expect(result).to respond_to(:timing)
    end
  end

  # ============================================================
  # Memory Management
  # ============================================================

  describe "Memory Management" do
    it "resets memory between runs by default" do
      mock_model.queue_final_answer("first run")
      mock_model.queue_final_answer("second run")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      result1 = agent.run("First task")
      result2 = agent.run("Second task")

      expect(result1.output).to eq("first run")
      expect(result2.output).to eq("second run")

      # Each run should start fresh - only one TaskStep per run
      task_steps = result2.steps.count { |s| s.is_a?(Smolagents::Types::TaskStep) }
      expect(task_steps).to eq(1)
    end

    it "preserves memory with reset: false" do
      mock_model.queue_final_answer("run 1")
      mock_model.queue_final_answer("run 2")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      agent.run("First task", reset: true)
      agent.run("Second task", reset: false)

      # Memory should contain steps from both runs
      expect(agent.memory.steps.count).to be > 2
    end

    it "uses default strategy when no budget specified" do
      mock_model.queue_final_answer("done")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .memory
                        .build

      expect(agent.memory.config.full?).to be true
      expect(agent.memory.config.budget?).to be false
    end
  end

  # ============================================================
  # Planning Integration
  # ============================================================

  describe "Planning Integration" do
    it "enables planning with default interval" do
      mock_model.queue_planning_response("Plan: Execute task")
      mock_model.queue_final_answer("done")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .planning
                        .build

      expect(agent.planning_interval).to eq(3) # Default interval
    end

    it "generates planning steps during execution" do
      mock_model.queue_planning_response("Plan: 1. Analyze 2. Answer")
      mock_model.queue_final_answer("planned answer")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .planning(interval: 3)
                        .build

      result = agent.run("Task requiring planning")

      planning_steps = result.steps.select { |s| s.is_a?(Smolagents::PlanningStep) }
      expect(planning_steps).not_to be_empty
      expect(planning_steps.first.plan).to include("Plan")
    end

    it "disables planning with explicit false" do
      mock_model.queue_final_answer("no planning")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .planning(false)
                        .build

      expect(agent.planning_interval).to be_nil
    end
  end

  # ============================================================
  # Edge Cases
  # ============================================================

  describe "Edge Cases" do
    it "handles empty string final answer" do
      mock_model.queue_final_answer("")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      result = agent.run("Task")

      expect(result).to be_success
      expect(result.output).to eq("")
    end

    it "handles special characters in output" do
      special_answer = 'Answer with "quotes" and \'apostrophes\' and \\ backslash'
      mock_model.queue_final_answer(special_answer)

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      result = agent.run("Task")

      expect(result).to be_success
      expect(result.output).to include("quotes")
    end

    it "handles unicode in responses" do
      mock_model.queue_final_answer("Unicode: \u2713, \u2717, \u2192")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      result = agent.run("Task")

      expect(result).to be_success
      expect(result.output).to include("\u2713")
    end

    it "handles response without code block gracefully" do
      mock_model.queue_response("I'm thinking about this...")
      mock_model.queue_evaluation_continue # Evaluation after non-code response
      mock_model.queue_final_answer("The answer")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      result = agent.run("Task")

      expect(result).to be_success
      expect(result.output).to eq("The answer")
      expect(mock_model.call_count).to eq(3) # non-code response + evaluation + final answer
    end
  end
end
