RSpec.describe Smolagents::Testing::SpyTool do
  subject(:spy) { described_class.new("test_spy") }

  describe "#initialize" do
    it "sets the tool name" do
      expect(spy.name).to eq("test_spy")
    end

    it "defaults name to spy_tool" do
      tool = described_class.new

      expect(tool.name).to eq("spy_tool")
    end

    it "defaults return_value to ok" do
      expect(spy.return_value).to eq("ok")
    end

    it "accepts custom return_value" do
      tool = described_class.new("custom", return_value: 42)

      expect(tool.return_value).to eq(42)
    end

    it "starts with empty calls" do
      expect(spy.calls).to be_empty
    end

    it "inherits from Tools::Tool" do
      expect(spy).to be_a(Smolagents::Tools::Tool)
    end
  end

  describe "#name" do
    it "overrides class-level tool_name per instance" do
      tool_a = described_class.new("search")
      tool_b = described_class.new("calculator")

      expect(tool_a.name).to eq("search")
      expect(tool_b.name).to eq("calculator")
    end
  end

  describe "#execute" do
    it "records keyword arguments" do
      spy.execute(query: "Ruby", limit: 10)

      expect(spy.calls).to eq([{ query: "Ruby", limit: 10 }])
    end

    it "records multiple calls independently" do
      spy.execute(query: "Ruby")
      spy.execute(query: "Python")
      spy.execute(query: "Elixir")

      expected = [{ query: "Ruby" }, { query: "Python" }, { query: "Elixir" }]

      expect(spy.calls).to eq(expected)
    end

    it "returns the configured return_value" do
      result = spy.execute(x: 1)

      expect(result).to eq("ok")
    end

    it "returns custom return_value" do
      tool = described_class.new("spy", return_value: { status: "success", data: [1, 2, 3] })

      result = tool.execute(query: "test")

      expect(result).to eq({ status: "success", data: [1, 2, 3] })
    end

    it "returns nil when configured with nil" do
      tool = described_class.new("spy", return_value: nil)

      expect(tool.execute(x: 1)).to be_nil
    end

    it "records call with no arguments" do
      spy.execute

      expect(spy.calls).to eq([{}])
    end

    it "returns the same value on every call" do
      results = Array.new(3) { spy.execute(n: it) }

      expect(results).to all(eq("ok"))
    end
  end

  describe "#called?" do
    it "returns false before any calls" do
      expect(spy.called?).to be false
    end

    it "returns true after one call" do
      spy.execute(x: 1)

      expect(spy.called?).to be true
    end

    it "returns true after multiple calls" do
      3.times { spy.execute(x: 1) }

      expect(spy.called?).to be true
    end
  end

  describe "#call_count" do
    it "returns zero before any calls" do
      expect(spy.call_count).to eq(0)
    end

    it "counts each invocation" do
      5.times { spy.execute(n: 1) }

      expect(spy.call_count).to eq(5)
    end
  end

  describe "#last_call" do
    it "returns nil when no calls made" do
      expect(spy.last_call).to be_nil
    end

    it "returns the most recent call arguments" do
      spy.execute(query: "first")
      spy.execute(query: "second")
      spy.execute(query: "third")

      expect(spy.last_call).to eq({ query: "third" })
    end
  end

  describe "#calls" do
    it "preserves call order" do
      spy.execute(step: 1)
      spy.execute(step: 2)
      spy.execute(step: 3)

      expect(spy.calls.map { it[:step] }).to eq([1, 2, 3])
    end

    it "preserves all keyword arguments per call" do
      spy.execute(a: 1, b: "two", c: [3])

      expect(spy.calls.first).to eq({ a: 1, b: "two", c: [3] })
    end
  end

  describe "#reset!" do
    before do
      spy.execute(query: "Ruby")
      spy.execute(query: "Python")
    end

    it "clears all recorded calls" do
      spy.reset!

      expect(spy.calls).to be_empty
    end

    it "resets call_count to zero" do
      spy.reset!

      expect(spy.call_count).to eq(0)
    end

    it "resets called? to false" do
      spy.reset!

      expect(spy.called?).to be false
    end

    it "resets last_call to nil" do
      spy.reset!

      expect(spy.last_call).to be_nil
    end

    it "allows recording new calls after reset" do
      spy.reset!
      spy.execute(query: "Elixir")

      expect(spy.call_count).to eq(1)
      expect(spy.last_call).to eq({ query: "Elixir" })
    end

    it "does not change the return_value" do
      tool = described_class.new("spy", return_value: "custom")
      tool.execute(x: 1)
      tool.reset!

      expect(tool.return_value).to eq("custom")
      expect(tool.execute(x: 2)).to eq("custom")
    end
  end

  describe "instance independence" do
    it "tracks calls independently per instance" do
      tool_a = described_class.new("search")
      tool_b = described_class.new("calculator")

      tool_a.execute(query: "Ruby")
      tool_b.execute(value: 42)

      expect(tool_a.calls).to eq([{ query: "Ruby" }])
      expect(tool_b.calls).to eq([{ value: 42 }])
    end

    it "resets independently per instance" do
      tool_a = described_class.new("search")
      tool_b = described_class.new("calculator")

      tool_a.execute(query: "Ruby")
      tool_b.execute(value: 42)

      tool_a.reset!

      expect(tool_a.calls).to be_empty
      expect(tool_b.calls).to eq([{ value: 42 }])
    end
  end

  describe "tool metadata" do
    it "has a description" do
      expect(described_class.description).to eq("Records all calls for testing")
    end

    it "has empty inputs" do
      expect(described_class.inputs).to eq({})
    end

    it "has string output_type" do
      expect(described_class.output_type).to eq("string")
    end
  end
end
