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
