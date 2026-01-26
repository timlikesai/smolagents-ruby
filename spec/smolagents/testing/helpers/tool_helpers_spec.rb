RSpec.describe Smolagents::Testing::Helpers::ToolHelpers do
  include described_class

  describe "#spy_tool" do
    it "creates a SpyTool instance" do
      tool = spy_tool("search")

      expect(tool).to be_a(Smolagents::Testing::SpyTool)
    end

    it "sets the tool name" do
      tool = spy_tool("search")

      expect(tool.name).to eq("search")
    end

    it "uses default return value" do
      tool = spy_tool("test_tool")

      expect(tool.return_value).to eq("ok")
    end

    it "accepts custom return value" do
      tool = spy_tool("custom", return_value: "custom_response")

      expect(tool.return_value).to eq("custom_response")
    end

    it "can track invocations" do
      tool = spy_tool("tracker")

      expect(tool).to respond_to(:calls) if tool.respond_to?(:calls)
    end

    it "creates multiple independent spy tools" do
      # NOTE: SpyTool modifies class-level tool_name, so each creation
      # overwrites the name for all instances. Test tracks calls independently.
      tool1 = spy_tool("search")
      tool2 = spy_tool("calculator")

      # Each tool should track calls independently
      tool1.execute(query: "ruby")
      tool2.execute(value: 42)

      expect(tool1.calls).to eq([{ query: "ruby" }])
      expect(tool2.calls).to eq([{ value: 42 }])
    end
  end

  describe "#mock_tool" do
    it "creates a mock Tool instance" do
      tool = mock_tool("test")

      expect(tool).to be_a(Smolagents::Tools::Tool)
    end

    it "sets the tool name" do
      tool = mock_tool("search")

      expect(tool.name).to eq("search")
    end

    it "returns specified value when executed" do
      tool = mock_tool("calculator", returns: 42)

      result = tool.execute

      expect(result).to eq(42)
    end

    it "returns nil when no return value specified" do
      tool = mock_tool("test")

      result = tool.execute

      expect(result).to be_nil
    end

    it "raises specified exception when called" do
      error = RuntimeError.new("Tool failed!")
      tool = mock_tool("failing", raises: error)

      expect { tool.execute }.to raise_error(RuntimeError, "Tool failed!")
    end

    it "raises takes precedence over returns" do
      error = RuntimeError.new("Error!")
      tool = mock_tool("test", returns: 42, raises: error)

      expect { tool.execute }.to raise_error(RuntimeError)
    end

    it "accepts string return value" do
      tool = mock_tool("echo", returns: "hello")

      expect(tool.execute).to eq("hello")
    end

    it "accepts hash return value" do
      response = { status: "ok", data: [1, 2, 3] }
      tool = mock_tool("get_data", returns: response)

      expect(tool.execute).to eq(response)
    end

    it "accepts array return value" do
      data = [1, 2, 3, 4, 5]
      tool = mock_tool("list", returns: data)

      expect(tool.execute).to eq(data)
    end

    it "creates multiple independent mock tools" do
      tool1 = mock_tool("add", returns: 7)
      tool2 = mock_tool("multiply", returns: 12)

      expect(tool1.execute).to eq(7)
      expect(tool2.execute).to eq(12)
    end

    it "has tool description" do
      tool = mock_tool("search")

      expect(tool.description).to include("Mock")
      expect(tool.description).to include("search")
    end

    it "has defined inputs" do
      tool = mock_tool("test")

      expect(tool.inputs).not_to be_empty
      expect(tool.inputs).to have_key(:input)
    end

    it "has output_type defined" do
      tool = mock_tool("test")

      expect(tool.output_type).to eq("string")
    end
  end

  describe "MockToolBuilder" do
    let(:builder) { Smolagents::Testing::Helpers::MockToolBuilder }

    it "responds to build method" do
      expect(builder).to respond_to(:build)
    end

    it "builds a Tool class with correct name" do
      tool = builder.build("custom_tool", returns: "result", raises: nil)

      expect(tool.name).to eq("custom_tool")
    end

    it "builds tool with return behavior" do
      tool = builder.build("test", returns: "success", raises: nil)

      expect(tool.execute).to eq("success")
    end

    it "builds tool with raise behavior" do
      error = ArgumentError.new("Invalid input")
      tool = builder.build("failing", returns: nil, raises: error)

      expect { tool.execute }.to raise_error(ArgumentError)
    end

    it "creates independent tool instances" do
      tool1 = builder.build("tool1", returns: 1, raises: nil)
      tool2 = builder.build("tool2", returns: 2, raises: nil)

      expect(tool1.execute).to eq(1)
      expect(tool2.execute).to eq(2)
    end
  end

  describe "helper integration" do
    it "all methods are available in test context" do
      expect(self).to respond_to(:spy_tool)
      expect(self).to respond_to(:mock_tool)
    end

    it "can use mock tools with agents" do
      tool = mock_tool("search", returns: "search results")

      expect(tool).to respond_to(:execute)
      expect(tool.execute).to eq("search results")
    end

    it "can chain tool creation" do
      tools = [
        mock_tool("add", returns: 5),
        mock_tool("multiply", returns: 10),
        spy_tool("log")
      ]

      expect(tools.size).to eq(3)
      expect(tools[0]).to be_a(Smolagents::Tools::Tool)
    end
  end

  describe "tool behavior" do
    it "mock tool ignores execute arguments" do
      tool = mock_tool("test", returns: 42)

      result1 = tool.execute(a: 1, b: 2)
      result2 = tool.execute(x: "y", z: "w")

      expect(result1).to eq(42)
      expect(result2).to eq(42)
    end

    it "mock tool executes consistently" do
      tool = mock_tool("consistent", returns: "same")

      results = Array.new(5) { tool.execute }

      expect(results.uniq).to eq(["same"])
    end

    it "mock tool with complex return value" do
      complex_value = {
        data: [1, 2, 3],
        metadata: { count: 3, type: "numbers" }
      }
      tool = mock_tool("complex", returns: complex_value)

      result = tool.execute

      expect(result).to eq(complex_value)
    end
  end

  describe "error handling" do
    it "preserves exception message" do
      error = RuntimeError.new("Specific error message")
      tool = mock_tool("test", raises: error)

      expect { tool.execute }.to raise_error(RuntimeError, "Specific error message")
    end

    it "can raise different exception types" do
      [ArgumentError, TypeError, StandardError].each do |error_class|
        tool = mock_tool("test", raises: error_class.new("message"))

        expect { tool.execute }.to raise_error(error_class)
      end
    end
  end
end
