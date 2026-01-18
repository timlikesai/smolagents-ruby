RSpec.describe Smolagents::Concerns::ReActLoop::Control::SyncHandler do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ReActLoop::Control::SyncHandler
    end
  end

  let(:instance) { test_class.new }

  describe ".provided_methods" do
    it "documents available methods" do
      methods = described_class.provided_methods
      expect(methods).to include(consume_fiber: kind_of(String))
    end
  end

  describe "#consume_fiber" do
    it "returns final RunResult" do
      result = Smolagents::Types::RunResult.success(output: "done", steps: [])
      fiber = Fiber.new { result }

      consumed = instance.send(:consume_fiber, fiber)
      expect(consumed).to eq(result)
    end

    it "skips ActionStep and continues" do
      step = Smolagents::Types::ActionStep.new(step_number: 1)
      result = Smolagents::Types::RunResult.success(output: "done", steps: [step])

      fiber = Fiber.new do
        Fiber.yield(step) # First yield ActionStep
        result            # Final return RunResult
      end

      consumed = instance.send(:consume_fiber, fiber)
      expect(consumed).to eq(result)
    end

    it "auto-approves reversible confirmations" do
      confirmation = Smolagents::Types::ControlRequests::Confirmation.create(
        action: "update", description: "Update file", reversible: true
      )
      result = Smolagents::Types::RunResult.success(output: "done", steps: [])

      received_response = nil

      fiber = Fiber.new do
        received_response = Fiber.yield(confirmation) # Yield confirmation, receive response
        result
      end

      consumed = instance.send(:consume_fiber, fiber)

      expect(received_response).to be_a(Smolagents::Types::ControlRequests::Response)
      expect(received_response.approved?).to be true
      expect(consumed).to eq(result)
    end

    it "uses default value for :default sync behavior" do
      user_input = Smolagents::Types::ControlRequests::UserInput.create(
        prompt: "Name?", default_value: "default_name"
      )
      result = Smolagents::Types::RunResult.success(output: "done", steps: [])

      received_response = nil

      fiber = Fiber.new do
        received_response = Fiber.yield(user_input) # Yield input request, receive response
        result
      end

      consumed = instance.send(:consume_fiber, fiber)

      expect(received_response.value).to eq("default_name")
      expect(consumed).to eq(result)
    end

    it "raises for :raise sync behavior" do
      # Non-reversible confirmations have :raise behavior
      confirmation = Smolagents::Types::ControlRequests::Confirmation.create(
        action: "destroy", description: "Destroy database", reversible: false
      )

      fiber = Fiber.new { confirmation }

      expect { instance.send(:consume_fiber, fiber) }
        .to raise_error(Smolagents::Errors::ControlFlowError, /cannot be handled in sync mode/)
    end

    it "returns nil for :skip sync behavior" do
      sub_query = Smolagents::Types::ControlRequests::SubAgentQuery.create(
        agent_name: "helper", query: "What is X?"
      )
      result = Smolagents::Types::RunResult.success(output: "done", steps: [])

      received_response = nil

      fiber = Fiber.new do
        received_response = Fiber.yield(sub_query) # Yield sub-query, receive response
        result
      end

      consumed = instance.send(:consume_fiber, fiber)

      expect(received_response.value).to be_nil
      expect(consumed).to eq(result)
    end
  end

  describe "#handle_sync_control_request" do
    it "handles :approve behavior" do
      request = Smolagents::Types::ControlRequests::Confirmation.create(
        action: "update", description: "Update", reversible: true
      )

      response = instance.send(:handle_sync_control_request, request)
      expect(response.approved?).to be true
    end

    it "handles :skip behavior" do
      request = Smolagents::Types::ControlRequests::SubAgentQuery.create(
        agent_name: "test", query: "Help"
      )

      response = instance.send(:handle_sync_control_request, request)
      expect(response.value).to be_nil
    end

    it "handles :default behavior with default_value" do
      request = Smolagents::Types::ControlRequests::UserInput.create(
        prompt: "Name?", default_value: "Alice"
      )

      response = instance.send(:handle_sync_control_request, request)
      expect(response.value).to eq("Alice")
    end

    it "raises for :default behavior without default_value" do
      request = Smolagents::Types::ControlRequests::UserInput.create(
        prompt: "Name?"
      )

      expect { instance.send(:handle_sync_control_request, request) }
        .to raise_error(Smolagents::Errors::ControlFlowError)
    end
  end
end
