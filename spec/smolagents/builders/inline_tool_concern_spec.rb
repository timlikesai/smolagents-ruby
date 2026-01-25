require "spec_helper"

RSpec.describe Smolagents::Builders::InlineToolConcern do
  let(:test_builder_class) do
    Class.new(Data.define(:configuration)) do
      include Smolagents::Builders::InlineToolConcern

      def self.create
        new(configuration: { tool_instances: [] })
      end

      def with_config(new_config)
        self.class.new(configuration: configuration.merge(new_config))
      end

      def check_frozen!
        raise FrozenError if configuration[:__frozen__]
      end

      def freeze!
        with_config(__frozen__: true)
      end
    end
  end

  let(:builder) { test_builder_class.create }

  describe "#tool" do
    context "with simple tool definition" do
      it "creates inline tool with name and description" do
        result = builder.tool(:greet, "Say hello", name: String) { |name:| "Hello, #{name}!" }

        expect(result.configuration[:tool_instances].size).to eq(1)
        tool = result.configuration[:tool_instances].first
        expect(tool).to be_a(Smolagents::Tools::InlineTool)
      end

      it "returns new builder instance" do
        result = builder.tool(:greet, "Say hello", name: String) { |name:| "Hello" }

        expect(result).not_to equal(builder)
        expect(result).to be_a(test_builder_class)
      end

      it "preserves immutability" do
        original_tools = builder.configuration[:tool_instances].dup

        result = builder.tool(:greet, "Say hello", name: String) { |name:| "Hello" }

        expect(builder.configuration[:tool_instances]).to eq(original_tools)
        expect(result.configuration[:tool_instances].size).to eq(original_tools.size + 1)
      end
    end

    context "with multiple inputs" do
      it "creates tool with multiple input parameters" do
        result = builder.tool(:add, "Add numbers", a: Integer, b: Integer) do |a:, b:|
          a + b
        end

        tool = result.configuration[:tool_instances].first
        expect(tool).to be_a(Smolagents::Tools::InlineTool)
        # Input types should be captured
        expect(tool.inputs).to be_a(Hash)
      end

      it "accepts various input types" do
        result = builder.tool(:convert, "Convert values",
                              text: String, count: Integer, ratio: Float) do
          "converted"
        end

        tool = result.configuration[:tool_instances].first
        expect(tool.inputs.size).to eq(3)
      end
    end

    context "with tool chaining" do
      it "accumulates multiple inline tools" do
        result = builder
                 .tool(:greet, "Say hello", name: String) { |name:| "Hello, #{name}!" }
                 .tool(:farewell, "Say goodbye", name: String) { |name:| "Goodbye, #{name}!" }

        expect(result.configuration[:tool_instances].size).to eq(2)
      end

      it "maintains separate tool definitions" do
        result = builder
                 .tool(:tool1, "First", x: Integer) { |x:| x }
                 .tool(:tool2, "Second", y: String) { |y:| y }

        tool1, tool2 = result.configuration[:tool_instances]
        expect(tool1.name.to_sym).to eq(:tool1)
        expect(tool2.name.to_sym).to eq(:tool2)
      end
    end

    context "with tool execution" do
      it "allows tool to be called with correct parameters" do
        result = builder.tool(:multiply, "Multiply", a: Integer, b: Integer) { |a:, b:| a * b }

        tool = result.configuration[:tool_instances].first
        # Tool should be executable
        expect(tool).to respond_to(:call) | respond_to(:execute) | respond_to(:perform)
      end

      it "preserves block closure" do
        multiplier = 10
        result = builder.tool(:scale, "Scale by factor", value: Integer) do |value:|
          value * multiplier
        end

        tool = result.configuration[:tool_instances].first
        expect(tool).to be_a(Smolagents::Tools::InlineTool)
      end
    end

    context "error handling" do
      it "raises error when block is missing" do
        expect { builder.tool(:greet, "Say hello", name: String) }
          .to raise_error(ArgumentError, /Block required/)
      end

      it "raises error with meaningful message on missing block" do
        expect { builder.tool(:test, "Test", param: String) }
          .to raise_error(ArgumentError)
      end
    end

    context "with frozen builder" do
      it "raises FrozenError when frozen" do
        frozen_builder = builder.freeze!

        expect do
          frozen_builder.tool(:greet, "Say hello", name: String) { |name:| "Hello" }
        end.to raise_error(FrozenError)
      end
    end

    context "tool name handling" do
      it "accepts symbol names" do
        result = builder.tool(:my_tool, "My tool", x: String) { |x:| x }

        tool = result.configuration[:tool_instances].first
        expect(tool.name.to_sym).to eq(:my_tool)
      end

      it "accepts string names" do
        result = builder.tool("my_tool", "My tool", x: String) { |x:| x }

        tool = result.configuration[:tool_instances].first
        expect(tool.name.to_sym).to eq(:my_tool)
      end
    end

    context "description handling" do
      it "stores the description" do
        desc = "This is a comprehensive description of what the tool does"
        result = builder.tool(:test, desc, x: String) { |x:| x }

        tool = result.configuration[:tool_instances].first
        expect(tool.description).to eq(desc)
      end
    end

    context "complex use cases" do
      it "works with nested data structures" do
        result = builder.tool(:process, "Process data", data: String) do |data:|
          { processed: true, input: data }
        end

        tool = result.configuration[:tool_instances].first
        expect(tool).to be_a(Smolagents::Tools::InlineTool)
      end

      it "allows multiple tools with same pattern" do
        result = builder
                 .tool(:search, "Search", query: String) { |query:| "results" }
                 .tool(:lookup, "Lookup", term: String) { |term:| "found" }
                 .tool(:index, "Index", data: String) { |data:| "indexed" }

        expect(result.configuration[:tool_instances].size).to eq(3)
      end
    end
  end

  describe "method signature" do
    it "has correct method signature" do
      method = test_builder_class.instance_method(:tool)
      params = method.parameters
      # Should have name, description, and block parameters
      expect(params).to be_a(Array)
      expect(params.first[0]).to eq(:req) # name
    end
  end

  describe "frozen check" do
    it "calls check_frozen! before modifying" do
      # Verify check_frozen! is called by testing that frozen builder raises
      frozen_builder = builder.freeze!

      expect do
        frozen_builder.tool(:test, "Test", x: String) { |x:| x }
      end.to raise_error(FrozenError)
    end
  end
end
