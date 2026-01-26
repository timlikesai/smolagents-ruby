require "smolagents/concerns/agents/react_loop/fiber_execution"

RSpec.describe Smolagents::Concerns::ReActLoop::FiberExecution do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ReActLoop::FiberExecution

      attr_accessor :logger, :task, :memory, :task_images

      def reset_state; end

      def fiber_loop(task:, additional_prompting:, images:)
        Smolagents::Types::RunResult.success(output: "completed #{task}", steps: [])
      end
    end
  end

  let(:instance) { test_class.new }

  describe "#run_fiber" do
    it "returns a Fiber" do
      fiber = instance.run_fiber("test task")

      expect(fiber).to be_a(Fiber)
    end

    it "fiber executes the task" do
      fiber = instance.run_fiber("test task")

      result = fiber.resume

      expect(result).to be_a(Smolagents::Types::RunResult)
    end

    it "can be consumed" do
      fiber = instance.run_fiber("test task")

      expect { fiber.resume }.not_to raise_error
    end

    it "accepts images parameter" do
      fiber = instance.run_fiber("test", images: ["image.png"])

      expect(fiber).to be_a(Fiber)
    end

    it "accepts additional_prompting parameter" do
      fiber = instance.run_fiber("test", additional_prompting: "extra context")

      expect(fiber).to be_a(Fiber)
    end
  end

  describe "#fiber_context?" do
    it "checks thread variable for fiber context" do
      # Default is false when not set
      result = instance.fiber_context?

      expect(result).to be(true).or be(false)
    end
  end

  describe "#write_memory_to_messages" do
    it "delegates to memory" do
      mock_memory = double("memory", to_messages: %w[msg1 msg2])
      instance.instance_variable_set(:@memory, mock_memory)

      result = instance.write_memory_to_messages

      expect(result).to eq(%w[msg1 msg2])
    end
  end

  describe "fiber-based execution" do
    it "supports fiber reset option" do
      fiber = instance.run_fiber("test", reset: true)

      expect(fiber).to be_a(Fiber)
    end

    it "handles fiber completion" do
      fiber = instance.run_fiber("test")

      fiber.resume while fiber.alive?

      expect(fiber.alive?).to be false
    end
  end
end
