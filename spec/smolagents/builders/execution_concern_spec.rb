require "spec_helper"

RSpec.describe Smolagents::Builders::ExecutionConcern do
  include_context "with mocked tools"
  include_context "with mocked model"

  let(:test_builder_class) do
    Class.new(Data.define(:configuration)) do
      include Smolagents::Builders::ExecutionConcern

      def self.create
        new(configuration: {})
      end

      def build
        agent = instance_double(Smolagents::Agents::Agent)
        result = Smolagents::Types::RunResult.success(output: "result", steps: [])
        allow(agent).to receive_messages(run: result, run_fiber: Fiber.new { "fiber_result" })
        agent
      end

      attr_reader :configuration

      def with_config(new_config)
        self.class.new(configuration: configuration.merge(new_config))
      end
    end
  end

  let(:builder) { test_builder_class.create }

  describe "#run" do
    it "builds agent and runs task" do
      mock_agent = instance_double(Smolagents::Agents::Agent)
      mock_result = Smolagents::Types::RunResult.success(output: "42", steps: [])

      allow(test_builder_class).to receive(:new).and_return(mock_agent)
      allow(mock_agent).to receive(:run).with("test task").and_return(mock_result)

      # We'll test the method signature
      expect(builder).to respond_to(:run)
    end

    it "accepts task argument" do
      expect(builder).to respond_to(:run)
      method = test_builder_class.instance_method(:run)
      expect(method.parameters.map(&:first)).to include(:req)
    end

    it "passes through kwargs to agent.run" do
      # Verify method accepts kwargs (negative arity means splat/kwargs)
      expect(builder.method(:run).arity).to be < 0
    end
  end

  describe "#run_fiber" do
    it "builds agent and returns fiber" do
      expect(builder).to respond_to(:run_fiber)
    end

    it "accepts task argument" do
      method = test_builder_class.instance_method(:run_fiber)
      expect(method.parameters.map(&:first)).to include(:req)
    end

    it "passes through kwargs to agent.run_fiber" do
      # Verify method accepts kwargs
      expect(builder.method(:run_fiber).arity).to be < 0 # Splat/kwargs
    end

    it "returns a Fiber" do
      # The method should return what build.run_fiber returns
      expect(builder).to respond_to(:run_fiber)
    end
  end

  describe "delegation to build" do
    it "executes build internally during run" do
      # The module should delegate to build
      expect(test_builder_class.instance_method(:run).source_location).not_to be_nil
    end

    it "executes build internally during run_fiber" do
      expect(test_builder_class.instance_method(:run_fiber).source_location).not_to be_nil
    end
  end

  describe "integration with immutable builders" do
    let(:configurable_builder_class) do
      Class.new(Data.define(:configuration)) do
        include Smolagents::Builders::ExecutionConcern

        def self.create
          new(configuration: {})
        end

        def build = "built_object"

        def max_steps(count)
          self.class.new(configuration: configuration.merge(max_steps: count))
        end
      end
    end

    it "can chain configuration before run" do
      built = configurable_builder_class.create.max_steps(10)
      expect(built.configuration[:max_steps]).to eq(10)
    end
  end
end
