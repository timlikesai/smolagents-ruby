RSpec.describe Smolagents::Concerns::ReActLoop::Control do
  describe ".provided_methods" do
    it "aggregates all sub-module methods" do
      methods = described_class.provided_methods

      # From FiberControl
      expect(methods).to include(:yield_control)
      expect(methods).to include(:ensure_fiber_context!)
      expect(methods).to include(:fiber_context?)

      # From UserInput
      expect(methods).to include(:request_input)

      # From Confirmation
      expect(methods).to include(:request_confirmation)

      # From Escalation
      expect(methods).to include(:escalate_query)

      # From SyncHandler
      expect(methods).to include(:consume_fiber)
    end

    it "provides descriptions for all methods" do
      methods = described_class.provided_methods
      methods.each_value do |description|
        expect(description).to be_a(String)
        expect(description.length).to be > 0
      end
    end
  end

  describe ".included" do
    let(:test_class) { Class.new { def emit(_); end } }

    before do
      test_class.include(described_class)
    end

    it "includes FiberControl" do
      expect(test_class.included_modules).to include(described_class::FiberControl)
    end

    it "includes UserInput" do
      expect(test_class.included_modules).to include(described_class::UserInput)
    end

    it "includes Confirmation" do
      expect(test_class.included_modules).to include(described_class::Confirmation)
    end

    it "includes Escalation" do
      expect(test_class.included_modules).to include(described_class::Escalation)
    end

    it "includes SyncHandler" do
      expect(test_class.included_modules).to include(described_class::SyncHandler)
    end

    it "provides all public control methods" do
      instance = test_class.new

      expect(instance).to respond_to(:request_input)
      expect(instance).to respond_to(:request_confirmation)
      expect(instance).to respond_to(:escalate_query)
    end
  end

  describe "integration" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::ReActLoop::Control

        def emit(_event); end
      end
    end

    let(:instance) { test_class.new }

    it "methods work together in fiber context" do
      set_fiber_context(true)

      fiber = Fiber.new do
        input = instance.request_input("What file?")
        confirmed = instance.request_confirmation(action: "delete", description: "Delete #{input}")
        confirmed ? "Deleted #{input}" : "Cancelled"
      end

      # First: user input request
      request1 = fiber.resume
      expect(request1).to be_a(Smolagents::Types::ControlRequests::UserInput)

      # Respond with filename
      response1 = Smolagents::Types::ControlRequests::Response.respond(request_id: request1.id, value: "config.yml")
      request2 = fiber.resume(response1)

      # Second: confirmation request
      expect(request2).to be_a(Smolagents::Types::ControlRequests::Confirmation)
      expect(request2.description).to eq("Delete config.yml")

      # Approve deletion
      response2 = Smolagents::Types::ControlRequests::Response.approve(request_id: request2.id)
      result = fiber.resume(response2)

      expect(result).to eq("Deleted config.yml")
    ensure
      clear_fiber_context
    end
  end
end
