RSpec.describe Smolagents::Concerns::ReActLoop::Control::Confirmation do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ReActLoop::Control::FiberControl
      include Smolagents::Concerns::ReActLoop::Control::Confirmation

      def emit(_event); end
    end
  end

  let(:instance) { test_class.new }

  describe ".provided_methods" do
    it "documents available methods" do
      methods = described_class.provided_methods
      expect(methods).to include(request_confirmation: kind_of(String))
    end
  end

  describe "#request_confirmation" do
    it "raises when not in fiber context" do
      clear_fiber_context
      expect { instance.request_confirmation(action: "delete", description: "Delete file") }
        .to raise_error(Smolagents::Errors::ControlFlowError)
    end

    it "yields Confirmation request with all parameters" do
      set_fiber_context(true)

      fiber = Fiber.new do
        instance.request_confirmation(
          action: "delete_all",
          description: "Delete all files",
          consequences: ["Data loss"],
          reversible: false
        )
      end

      request = fiber.resume
      expect(request).to be_a(Smolagents::Types::ControlRequests::Confirmation)
      expect(request.action).to eq("delete_all")
      expect(request.description).to eq("Delete all files")
      expect(request.consequences).to eq(["Data loss"])
      expect(request.reversible).to be false
    ensure
      clear_fiber_context
    end

    it "returns true when approved" do
      set_fiber_context(true)

      fiber = Fiber.new do
        instance.request_confirmation(action: "delete", description: "Delete file")
      end

      request = fiber.resume
      response = Smolagents::Types::ControlRequests::Response.approve(request_id: request.id)
      result = fiber.resume(response)
      expect(result).to be true
    ensure
      clear_fiber_context
    end

    it "returns false when denied" do
      set_fiber_context(true)

      fiber = Fiber.new do
        instance.request_confirmation(action: "delete", description: "Delete file")
      end

      request = fiber.resume
      response = Smolagents::Types::ControlRequests::Response.deny(request_id: request.id, reason: "No")
      result = fiber.resume(response)
      expect(result).to be false
    ensure
      clear_fiber_context
    end

    it "defaults to reversible: true" do
      set_fiber_context(true)

      fiber = Fiber.new do
        instance.request_confirmation(action: "update", description: "Update config")
      end

      request = fiber.resume
      expect(request.reversible).to be true
    ensure
      clear_fiber_context
    end
  end
end
