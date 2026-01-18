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
        format_for: "mock_tool(query:): A mock tool for testing"
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
        format_for: "first_tool(): First tool"
      )
      allow(tool1).to receive(:call).and_return("first result")

      tool2 = instance_double(Smolagents::Tool)
      allow(tool2).to receive_messages(
        name: "second_tool",
        description: "Second tool",
        inputs: {},
        output_type: "string",
        format_for: "second_tool(): Second tool"
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
  # Self-Refine (arXiv:2303.17651)
  # ============================================================

  describe "Self-Refine" do
    describe "with execution feedback (default)" do
      it "skips refinement when execution succeeds" do
        mock_model.queue_final_answer("correct answer")

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(:final_answer)
                          .refine # Enable with defaults
                          .build

        result = agent.run("Task")

        expect(result).to be_success
        expect(result.output).to eq("correct answer")
        # Execution feedback doesn't call model for critique if no error
      end

      it "attempts refinement when execution has error" do
        # First action errors, triggers refinement via execution feedback
        mock_model.queue_code_action("undefined_var")
        mock_model.queue_evaluation_continue # Continue after error
        mock_model.queue_final_answer("recovered")

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(:final_answer)
                          .refine(feedback: :execution)
                          .build

        result = agent.run("Task with potential error")

        expect(result).to be_success
        expect(result.output).to eq("recovered")
      end
    end

    describe "with self-critique feedback" do
      it "approves good output without refinement" do
        mock_model.queue_code_action("result = 42")
        mock_model.queue_critique_approved # LGTM response
        mock_model.queue_evaluation_continue
        mock_model.queue_final_answer("42")

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(:final_answer)
                          .refine(feedback: :self)
                          .build

        result = agent.run("Calculate")

        expect(result).to be_success
        expect(result.output).to eq("42")
      end

      it "refines output based on critique" do
        # Initial action
        mock_model.queue_code_action("result = 41")
        # Critique identifies issue
        mock_model.queue_critique_issue("Off by one", "Change 41 to 42")
        # Refinement applied
        mock_model.queue_refinement("result = 42")
        # Now approved
        mock_model.queue_critique_approved
        mock_model.queue_evaluation_continue
        mock_model.queue_final_answer("42")

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(:final_answer)
                          .refine(max_iterations: 3, feedback: :self)
                          .build

        result = agent.run("Calculate 40 + 2")

        expect(result).to be_success
      end
    end

    describe "configuration" do
      it "configures max iterations" do
        mock_model.queue_final_answer("done")

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(:final_answer)
                          .refine(5) # Integer sets max_iterations
                          .build

        expect(agent.instance_variable_get(:@refine_config).max_iterations).to eq(5)
      end

      it "disables refinement explicitly" do
        mock_model.queue_final_answer("done")

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(:final_answer)
                          .refine(false)
                          .build

        expect(agent.instance_variable_get(:@refine_config)&.enabled).to be_falsey
      end
    end
  end

  # ============================================================
  # Specializations and Personas
  # ============================================================

  describe "Specializations and Personas" do
    describe ".with(:specialization)" do
      it "adds tools AND persona from specialization" do
        mock_model.queue_final_answer("researched result")

        agent = Smolagents.agent
                          .model { mock_model }
                          .with(:researcher) # Adds research tools + persona
                          .build

        # Specialization adds tools beyond just final_answer
        expect(agent.tools.size).to be > 1
        # Specialization adds custom instructions
        expect(agent.custom_instructions).not_to be_nil
      end

      it "combines multiple specializations" do
        mock_model.queue_final_answer("combined result")

        builder = Smolagents.agent
                            .model { mock_model }
                            .with(:researcher, :data_analyst)

        # Both specializations' tools are included
        tool_names = builder.config[:tool_names]
        expect(tool_names).to include(:final_answer)
      end
    end

    describe ".as(:persona)" do
      it "adds ONLY persona (no extra tools)" do
        mock_model.queue_final_answer("persona result")

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(:final_answer)  # Explicit tools only
                          .as(:researcher)       # Persona only
                          .build

        # Only final_answer tool (no extra tools from persona)
        expect(agent.tools.keys).to eq(["final_answer"])
        # But has custom instructions from persona
        expect(agent.custom_instructions).not_to be_nil
        expect(agent.custom_instructions).to include("research")
      end

      it "aliases persona() to as()" do
        mock_model.queue_final_answer("done")

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(:final_answer)
                          .persona(:analyst) # Same as .as(:analyst)
                          .build

        expect(agent.custom_instructions).not_to be_nil
      end
    end

    describe "specialization vs persona distinction" do
      it "demonstrates the key difference" do
        # .with() = tools + persona bundle
        with_builder = Smolagents.agent.model { mock_model }.with(:researcher)

        # .as() = persona only (manual tool control)
        as_builder = Smolagents.agent.model { mock_model }.tools(:final_answer).as(:researcher)

        # with() has more tools
        expect(with_builder.config[:tool_names].size).to be > as_builder.config[:tool_names].size

        # Both have instructions
        expect(with_builder.config[:custom_instructions]).not_to be_nil
        expect(as_builder.config[:custom_instructions]).not_to be_nil
      end

      it "shows equivalence: .with(:researcher) == .tools(research_tools).as(:researcher)" do
        # Get the tools from the researcher specialization
        spec = Smolagents::Specializations.get(:researcher)
        spec_tools = spec.tools

        # Build with specialization
        with_spec = Smolagents.agent.model { mock_model }.with(:researcher)

        # Build with explicit tools + persona
        explicit = Smolagents.agent.model { mock_model }.tools(*spec_tools).as(:researcher)

        # Same tools (order may vary)
        expect(with_spec.config[:tool_names].sort).to eq(explicit.config[:tool_names].sort)

        # Same instructions
        expect(with_spec.config[:custom_instructions]).to eq(explicit.config[:custom_instructions])
      end
    end
  end

  # ============================================================
  # Inline Tool Builder
  # ============================================================

  describe "Inline Tool Builder" do
    it "creates tool inline with builder DSL" do
      mock_model.queue_code_action("final_answer(double_it(value: 21))")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .tool(:double_it, "Double a number", value: Integer) { |value:| value * 2 }
                        .build

      result = agent.run("Double 21")

      expect(result).to be_success
      expect(result.output).to eq(42)
      expect(agent.tools).to have_key("double_it")
    end

    it "creates multiple inline tools" do
      mock_model.queue_code_action("final_answer(add(a: 10, b: 5) + multiply(a: 3, b: 4))")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .tool(:add, "Add two numbers", a: Integer, b: Integer) { |a:, b:| a + b }
                        .tool(:multiply, "Multiply two numbers", a: Integer, b: Integer) { |a:, b:| a * b }
                        .build

      result = agent.run("Calculate (10 + 5) + (3 * 4)")

      expect(result).to be_success
      expect(result.output).to eq(27) # 15 + 12
    end

    it "inline tool has proper metadata" do
      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .tool(:greet, "Greet someone", name: String) { |name:| "Hello #{name}!" }
                        .build

      tool = agent.tools["greet"]

      expect(tool.name).to eq("greet")
      expect(tool.description).to eq("Greet someone")
      expect(tool.inputs).to have_key(:name)
    end
  end

  # ============================================================
  # Fiber Execution (Step-by-Step Control)
  # ============================================================

  describe "Fiber Execution" do
    it "yields each step via run_fiber" do
      mock_model.queue_code_action("step1 = 'first'")
      mock_model.queue_evaluation_continue
      mock_model.queue_code_action("step2 = 'second'")
      mock_model.queue_evaluation_continue
      mock_model.queue_final_answer("done")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      fiber = agent.run_fiber("Multi-step task")
      steps = []

      # Collect steps until fiber completes
      loop do
        step = fiber.resume
        break if step.nil? || step.is_a?(Smolagents::Types::RunResult)

        steps << step
      end

      action_steps = steps.select { |s| s.is_a?(Smolagents::Types::ActionStep) }
      expect(action_steps.size).to be >= 2
    end

    it "allows inspection between steps" do
      mock_model.queue_code_action("x = 1")
      mock_model.queue_evaluation_continue
      mock_model.queue_final_answer("done")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      fiber = agent.run_fiber("Task")

      # Get first step
      first_step = fiber.resume

      # Can inspect step details
      expect(first_step).to be_a(Smolagents::Types::ActionStep)
      expect(first_step.step_number).to eq(1)

      # Continue to completion
      result = nil
      loop do
        step = fiber.resume
        if step.is_a?(Smolagents::Types::RunResult)
          result = step
          break
        end
        break if step.nil?
      end

      expect(result).to be_success
    end

    it "builder provides run_fiber shortcut" do
      mock_model.queue_final_answer("done")

      fiber = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .run_fiber("Task") # Direct from builder

      expect(fiber).to be_a(Fiber)
    end
  end

  # ============================================================
  # Streaming Execution
  # ============================================================

  describe "Streaming Execution" do
    it "returns enumerator with stream: true" do
      mock_model.queue_code_action("x = 1")
      mock_model.queue_evaluation_continue
      mock_model.queue_final_answer("done")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      stream = agent.run("Task", stream: true)

      expect(stream).to be_a(Enumerator)

      steps = stream.to_a
      expect(steps).not_to be_empty
      expect(steps.last).to be_a(Smolagents::Types::RunResult)
    end

    it "yields steps as they complete" do
      mock_model.queue_code_action("data = fetch()")
      mock_model.queue_evaluation_continue
      mock_model.queue_code_action("result = process(data)")
      mock_model.queue_evaluation_continue
      mock_model.queue_final_answer("processed")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      step_numbers = []
      agent.run("Multi-step", stream: true).each do |step|
        step_numbers << step.step_number if step.respond_to?(:step_number)
      end

      expect(step_numbers).to eq([1, 2, 3])
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

  # ============================================================
  # Toolkits (README: Predefined tool groups)
  # ============================================================

  describe "Toolkits" do
    it "expands :search toolkit to individual tools" do
      mock_model.queue_final_answer("found it")

      builder = Smolagents.agent
                          .model { mock_model }
                          .tools(:search)

      # Search toolkit should expand to multiple search tools
      tool_names = builder.config[:tool_names]
      expect(tool_names).to include(:duckduckgo_search)
    end

    it "expands :web toolkit to web tools" do
      mock_model.queue_final_answer("visited")

      builder = Smolagents.agent
                          .model { mock_model }
                          .tools(:web)

      tool_names = builder.config[:tool_names]
      expect(tool_names).to include(:visit_webpage)
    end

    it "expands :research to search + web combined" do
      mock_model.queue_final_answer("researched")

      builder = Smolagents.agent
                          .model { mock_model }
                          .tools(:research)

      tool_names = builder.config[:tool_names]
      expect(tool_names).to include(:duckduckgo_search)
      expect(tool_names).to include(:visit_webpage)
    end

    it "combines multiple toolkits" do
      mock_model.queue_final_answer("done")

      builder = Smolagents.agent
                          .model { mock_model }
                          .tools(:search, :web)

      tool_names = builder.config[:tool_names]
      expect(tool_names).to include(:duckduckgo_search)
      expect(tool_names).to include(:visit_webpage)
    end
  end

  # ============================================================
  # Model Creation (README: Three equivalent ways)
  # ============================================================

  describe "Model Creation" do
    describe "via class method shortcuts" do
      it "creates LM Studio model" do
        model = Smolagents::OpenAIModel.lm_studio("test-model")
        expect(model).to be_a(Smolagents::OpenAIModel)
        expect(model.model_id).to eq("test-model")
      end

      it "creates Ollama model" do
        model = Smolagents::OpenAIModel.ollama("test-model")
        expect(model).to be_a(Smolagents::OpenAIModel)
        expect(model.model_id).to eq("test-model")
      end

      it "creates llama.cpp model" do
        model = Smolagents::OpenAIModel.llama_cpp("test-model")
        expect(model).to be_a(Smolagents::OpenAIModel)
        expect(model.model_id).to eq("test-model")
      end
    end

    describe "via builder with presets" do
      it "creates model with preset" do
        model = Smolagents.model(:lm_studio).id("test-model").build
        expect(model).to be_a(Smolagents::OpenAIModel)
        expect(model.model_id).to eq("test-model")
      end

      it "supports custom host/port" do
        model = Smolagents.model(:lm_studio)
                          .id("test-model")
                          .at(host: "192.168.1.5", port: 1234)
                          .build
        expect(model).to be_a(Smolagents::OpenAIModel)
      end
    end

    describe "via full builder" do
      it "creates model with full configuration" do
        model = Smolagents.model(:openai)
                          .id("gpt-4")
                          .temperature(0.7)
                          .build

        expect(model).to be_a(Smolagents::OpenAIModel)
        expect(model.model_id).to eq("gpt-4")
      end
    end
  end

  # ============================================================
  # One-Shot Execution (README: Quick Start)
  # ============================================================

  describe "One-Shot Execution" do
    it "runs without .build" do
      mock_model.queue_final_answer("quick result")

      # Direct .run() on builder - no .build needed
      result = Smolagents.agent
                         .model { mock_model }
                         .run("Quick task")

      expect(result).to be_success
      expect(result.output).to eq("quick result")
    end

    it "supports tools in one-shot" do
      mock_model.queue_final_answer("with tools")

      result = Smolagents.agent
                         .model { mock_model }
                         .tools(:final_answer)
                         .run("Task with tools")

      expect(result).to be_success
    end
  end

  # ============================================================
  # Multi-Agent Teams (README: Multi-Agent Teams)
  # ============================================================

  describe "Multi-Agent Teams" do
    it "builds team with multiple agents" do
      researcher_model = Smolagents::Testing::MockModel.new
      researcher_model.queue_final_answer("research findings")

      analyst_model = Smolagents::Testing::MockModel.new
      analyst_model.queue_final_answer("analysis complete")

      team_model = Smolagents::Testing::MockModel.new
      team_model.queue_final_answer("team result")

      researcher = Smolagents.agent.model { researcher_model }.as(:researcher).build
      analyst = Smolagents.agent.model { analyst_model }.as(:analyst).build

      team = Smolagents.team
                       .model { team_model }
                       .agent(researcher, as: "researcher")
                       .agent(analyst, as: "analyst")
                       .build

      expect(team).to be_a(Smolagents::Agents::Agent)
      expect(team.managed_agents).to have_key("researcher")
      expect(team.managed_agents).to have_key("analyst")
    end

    it "team agents are callable as tools" do
      researcher_model = Smolagents::Testing::MockModel.new
      researcher_model.queue_final_answer("research result")

      team_model = Smolagents::Testing::MockModel.new
      team_model.queue_code_action('final_answer(researcher(task: "find info"))')

      researcher = Smolagents.agent.model { researcher_model }.as(:researcher).build

      team = Smolagents.team
                       .model { team_model }
                       .agent(researcher, as: "researcher")
                       .build

      # Team should have researcher as a managed agent tool
      expect(team.tools).to have_key("researcher")
    end
  end
end
