RSpec.describe Smolagents::Concerns::ReActLoop::Control::FiberControl do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ReActLoop::Control::FiberControl

      # Stub emit for testing
      def emit(_event); end
    end
  end

  let(:instance) { test_class.new }

  describe ".provided_methods" do
    it "documents available methods" do
      methods = described_class.provided_methods
      expect(methods).to include(
        yield_control: kind_of(String),
        ensure_fiber_context!: kind_of(String),
        fiber_context?: kind_of(String)
      )
    end
  end

  describe "#fiber_context?" do
    it "returns false when not in fiber context" do
      clear_fiber_context
      expect(instance.send(:fiber_context?)).to be false
    end

    it "returns true when in fiber context" do
      set_fiber_context(true)
      expect(instance.send(:fiber_context?)).to be true
    ensure
      clear_fiber_context
    end
  end

  describe "#ensure_fiber_context!" do
    it "raises ControlFlowError when not in fiber context" do
      clear_fiber_context
      expect { instance.send(:ensure_fiber_context!) }
        .to raise_error(Smolagents::Errors::ControlFlowError, /Fiber context/)
    end

    it "does not raise when in fiber context" do
      set_fiber_context(true)
      expect { instance.send(:ensure_fiber_context!) }.not_to raise_error
    ensure
      clear_fiber_context
    end
  end

  describe "#yield_control" do
    let(:request) do
      Smolagents::Types::ControlRequests::UserInput.create(prompt: "Test?")
    end

    let(:response) do
      Smolagents::Types::ControlRequests::Response.respond(request_id: request.id, value: "answer")
    end

    it "yields the request and returns the response" do
      set_fiber_context(true)

      fiber = Fiber.new do
        instance.send(:yield_control, request)
      end

      yielded = fiber.resume
      expect(yielded).to eq(request)

      result = fiber.resume(response)
      expect(result).to eq(response)
    ensure
      clear_fiber_context
    end
  end

  describe "#request_type_sym" do
    it "extracts symbol from class name" do
      request = Smolagents::Types::ControlRequests::UserInput.create(prompt: "Test?")
      expect(instance.send(:request_type_sym, request)).to eq(:userinput)
    end
  end

  describe "#extract_prompt" do
    it "extracts prompt from UserInput" do
      request = Smolagents::Types::ControlRequests::UserInput.create(prompt: "What is X?")
      expect(instance.send(:extract_prompt, request)).to eq("What is X?")
    end

    it "extracts query from SubAgentQuery" do
      request = Smolagents::Types::ControlRequests::SubAgentQuery.create(agent_name: "test", query: "Help me")
      expect(instance.send(:extract_prompt, request)).to eq("Help me")
    end

    it "extracts description from Confirmation" do
      request = Smolagents::Types::ControlRequests::Confirmation.create(
        action: "delete", description: "Delete file"
      )
      expect(instance.send(:extract_prompt, request)).to eq("Delete file")
    end
  end
end
