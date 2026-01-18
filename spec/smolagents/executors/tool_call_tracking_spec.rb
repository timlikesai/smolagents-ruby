RSpec.describe Smolagents::Executors::Executor::ToolCallTracking do
  let(:executor) { Smolagents::Executors::LocalRuby.new }

  let(:simple_tool) do
    Smolagents::Tools.define_tool(
      "simple",
      description: "A simple tool",
      inputs: { value: { type: "integer", description: "A value" } },
      output_type: "integer"
    ) { |value:| value * 2 }
  end

  before { executor.send_tools(simple: simple_tool) }

  describe "#tool_calls" do
    it "starts empty" do
      expect(executor.tool_calls).to be_empty
    end

    it "tracks tool calls during execution" do
      executor.execute("simple(value: 5)", language: :ruby)

      expect(executor.tool_calls.size).to eq(1)
      expect(executor.tool_calls.first.tool_name).to eq("simple")
      expect(executor.tool_calls.first.result.data).to eq(10)
    end

    it "tracks multiple tool calls" do
      executor.execute("simple(value: 1); simple(value: 2)", language: :ruby)

      expect(executor.tool_calls.size).to eq(2)
      expect(executor.tool_calls.map(&:tool_name)).to eq(%w[simple simple])
    end

    it "records duration for each call" do
      executor.execute("simple(value: 5)", language: :ruby)

      expect(executor.tool_calls.first.duration).to be_a(Float)
    end

    it "records errors when tool call fails" do
      error_tool = Smolagents::Tools.define_tool(
        "failing",
        description: "A tool that fails",
        inputs: {},
        output_type: "string"
      ) { raise "Tool error" }

      executor.send_tools(failing: error_tool)
      result = executor.execute("failing()", language: :ruby)

      expect(result.error).to include("Tool error")
      expect(executor.tool_calls.first.error).to include("Tool error")
    end
  end

  describe "#clear_tool_calls" do
    it "clears tracked calls between executions" do
      executor.execute("simple(value: 1)", language: :ruby)
      expect(executor.tool_calls.size).to eq(1)

      executor.execute("simple(value: 2)", language: :ruby)
      expect(executor.tool_calls.size).to eq(1) # Cleared and new call tracked
      expect(executor.tool_calls.first.result.data).to eq(4) # 2 * 2
    end
  end

  describe Smolagents::Executors::Executor::ToolCallTracking::TrackedCall do
    let(:call) do
      described_class.new(
        tool_name: "test",
        arguments: { x: 1 },
        result: "ok",
        duration: 0.5,
        error: nil
      )
    end

    it "has success? predicate" do
      expect(call).to be_success
    end

    it "returns false for success? when error present" do
      error_call = described_class.new(
        tool_name: "test",
        arguments: {},
        result: nil,
        duration: 0.1,
        error: "boom"
      )
      expect(error_call).not_to be_success
    end

    it "converts to hash" do
      expect(call.to_h).to eq(
        tool_name: "test",
        arguments: { x: 1 },
        result: "ok",
        duration: 0.5,
        error: nil
      )
    end
  end
end
