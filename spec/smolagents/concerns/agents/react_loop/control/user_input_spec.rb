RSpec.describe Smolagents::Concerns::ReActLoop::Control::UserInput do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ReActLoop::Control::FiberControl
      include Smolagents::Concerns::ReActLoop::Control::UserInput

      def emit(_event); end
    end
  end

  let(:instance) { test_class.new }

  describe ".provided_methods" do
    it "documents available methods" do
      methods = described_class.provided_methods
      expect(methods).to include(request_input: kind_of(String))
    end
  end

  describe "#request_input" do
    it "raises when not in fiber context" do
      clear_fiber_context
      expect { instance.request_input("What?") }
        .to raise_error(Smolagents::Errors::ControlFlowError)
    end

    it "yields UserInput request and returns response value" do
      set_fiber_context(true)

      fiber = Fiber.new do
        instance.request_input("What file?", options: %w[a b], timeout: 30, context: { key: "val" })
      end

      request = fiber.resume
      expect(request).to be_a(Smolagents::Types::ControlRequests::UserInput)
      expect(request.prompt).to eq("What file?")
      expect(request.options).to eq(%w[a b])
      expect(request.timeout).to eq(30)
      expect(request.context).to eq({ key: "val" })

      response = Smolagents::Types::ControlRequests::Response.respond(request_id: request.id, value: "file.txt")
      result = fiber.resume(response)
      expect(result).to eq("file.txt")
    ensure
      clear_fiber_context
    end

    it "returns nil when response value is nil" do
      set_fiber_context(true)

      fiber = Fiber.new { instance.request_input("Prompt") }
      request = fiber.resume

      response = Smolagents::Types::ControlRequests::Response.respond(request_id: request.id, value: nil)
      result = fiber.resume(response)
      expect(result).to be_nil
    ensure
      clear_fiber_context
    end
  end
end
