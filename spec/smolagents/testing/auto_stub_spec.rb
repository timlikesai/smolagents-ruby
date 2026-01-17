require "spec_helper"

RSpec.describe Smolagents::Testing::AutoStub do
  describe ".mock_for_tools" do
    it "creates a MockModel with queued responses" do
      mock = described_class.mock_for_tools(:search)

      expect(mock).to be_a(Smolagents::Testing::MockModel)
      expect(mock.remaining_responses).to eq(2)
    end

    it "queues a final answer at the end" do
      mock = described_class.mock_for_tools(:search)

      # Skip the first response (tool call)
      mock.generate([])

      # Second response should be final_answer
      response = mock.generate([])
      expect(response.content).to include("final_answer")
      expect(response.content).to include("Task completed")
    end

    it "accepts custom final_answer" do
      mock = described_class.mock_for_tools(:search, final_answer: "Custom answer")

      mock.generate([]) # Skip tool call
      response = mock.generate([])

      expect(response.content).to include("Custom answer")
    end

    it "handles multiple tool names" do
      mock = described_class.mock_for_tools(:search, :calculator, :web)

      expect(mock.remaining_responses).to eq(4) # 3 tools + final_answer
    end

    it "handles array of tool names" do
      mock = described_class.mock_for_tools(%i[search calculator])

      expect(mock.remaining_responses).to eq(3) # 2 tools + final_answer
    end

    it "handles unknown tools with fallback" do
      mock = described_class.mock_for_tools(:unknown_tool)

      response = mock.generate([])
      expect(response.content).to include("unknown_tool()")
    end
  end

  describe ".generate_tool_call" do
    let(:tool_class) do
      Class.new(Smolagents::Tool) do
        self.tool_name = "test_tool"
        self.description = "A test tool"
        self.inputs = {
          query: { type: "string", description: "Search query" },
          count: { type: "integer", description: "Number of results" }
        }
        self.output_type = "string"

        def execute(_query:, _count: 10)
          "Result"
        end
      end
    end

    it "generates a tool call with arguments" do
      tool = tool_class.new
      call = described_class.generate_tool_call(tool)

      expect(call).to include("test_tool(")
      expect(call).to include("query:")
      expect(call).to include("count:")
    end

    it "handles tools with no inputs" do
      no_input_tool = Class.new(Smolagents::Tool) do
        self.tool_name = "simple"
        self.description = "Simple tool"
        self.inputs = {}
        self.output_type = "string"

        def execute
          "Done"
        end
      end.new

      call = described_class.generate_tool_call(no_input_tool)
      expect(call).to eq("simple()")
    end
  end

  describe ".generate_arguments" do
    let(:tool_class) do
      Class.new(Smolagents::Tool) do
        self.tool_name = "multi_input"
        self.description = "Tool with multiple input types"
        self.inputs = {
          text: { type: "string", description: "Text input" },
          number: { type: "integer", description: "Number input" },
          flag: { type: "boolean", description: "Boolean flag" },
          items: { type: "array", description: "Array input" },
          data: { type: "object", description: "Object input" }
        }
        self.output_type = "string"

        def execute(**) = "Done"
      end
    end

    it "generates arguments for all types" do
      tool = tool_class.new
      args = described_class.generate_arguments(tool)

      expect(args).to include('text: "test text"')
      expect(args).to include("number: 42")
      expect(args).to include("flag: true")
      expect(args).to include("items: []")
      expect(args).to include("data: {}")
    end

    it "returns empty array for tools without inputs" do
      no_input_tool = Class.new(Smolagents::Tool) do
        self.tool_name = "none"
        self.description = "No inputs"
        self.inputs = {}
        self.output_type = "string"

        def execute = "Done"
      end.new

      args = described_class.generate_arguments(no_input_tool)
      expect(args).to be_empty
    end

    it "handles tools that do not respond to inputs" do
      fake_tool = Object.new
      args = described_class.generate_arguments(fake_tool)

      expect(args).to be_empty
    end
  end

  describe ".generate_value_for_type" do
    it "generates string values" do
      expect(described_class.generate_value_for_type("string", "query")).to eq('"test query"')
      expect(described_class.generate_value_for_type("text", "name")).to eq('"test name"')
    end

    it "generates integer values" do
      expect(described_class.generate_value_for_type("integer")).to eq("42")
      expect(described_class.generate_value_for_type("int")).to eq("42")
      expect(described_class.generate_value_for_type("number")).to eq("42")
    end

    it "generates float values" do
      expect(described_class.generate_value_for_type("float")).to eq("3.14")
      expect(described_class.generate_value_for_type("decimal")).to eq("3.14")
    end

    it "generates boolean values" do
      expect(described_class.generate_value_for_type("boolean")).to eq("true")
      expect(described_class.generate_value_for_type("bool")).to eq("true")
    end

    it "generates array values" do
      expect(described_class.generate_value_for_type("array")).to eq("[]")
      expect(described_class.generate_value_for_type("list")).to eq("[]")
    end

    it "generates hash values" do
      expect(described_class.generate_value_for_type("hash")).to eq("{}")
      expect(described_class.generate_value_for_type("object")).to eq("{}")
      expect(described_class.generate_value_for_type("dict")).to eq("{}")
    end

    it "defaults to string for unknown types" do
      expect(described_class.generate_value_for_type("unknown")).to eq('"test"')
      expect(described_class.generate_value_for_type(nil)).to eq('"test"')
    end

    it "is case-insensitive" do
      expect(described_class.generate_value_for_type("STRING")).to eq('"test value"')
      expect(described_class.generate_value_for_type("Boolean")).to eq("true")
    end
  end

  describe ".mock_for_steps" do
    it "creates a mock with specified number of steps" do
      mock = described_class.mock_for_steps(steps: 3)

      expect(mock.remaining_responses).to eq(3)
    end

    it "queues intermediate step actions" do
      mock = described_class.mock_for_steps(steps: 3)

      response1 = mock.generate([])
      expect(response1.content).to include("step_1")

      response2 = mock.generate([])
      expect(response2.content).to include("step_2")
    end

    it "ends with final answer" do
      mock = described_class.mock_for_steps(steps: 2, final_answer: "Completed")

      mock.generate([]) # Skip step 1
      response = mock.generate([])

      expect(response.content).to include("final_answer")
      expect(response.content).to include("Completed")
    end

    it "handles single step" do
      mock = described_class.mock_for_steps(steps: 1, final_answer: "Only one")

      expect(mock.remaining_responses).to eq(1)

      response = mock.generate([])
      expect(response.content).to include("final_answer")
      expect(response.content).to include("Only one")
    end
  end
end
