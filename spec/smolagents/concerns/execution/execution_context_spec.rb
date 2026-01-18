RSpec.describe Smolagents::Concerns::ExecutionContext do
  before do
    stub_const("TestExecutionContext", Class.new do
      include Smolagents::Concerns::ExecutionContext

      attr_accessor :state, :spawn_config, :max_steps, :tools

      def initialize(executor: nil, authorized_imports: nil, state: {}, max_steps: nil, spawn_config: nil)
        @state = state
        @max_steps = max_steps
        @spawn_config = spawn_config
        @tools = {}
        setup_code_execution(executor:, authorized_imports:)
      end
    end)
  end

  let(:mock_executor) do
    instance_double(Smolagents::Executors::Executor, send_tools: nil)
  end

  describe "#setup_code_execution" do
    context "with custom executor" do
      it "sets the executor" do
        context = TestExecutionContext.new(executor: mock_executor)

        expect(context.instance_variable_get(:@executor)).to eq(mock_executor)
      end
    end

    context "with custom authorized_imports" do
      it "sets authorized_imports" do
        context = TestExecutionContext.new(authorized_imports: %w[json yaml])

        expect(context.instance_variable_get(:@authorized_imports)).to eq(%w[json yaml])
      end
    end

    context "with defaults" do
      before do
        allow(Smolagents.configuration).to receive(:authorized_imports).and_return(["csv"])
      end

      it "uses LocalRubyExecutor by default" do
        context = TestExecutionContext.new

        expect(context.instance_variable_get(:@executor)).to be_a(Smolagents::LocalRubyExecutor)
      end

      it "uses configuration authorized_imports" do
        context = TestExecutionContext.new

        expect(context.instance_variable_get(:@authorized_imports)).to eq(["csv"])
      end
    end
  end

  describe "#finalize_code_execution" do
    it "sends tools to executor" do
      context = TestExecutionContext.new(executor: mock_executor)
      context.tools = { "search" => double }

      context.finalize_code_execution

      expect(mock_executor).to have_received(:send_tools).with(context.tools)
    end
  end

  describe "#build_execution_variables" do
    it "includes state variables" do
      context = TestExecutionContext.new(
        executor: mock_executor,
        state: { "query" => "test", "count" => 5 }
      )

      vars = context.build_execution_variables

      expect(vars["query"]).to eq("test")
      expect(vars["count"]).to eq(5)
    end

    context "with action_step and max_steps" do
      it "includes step context" do
        context = TestExecutionContext.new(
          executor: mock_executor,
          max_steps: 10
        )
        action_step = Smolagents::ActionStepBuilder.new(step_number: 3)

        vars = context.build_execution_variables(action_step)

        expect(vars["_step"]).to eq(3)
        expect(vars["_max_steps"]).to eq(10)
        expect(vars["_steps_remaining"]).to eq(7)
      end

      it "clamps steps_remaining to zero" do
        context = TestExecutionContext.new(
          executor: mock_executor,
          max_steps: 5
        )
        action_step = Smolagents::ActionStepBuilder.new(step_number: 10)

        vars = context.build_execution_variables(action_step)

        expect(vars["_steps_remaining"]).to eq(0)
      end
    end

    context "without max_steps" do
      it "does not include step context" do
        context = TestExecutionContext.new(executor: mock_executor)
        action_step = Smolagents::ActionStepBuilder.new(step_number: 3)

        vars = context.build_execution_variables(action_step)

        expect(vars).not_to have_key("_step")
        expect(vars).not_to have_key("_max_steps")
        expect(vars).not_to have_key("_steps_remaining")
      end
    end

    context "with spawn_config" do
      it "includes spawn function" do
        spawn_config = Smolagents::Types::SpawnConfig.create(allow: [:default])
        context = TestExecutionContext.new(
          executor: mock_executor,
          spawn_config:
        )

        # Mock the spawn function creation
        allow(Smolagents::Runtime::Spawn).to receive(:create_spawn_function)
          .and_return(->(task) { "spawned: #{task}" })

        vars = context.build_execution_variables

        expect(vars["spawn"]).to be_a(Proc)
      end
    end
  end
end
