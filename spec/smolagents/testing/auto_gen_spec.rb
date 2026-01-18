require "spec_helper"

RSpec.describe Smolagents::Testing::AutoGen do
  # Create a simple test tool class
  let(:simple_tool_class) do
    Class.new(Smolagents::Tool) do
      self.tool_name = "simple_tool"
      self.description = "A simple tool for testing. Does something useful."
      self.inputs = {
        query: { type: "string", description: "The query to process" }
      }
      self.output_type = "string"

      def execute(query:)
        "Processed: #{query}"
      end
    end
  end

  let(:multi_input_tool_class) do
    Class.new(Smolagents::Tool) do
      self.tool_name = "multi_input_tool"
      self.description = "A tool with multiple inputs. Processes data."
      self.inputs = {
        query: { type: "string", description: "The search query" },
        limit: { type: "integer", description: "Maximum results to return" },
        optional_param: { type: "string", description: "Optional parameter", required: false }
      }
      self.output_type = "array"

      def execute(query:, limit:, optional_param: nil)
        [query, limit, optional_param].compact
      end
    end
  end

  let(:simple_tool) { simple_tool_class.new }
  let(:multi_input_tool) { multi_input_tool_class.new }

  describe ".tests_for_tool" do
    subject(:tests) { described_class.tests_for_tool(simple_tool) }

    it "returns an array of test cases" do
      expect(tests).to be_an(Array)
      expect(tests).to all(be_a(Smolagents::Testing::TestCase))
    end

    it "includes a basic invocation test" do
      basic_test = tests.find { |t| t.name.include?("basic_invocation") }
      expect(basic_test).not_to be_nil
      expect(basic_test.name).to eq("simple_tool_basic_invocation")
      expect(basic_test.capability).to eq(:tool_use)
    end

    it "includes input parameter tests for required inputs" do
      query_test = tests.find { |t| t.name.include?("with_query") }
      expect(query_test).not_to be_nil
      expect(query_test.name).to eq("simple_tool_with_query")
    end

    it "sets correct tools array" do
      tests.each do |test|
        expect(test.tools).to eq([:simple_tool])
      end
    end

    it "sets reasonable defaults for max_steps and timeout" do
      tests.each do |test|
        expect(test.max_steps).to eq(5)
        expect(test.timeout).to eq(60)
      end
    end

    context "with multi-input tool" do
      subject(:tests) { described_class.tests_for_tool(multi_input_tool) }

      it "creates tests for each required input" do
        names = tests.map(&:name)
        expect(names).to include("multi_input_tool_basic_invocation")
        expect(names).to include("multi_input_tool_with_query")
        expect(names).to include("multi_input_tool_with_limit")
      end

      it "excludes optional parameters" do
        names = tests.map(&:name)
        expect(names).not_to include("multi_input_tool_with_optional_param")
      end
    end
  end

  describe ".tests_for_tools" do
    subject(:tests) { described_class.tests_for_tools([simple_tool, multi_input_tool]) }

    it "returns tests for all tools" do
      expect(tests.size).to be > 2
    end

    it "includes tests from both tools" do
      names = tests.map(&:name)
      expect(names.any? { |n| n.start_with?("simple_tool") }).to be true
      expect(names.any? { |n| n.start_with?("multi_input_tool") }).to be true
    end

    it "handles empty array" do
      expect(described_class.tests_for_tools([])).to eq([])
    end
  end

  describe ".generate_task_prompt" do
    context "without input_name" do
      it "generates a prompt based on tool description" do
        prompt = described_class.generate_task_prompt(simple_tool)
        expect(prompt).to include("simple_tool")
        expect(prompt).to include("simple tool for testing")
      end

      it "downcases the description" do
        prompt = described_class.generate_task_prompt(simple_tool)
        expect(prompt).not_to include("A simple")
        expect(prompt).to include("a simple")
      end
    end

    context "with input_name" do
      it "generates a prompt for the specific input" do
        prompt = described_class.generate_task_prompt(simple_tool, input_name: :query)
        expect(prompt).to include("simple_tool")
        expect(prompt).to include("query")
        expect(prompt).to include("The query to process")
      end

      it "handles string input names" do
        prompt = described_class.generate_task_prompt(simple_tool, input_name: "query")
        expect(prompt).to include("query")
      end

      it "handles missing input gracefully" do
        prompt = described_class.generate_task_prompt(simple_tool, input_name: :nonexistent)
        expect(prompt).to include("nonexistent")
        expect(prompt).to include("a value")
      end
    end
  end

  describe ".tool_call_validator" do
    subject(:validator) { described_class.tool_call_validator("simple_tool") }

    it "returns a callable validator" do
      expect(validator).to respond_to(:call)
    end

    it "validates when tool call syntax is present" do
      expect(validator.call("simple_tool(query: 'test')")).to be_truthy
    end

    it "validates when tool name is mentioned" do
      expect(validator.call("Using the simple_tool to search")).to be_truthy
    end

    it "validates case-insensitively" do
      expect(validator.call("SIMPLE_TOOL works")).to be_truthy
    end

    it "fails when tool is not mentioned" do
      expect(validator.call("other_tool(query: 'test')")).to be_falsy
    end

    it "handles symbol tool names" do
      validator = described_class.tool_call_validator(:simple_tool)
      expect(validator.call("simple_tool(query: 'test')")).to be_truthy
    end
  end

  describe "generated test cases" do
    it "have valid validators that can be called" do
      tests = described_class.tests_for_tool(simple_tool)

      tests.each do |test|
        expect(test.validator).to respond_to(:call)
        # Validator should accept tool call output
        expect(test.validator.call("simple_tool(query: 'test')")).to be_truthy
      end
    end

    it "can be used with TestRunner" do
      tests = described_class.tests_for_tool(simple_tool)

      tests.each do |test|
        expect(test).to respond_to(:name)
        expect(test).to respond_to(:task)
        expect(test).to respond_to(:tools)
        expect(test).to respond_to(:validator)
        expect(test).to respond_to(:max_steps)
        expect(test).to respond_to(:timeout)
      end
    end
  end

  describe "edge cases" do
    let(:tool_without_inputs) do
      Class.new(Smolagents::Tool) do
        self.tool_name = "no_input_tool"
        self.description = "A tool without inputs. Just runs."
        self.inputs = {}
        self.output_type = "string"

        def execute
          "done"
        end
      end.new
    end

    it "handles tools with no inputs" do
      tests = described_class.tests_for_tool(tool_without_inputs)
      expect(tests.size).to eq(1)
      expect(tests.first.name).to eq("no_input_tool_basic_invocation")
    end

    it "handles nil inputs gracefully" do
      # Create a tool-like object without inputs method
      fake_tool = Object.new
      def fake_tool.name = "fake"
      def fake_tool.description = "A fake tool."

      # Should not raise
      tests = described_class.tests_for_tool(fake_tool)
      expect(tests.size).to eq(1)
    end
  end
end
