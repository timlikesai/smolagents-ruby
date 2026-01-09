# frozen_string_literal: true

RSpec.describe Smolagents::Tool do
  # Create a simple test tool
  let(:test_tool_class) do
    Class.new(described_class) do
      self.tool_name = "test_tool"
      self.description = "A test tool"
      self.inputs = {
        "param1" => { "type" => "string", "description" => "First parameter" },
        "param2" => { "type" => "integer", "description" => "Second parameter", "nullable" => true }
      }
      self.output_type = "string"

      def forward(param1:, param2: nil)
        "Result: #{param1}, #{param2}"
      end
    end
  end

  let(:test_tool) { test_tool_class.new }

  describe ".inherited" do
    it "initializes class attributes for subclass" do
      subclass = Class.new(described_class)
      expect(subclass.tool_name).to be_nil
      expect(subclass.inputs).to eq({})
      expect(subclass.output_type).to eq("any")
    end
  end

  describe "#initialize" do
    it "validates arguments on initialization" do
      expect { test_tool }.not_to raise_error
    end

    it "raises error if tool_name is missing" do
      bad_class = Class.new(described_class) do
        self.description = "Test"
        self.inputs = {}
        self.output_type = "string"
      end

      expect { bad_class.new }.to raise_error(ArgumentError, /must have a name/)
    end

    it "raises error if invalid output_type" do
      bad_class = Class.new(described_class) do
        self.tool_name = "bad"
        self.description = "Test"
        self.inputs = {}
        self.output_type = "invalid_type"
      end

      expect { bad_class.new }.to raise_error(ArgumentError, /Invalid output_type/)
    end
  end

  describe "#name, #description, #inputs, #output_type" do
    it "delegates to class attributes" do
      expect(test_tool.name).to eq("test_tool")
      expect(test_tool.description).to eq("A test tool")
      expect(test_tool.inputs).to be_a(Hash)
      expect(test_tool.output_type).to eq("string")
    end
  end

  describe "#call" do
    it "calls forward with keyword arguments" do
      result = test_tool.call(param1: "test")
      expect(result).to eq("Result: test, ")
    end

    it "handles hash as single argument" do
      result = test_tool.call({ param1: "test", param2: 42 })
      expect(result).to eq("Result: test, 42")
    end

    it "calls setup on first use" do
      expect(test_tool).to receive(:setup).once.and_call_original
      test_tool.call(param1: "test")
      test_tool.call(param1: "test2") # Should not call setup again
    end
  end

  describe "#forward" do
    it "must be implemented by subclasses" do
      bare_tool_class = Class.new(described_class) do
        self.tool_name = "bare"
        self.description = "Bare tool"
        self.inputs = {}
        self.output_type = "any"
      end

      expect {
        bare_tool_class.new.forward
      }.to raise_error(NotImplementedError)
    end
  end

  describe "#to_code_prompt" do
    it "generates Ruby-style documentation" do
      prompt = test_tool.to_code_prompt
      expect(prompt).to include("def test_tool")
      expect(prompt).to include("param1: string")
      expect(prompt).to include("First parameter")
    end
  end

  describe "#to_tool_calling_prompt" do
    it "generates tool calling documentation" do
      prompt = test_tool.to_tool_calling_prompt
      expect(prompt).to include("test_tool:")
      expect(prompt).to include("A test tool")
      expect(prompt).to include("Takes inputs:")
    end
  end

  describe "#to_h" do
    it "converts to hash" do
      hash = test_tool.to_h
      expect(hash[:name]).to eq("test_tool")
      expect(hash[:description]).to eq("A test tool")
      expect(hash[:inputs]).to be_a(Hash)
      expect(hash[:output_type]).to eq("string")
    end
  end

  describe "#validate_tool_arguments" do
    it "validates required arguments are present" do
      expect {
        test_tool.validate_tool_arguments({ param1: "test" })
      }.not_to raise_error
    end

    it "raises error for missing required argument" do
      expect {
        test_tool.validate_tool_arguments({})
      }.to raise_error(Smolagents::AgentToolCallError, /missing required input/)
    end

    it "allows missing optional arguments" do
      expect {
        test_tool.validate_tool_arguments({ param1: "test" })
      }.not_to raise_error
    end

    it "raises error for unexpected arguments" do
      expect {
        test_tool.validate_tool_arguments({ param1: "test", unexpected: "value" })
      }.to raise_error(Smolagents::AgentToolCallError, /unexpected input/)
    end
  end
end
