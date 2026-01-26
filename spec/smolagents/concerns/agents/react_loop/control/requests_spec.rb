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

RSpec.describe Smolagents::Concerns::ReActLoop::Control::Escalation do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ReActLoop::Control::FiberControl
      include Smolagents::Concerns::ReActLoop::Control::Escalation

      def emit(_event); end
    end
  end

  let(:instance) { test_class.new }

  describe ".provided_methods" do
    it "documents available methods" do
      methods = described_class.provided_methods
      expect(methods).to include(escalate_query: kind_of(String))
    end
  end

  describe "#escalate_query" do
    it "raises when not in fiber context" do
      clear_fiber_context
      expect { instance.escalate_query("Help?") }
        .to raise_error(Smolagents::Errors::ControlFlowError)
    end

    it "yields SubAgentQuery request with all parameters" do
      set_fiber_context(true)

      fiber = Fiber.new do
        instance.escalate_query("What is the legal status?", options: { detail: "full" }, context: { topic: "law" })
      end

      request = fiber.resume
      expect(request).to be_a(Smolagents::Types::ControlRequests::SubAgentQuery)
      expect(request.query).to eq("What is the legal status?")
      expect(request.options).to eq({ detail: "full" })
      expect(request.context).to eq({ topic: "law" })
    ensure
      clear_fiber_context
    end

    it "returns the response value" do
      set_fiber_context(true)

      fiber = Fiber.new { instance.escalate_query("Help me") }
      request = fiber.resume

      response = Smolagents::Types::ControlRequests::Response.respond(request_id: request.id, value: "Answer here")
      result = fiber.resume(response)
      expect(result).to eq("Answer here")
    ensure
      clear_fiber_context
    end

    it "uses class name for agent_name" do
      # Create a named class
      named_class = Class.new(test_class)
      stub_const("TestAgent", named_class)
      named_instance = TestAgent.new

      set_fiber_context(true)

      fiber = Fiber.new { named_instance.escalate_query("Query") }
      request = fiber.resume
      expect(request.agent_name).to eq("testagent")
    ensure
      clear_fiber_context
    end

    it "falls back to 'agent' for anonymous classes" do
      set_fiber_context(true)

      fiber = Fiber.new { instance.escalate_query("Query") }
      request = fiber.resume
      expect(request.agent_name).to eq("agent")
    ensure
      clear_fiber_context
    end
  end
end
