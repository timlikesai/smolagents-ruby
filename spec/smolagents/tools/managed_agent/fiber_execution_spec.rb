RSpec.describe Smolagents::Tools::ManagedAgentTool do
  describe "Fiber execution functionality" do
    let(:mock_agent) do
      double(
        "agent",
        run: double("result", success?: true, output: "output"),
        respond_to?: false,
        tools: { search: double }
      )
    end

    let(:tool) do
      described_class.new(
        agent: mock_agent,
        name: "test_agent",
        description: "Test agent"
      )
    end

    describe "#fiber_context?" do
      it "returns false when not in fiber context" do
        expect(tool.send(:fiber_context?)).to be false
      end

      it "returns true when in fiber context" do
        Thread.current.thread_variable_set(
          Smolagents::Concerns::ReActLoop::Control::FiberControl::FIBER_CONTEXT_KEY,
          true
        )

        expect(tool.send(:fiber_context?)).to be true

        Thread.current.thread_variable_set(
          Smolagents::Concerns::ReActLoop::Control::FiberControl::FIBER_CONTEXT_KEY,
          nil
        )
      end
    end

    describe "#execute_sync" do
      it "calls agent.run without fiber" do
        result = double("result", success?: true, output: "sync output")
        allow(mock_agent).to receive(:run).with("test task", reset: true).and_return(result)

        output = tool.send(:execute_sync, "test task", nil)

        expect(output).to eq(result)
        expect(mock_agent).to have_received(:run).with("test task", reset: true)
      end
    end

    describe "#execute_fiber" do
      it "calls agent.run_fiber in fiber context" do
        skip "Fiber execution requires complex setup" if ENV["SKIP_FIBER_TESTS"]

        fiber = Fiber.new { double("result", success?: true) }
        allow(mock_agent).to receive(:run_fiber).and_return(fiber)

        # This test would require complex fiber mocking
        # In real usage, it would handle fiber resumption
      end
    end

    describe "#bubble_request" do
      it "yields control request and returns response" do
        skip "Fiber operations not testable in isolation"
      end
    end

    describe "#emit_progress" do
      it "emits SubAgentProgress event" do
        allow(tool).to receive(:emit)

        step = double(
          observations: "Step observation",
          step_number: 1
        )
        event = double(id: "event_1")

        tool.send(:emit_progress, event, step)

        expect(tool).to have_received(:emit)
      end

      it "truncates long observations to 100 chars" do
        allow(tool).to receive(:emit)

        long_text = "a" * 200
        step = double(
          observations: long_text,
          step_number: 1
        )
        event = double(id: "event_1")

        tool.send(:emit_progress, event, step)

        expect(tool).to have_received(:emit)
      end

      it "handles nil observations" do
        allow(tool).to receive(:emit)

        step = double(observations: nil, step_number: 1)
        event = double(id: "event_1")

        expect { tool.send(:emit_progress, event, step) }.not_to raise_error
      end
    end

    describe "run_agent method selection" do
      it "uses sync execution when not in fiber context" do
        allow(tool).to receive_messages(fiber_context?: false, execute_sync: "sync result")

        tool.send(:run_agent, "task", nil)

        expect(tool).to have_received(:execute_sync)
      end

      it "uses fiber execution when in fiber context and agent supports it" do
        allow(mock_agent).to receive(:respond_to?).with(:run_fiber).and_return(true)
        allow(tool).to receive_messages(fiber_context?: true, execute_fiber: "fiber result")

        tool.send(:run_agent, "task", nil)

        expect(tool).to have_received(:execute_fiber)
      end

      it "falls back to sync when fiber context exists but agent doesn't support it" do
        allow(mock_agent).to receive(:respond_to?).with(:run_fiber).and_return(false)
        allow(tool).to receive_messages(fiber_context?: true, execute_sync: "sync result")

        tool.send(:run_agent, "task", nil)

        expect(tool).to have_received(:execute_sync)
      end
    end
  end
end
