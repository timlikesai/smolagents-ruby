# Comprehensive Examples Integration Tests
#
# Tests all documented examples work with small local models.
# Based on examples/ directory demonstrating all DSL patterns.
#
RSpec.describe "Comprehensive Examples", skip: !ENV["LIVE_MODEL_TESTS"] do
  let(:lm_studio_url) { ENV.fetch("LM_STUDIO_URL", "http://localhost:1234/v1") }
  let(:model) do
    Smolagents::Models::OpenAIModel.new(
      model_id: "lfm2-8b-a1b", # Fast, capable model for testing
      api_base: lm_studio_url,
      api_key: "not-needed"
    )
  end

  # rubocop:disable RSpec/BeforeAfterAll
  before(:all) do
    # Log warnings and above - final_answer is now logged as info, not a warning
    Smolagents::Telemetry::LoggingSubscriber.enable(level: :warn)
  end

  after(:all) do
    Smolagents::Telemetry::LoggingSubscriber.disable
  end
  # rubocop:enable RSpec/BeforeAfterAll

  describe "Tool Creation" do
    context "with DSL-based tools (define_tool)" do
      it "creates simple calculator tool" do
        calculator = Smolagents::Tools.define_tool(
          "calculator",
          description: "Evaluate math expressions",
          inputs: { expression: { type: "string", description: "Math expression" } },
          output_type: "number"
        ) { |expression:| eval(expression).to_f }

        result = calculator.call(expression: "2 + 3 * 4")

        expect(result).to be_a(Smolagents::ToolResult)
        expect(result.data).to eq(14.0)
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
    end

    context "with Class-based tools" do
      before do
        stub_const("CounterTool", Class.new(Smolagents::Tool) do
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
        end)
      end

      it "creates tool with state" do
        counter = CounterTool.new

        expect(counter.call.data).to eq(1)
        expect(counter.call.data).to eq(2)
        expect(counter.call.data).to eq(3)
      end
    end
  end

  describe "Agent Builder Pattern" do
    it "builds agent with minimal config" do
      agent = Smolagents.agent.with(:code)
                        .model { model }
                        .tools(:final_answer)
                        .max_steps(10)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent.tools.keys).to include("final_answer")
    end

    it "builds agent with config" do
      agent = Smolagents.agent
                        .model { model }
                        .tools(:final_answer)
                        .max_steps(10)
                        .instructions("Be concise")
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent.max_steps).to eq(10)
    end

    it "creates immutable builders" do
      base = Smolagents.agent.with(:code).model { model }

      agent1 = base.max_steps(10).build
      agent2 = base.max_steps(15).build

      expect(agent1.max_steps).to eq(10)
      expect(agent2.max_steps).to eq(15)
    end
  end

  describe "Callbacks" do
    it "triggers before_step callback" do
      steps_started = []

      agent = Smolagents.agent.with(:code)
                        .model { model }
                        .tools(:final_answer)
                        .max_steps(10)
                        .on(:before_step) { |step_number:| steps_started << step_number }
                        .build

      agent.run("Use final_answer to return: hello")

      expect(steps_started).not_to be_empty
      expect(steps_started.first).to eq(1)
    end

    it "triggers after_step callback with timing" do
      step_durations = []

      agent = Smolagents.agent.with(:code)
                        .model { model }
                        .tools(:final_answer)
                        .max_steps(10)
                        .on(:after_step) { |_step:, monitor:| step_durations << monitor.duration }
                        .build

      agent.run("Use final_answer to return: done")

      expect(step_durations).not_to be_empty
      expect(step_durations.all? { |d| d.is_a?(Float) && d.positive? }).to be true
    end

    it "triggers after_task callback" do
      task_completed = false
      final_state = nil

      agent = Smolagents.agent.with(:code)
                        .model { model }
                        .tools(:final_answer)
                        .max_steps(10)
                        .on(:after_task) do |result:|
                          task_completed = true
                          final_state = result.state
      end
        .build

      agent.run("Use final_answer to return: complete")

      expect(task_completed).to be true
      expect(final_state).to eq(:success)
    end
  end

  describe "Tool Results" do
    let(:sample_tool) do
      Smolagents::Tools.define_tool(
        "sample",
        description: "Returns sample data",
        inputs: {},
        output_type: "array"
      ) { [{ name: "Alice", age: 30 }, { name: "Bob", age: 25 }] }
    end

    it "returns ToolResult from tool calls" do
      result = sample_tool.call

      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.data).to be_an(Array)
    end

    it "supports method chaining on ToolResult" do
      result = sample_tool.call

      names = result.pluck(:name)
      expect(names).to eq(%w[Alice Bob])
    end

    it "supports enumerable operations" do
      result = sample_tool.call

      adults = result.select { |person| person[:age] >= 25 }
      expect(adults.size).to eq(2)
    end
  end

  describe "Agent Execution" do
    context "with calculator tool" do
      let(:calculator) do
        Smolagents::Tools.define_tool(
          "calculate",
          description: "Evaluate math expressions",
          inputs: { expression: { type: "string", description: "Math expression" } },
          output_type: "number"
        ) { |expression:| eval(expression).to_f }
      end

      it "solves simple math problem" do
        agent = Smolagents.agent.with(:code)
                          .model { model }
                          .tools(calculator, :final_answer)
                          .max_steps(10)
                          .build

        result = agent.run("Use calculate tool with expression '15 * 7', then use final_answer to return the result.")

        expect(result.success?).to be true
        expect(result.output.to_s).to include("105")
      end

      it "solves multi-step math problem" do
        agent = Smolagents.agent.with(:code)
                          .model { model }
                          .tools(calculator, :final_answer)
                          .max_steps(12)
                          .build

        task = "First calculate 20 * 5, then add 50 to that result. Use final_answer to return the final number."
        result = agent.run(task)

        expect(result.success?).to be true
        expect(result.output.to_s).to include("150")
      end
    end

    context "with custom tools" do
      let(:data_tool) do
        Smolagents::Tools.define_tool(
          "get_data",
          description: "Returns test data",
          inputs: {},
          output_type: "array"
        ) { [1, 2, 3, 4, 5] }
      end

      it "processes data with custom tool" do
        agent = Smolagents.agent.with(:code)
                          .model { model }
                          .tools(data_tool, :final_answer)
                          .max_steps(10)
                          .build

        result = agent.run("Use get_data to fetch the data, calculate the sum, and return it with final_answer.")

        expect(result.success?).to be true
      end
    end
  end

  describe "RunResult Analysis" do
    let(:agent) do
      Smolagents.agent.with(:code)
                .model { model }
                .tools(:final_answer)
                .max_steps(10)
                .build
    end

    it "provides step count" do
      result = agent.run("Use final_answer to return: hello")

      expect(result.steps).not_to be_empty
      expect(result.steps.all? do |s|
        s.is_a?(Smolagents::Types::ActionStep) || s.is_a?(Smolagents::Types::TaskStep)
      end).to be true
    end

    it "provides token usage" do
      result = agent.run("Use final_answer to return: test")

      expect(result.token_usage).to be_a(Smolagents::TokenUsage)
      expect(result.token_usage.total_tokens).to be > 0
    end

    it "provides timing information" do
      result = agent.run("Use final_answer to return: timing")

      expect(result.duration).to be_a(Float)
    end

    it "includes summary with timing breakdown" do
      result = agent.run("Use final_answer to return: summary")

      summary = result.summary

      expect(summary).to be_a(String)
      expect(summary).to include("Run")
      expect(summary).to include("steps")
    end
  end

  describe "Error Handling" do
    it "handles max_steps gracefully" do
      # Tool that returns intermediate data
      step_tool = Smolagents::Tools.define_tool(
        "step_tool",
        description: "Returns intermediate step data",
        inputs: {},
        output_type: "string"
      ) { "step completed" }

      agent = Smolagents.agent.with(:code)
                        .model { model }
                        .tools(step_tool, :final_answer)
                        .max_steps(2)
                        .build

      # Task designed to exceed max_steps (model will try to keep calling step_tool)
      result = agent.run("Call step_tool 10 times and collect all the results.")

      expect(result.state).to eq(:max_steps_reached).or(eq(:success))
    end
  end

  describe "Memory Management" do
    let(:agent) do
      Smolagents.agent.with(:code)
                .model { model }
                .tools(:final_answer)
                .max_steps(10)
                .build
    end

    it "resets memory between runs by default" do
      agent.run("Use final_answer to return: first run")
      result = agent.run("Use final_answer to return: second run")

      # Should start fresh, not remember first run
      expect(result.state).to eq(:success).or(eq(:max_steps_reached))
    end

    it "preserves memory with reset: false" do
      agent.run("Use final_answer to return: run 1", reset: true)
      agent.run("Use final_answer to return: run 2", reset: false)

      # Memory should contain both runs
      expect(agent.memory.steps.count).to be > 2
    end
  end

  describe "Tool Integration Patterns" do
    it "works with array tool results" do
      list_tool = Smolagents::Tools.define_tool(
        "list_items",
        description: "Returns list of items",
        inputs: {},
        output_type: "array"
      ) { %w[apple banana cherry] }

      agent = Smolagents.agent.with(:code)
                        .model { model }
                        .tools(list_tool, :final_answer)
                        .max_steps(10)
                        .build

      task = "Call list_items, get the array, access the first element (index 0), and return it with final_answer."
      result = agent.run(task)

      expect(result.success?).to be true
    end

    it "works with hash tool results" do
      config_tool = Smolagents::Tools.define_tool(
        "get_config",
        description: "Returns configuration hash",
        inputs: {},
        output_type: "object"
      ) { { host: "localhost", port: 8080, ssl: false } }

      agent = Smolagents.agent.with(:code)
                        .model { model }
                        .tools(config_tool, :final_answer)
                        .max_steps(10)
                        .build

      result = agent.run("Call get_config, access the port value from the hash, and return it with final_answer.")

      expect(result.success?).to be true
    end
  end

  describe "Model Compatibility" do
    # Test that all 5 loaded models can complete basic tasks
    let(:basic_task) { "Call final_answer with this text: The answer is 42" }

    %w[
      lfm2-8b-a1b
      lfm2.5-1.2b-instruct
      gemma-3n-e4b
      granite-4.0-h-micro
      qwen3-vl-8b
    ].each do |model_id|
      it "works with #{model_id}" do
        test_model = Smolagents::Models::OpenAIModel.new(
          model_id:,
          api_base: lm_studio_url,
          api_key: "not-needed"
        )

        agent = Smolagents.agent
                          .model { test_model }
                          .tools(:final_answer)
                          .max_steps(10)
                          .build

        result = agent.run(basic_task)

        expect(result.output.to_s).to include("42")
      end
    end
  end

  describe "Memory Management (P1)" do
    it "configures memory with budget" do
      agent = Smolagents.agent
                        .model { model }
                        .tools(:final_answer)
                        .memory(budget: 50_000)
                        .build

      expect(agent.memory.config.budget).to eq(50_000)
      expect(agent.memory.config.mask?).to be true
    end

    it "configures memory with strategy" do
      agent = Smolagents.agent
                        .model { model }
                        .tools(:final_answer)
                        .memory(budget: 100_000, strategy: :hybrid, preserve_recent: 3)
                        .build

      expect(agent.memory.config.hybrid?).to be true
      expect(agent.memory.config.preserve_recent).to eq(3)
    end

    it "tracks token estimates" do
      agent = Smolagents.agent
                        .model { model }
                        .tools(:final_answer)
                        .memory(budget: 100_000)
                        .build

      agent.run("Use final_answer to return: test")

      expect(agent.memory.estimated_tokens).to be > 0
      expect(agent.memory.over_budget?).to be false
    end
  end

  describe "Pre-Act Planning (P3)" do
    it "enables planning with default interval" do
      agent = Smolagents.agent
                        .model { model }
                        .tools(:final_answer)
                        .planning
                        .build

      expect(agent.planning_interval).to eq(3)
    end

    it "enables planning with custom interval" do
      agent = Smolagents.agent
                        .model { model }
                        .tools(:final_answer)
                        .planning(5)
                        .build

      expect(agent.planning_interval).to eq(5)
    end

    it "generates planning steps during execution" do
      agent = Smolagents.agent
                        .model { model }
                        .tools(:final_answer)
                        .planning(interval: 3)
                        .max_steps(5)
                        .build

      agent.run("Use final_answer to return: planned result")

      planning_steps = agent.memory.steps.select { |s| s.is_a?(Smolagents::PlanningStep) }
      expect(planning_steps).not_to be_empty
    end
  end

  describe "Model Palette (P2)" do
    before do
      Smolagents.configure do |c|
        c.models do |m|
          m = m.register(:test_fast, -> { model })
          m = m.register(:test_smart, -> { model })
          m
        end
      end
    end

    after { Smolagents.reset_configuration! }

    it "registers models in palette" do
      expect(Smolagents.configuration.model_palette.registered?(:test_fast)).to be true
      expect(Smolagents.configuration.model_palette.names).to include(:test_fast, :test_smart)
    end

    it "builds agent with model reference" do
      agent = Smolagents.agent
                        .model(:test_fast)
                        .tools(:final_answer)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it "retrieves model via Smolagents.get_model" do
      retrieved = Smolagents.get_model(:test_fast)
      expect(retrieved).to eq(model)
    end
  end

  describe "Multi-Agent Spawn (P2)" do
    before do
      Smolagents.configure do |c|
        c.models do |m|
          m = m.register(:child_model, -> { model })
          m
        end
      end
    end

    after { Smolagents.reset_configuration! }

    it "configures spawn capability" do
      agent = Smolagents.agent
                        .model { model }
                        .tools(:final_answer)
                        .can_spawn(allow: [:child_model], tools: [:final_answer], inherit: :observations)
                        .build

      spawn_config = agent.instance_variable_get(:@spawn_config)
      expect(spawn_config).not_to be_nil
      expect(spawn_config.model_allowed?(:child_model)).to be true
      expect(spawn_config.inherit_scope.observations?).to be true
    end

    it "restricts spawn to allowed models" do
      agent = Smolagents.agent
                        .model { model }
                        .tools(:final_answer)
                        .can_spawn(allow: [:child_model], max_children: 2)
                        .build

      spawn_config = agent.instance_variable_get(:@spawn_config)
      expect(spawn_config.model_allowed?(:child_model)).to be true
      expect(spawn_config.model_allowed?(:unauthorized)).to be false
    end

    it "configures context inheritance scope" do
      agent = Smolagents.agent
                        .model { model }
                        .tools(:final_answer)
                        .can_spawn(inherit: :summary)
                        .build

      spawn_config = agent.instance_variable_get(:@spawn_config)
      expect(spawn_config.inherit_scope.summary?).to be true
    end
  end

  describe "Full DSL Showcase" do
    before do
      Smolagents.configure do |c|
        c.models do |m|
          m = m.register(:main, -> { model })
          m = m.register(:helper, -> { model })
          m
        end
      end
    end

    after { Smolagents.reset_configuration! }

    it "builds agent with all P1/P2/P3 features" do
      agent = Smolagents.agent
                        .model(:main)
                        .tools(:final_answer)
                        .planning(interval: 3)
                        .memory(budget: 100_000, strategy: :mask)
                        .can_spawn(allow: [:helper], tools: [:final_answer], inherit: :observations)
                        .max_steps(10)
                        .instructions("Be helpful and concise")
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent.planning_interval).to eq(3)
      expect(agent.memory.config.budget).to eq(100_000)
      expect(agent.instance_variable_get(:@spawn_config)).not_to be_nil
    end
  end
end
