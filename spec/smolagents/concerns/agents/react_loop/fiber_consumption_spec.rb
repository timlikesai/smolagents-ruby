require "smolagents/concerns/agents/react_loop/fiber_consumption"

RSpec.describe Smolagents::Concerns::ReActLoop::FiberConsumption do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ReActLoop::FiberConsumption

      attr_accessor :logger

      def run_fiber(_task, reset: true, images: nil, additional_prompting: nil)
        Fiber.new { Smolagents::Types::RunResult.success(output: "done", steps: []) }
      end
    end
  end

  let(:instance) { test_class.new }

  describe "#consume_fiber" do
    it "consumes fiber to completion and returns RunResult" do
      fiber = Fiber.new do
        Smolagents::Types::RunResult.success(output: "result", steps: [])
      end

      result = instance.send(:consume_fiber, fiber)

      expect(result).to be_a(Smolagents::Types::RunResult)
      expect(result.output).to eq("result")
    end

    it "skips ActionStep and continues" do
      action_step = Smolagents::Types::ActionStep.new(
        step_number: 1,
        action_output: "test",
        observations: "obs"
      )

      fiber = Fiber.new do
        Fiber.yield(action_step)
        Smolagents::Types::RunResult.success(output: "done", steps: [])
      end

      result = instance.send(:consume_fiber, fiber)

      expect(result).to be_a(Smolagents::Types::RunResult)
      expect(result.output).to eq("done")
    end
  end

  describe "#drain_fiber_to_enumerator" do
    it "returns an Enumerator" do
      fiber = Fiber.new do
        Smolagents::Types::RunResult.success(output: "done", steps: [])
      end

      result = instance.send(:drain_fiber_to_enumerator, fiber)

      expect(result).to be_a(Enumerator)
    end

    it "yields ActionStep objects" do
      step1 = Smolagents::Types::ActionStep.new(step_number: 1, action_output: "1", observations: "obs1")
      step2 = Smolagents::Types::ActionStep.new(step_number: 2, action_output: "2", observations: "obs2")

      fiber = Fiber.new do
        Fiber.yield(step1)
        Fiber.yield(step2)
        Smolagents::Types::RunResult.success(output: "done", steps: [])
      end

      enumerator = instance.send(:drain_fiber_to_enumerator, fiber)
      steps = enumerator.to_a

      expect(steps.size).to eq(2)
      expect(steps.first).to eq(step1)
      expect(steps.last).to eq(step2)
    end
  end

  describe "#auto_approve" do
    it "creates an approve response" do
      request = Smolagents::Types::ControlRequests::UserInput.create(
        prompt: "test"
      )

      response = instance.send(:auto_approve, request)

      expect(response).to be_a(Smolagents::Types::ControlRequests::Response)
      expect(response.request_id).to eq(request.id)
    end
  end

  describe "#run_sync" do
    it "executes fiber synchronously and returns result" do
      allow(instance).to receive(:run_fiber).and_return(
        Fiber.new { Smolagents::Types::RunResult.success(output: "sync result", steps: []) }
      )

      result = instance.send(:run_sync, "task", images: nil, additional_prompting: nil)

      expect(result).to be_a(Smolagents::Types::RunResult)
      expect(result.output).to eq("sync result")
    end
  end

  describe "#run_stream" do
    it "returns an Enumerator for streaming" do
      step = Smolagents::Types::ActionStep.new(step_number: 1, action_output: "test", observations: "obs")

      fiber = Fiber.new do
        Fiber.yield(step)
        Smolagents::Types::RunResult.success(output: "done", steps: [])
      end

      allow(instance).to receive(:run_fiber).and_return(fiber)

      result = instance.send(:run_stream, task: "task")

      expect(result).to be_a(Enumerator)
    end
  end
end
