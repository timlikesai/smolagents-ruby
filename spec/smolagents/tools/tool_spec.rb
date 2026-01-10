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

      expect do
        bare_tool_class.new.forward
      end.to raise_error(NotImplementedError)
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
      expect do
        test_tool.validate_tool_arguments({ param1: "test" })
      end.not_to raise_error
    end

    it "raises error for missing required argument" do
      expect do
        test_tool.validate_tool_arguments({})
      end.to raise_error(Smolagents::AgentToolCallError, /missing required input/)
    end

    it "allows missing optional arguments" do
      expect do
        test_tool.validate_tool_arguments({ param1: "test" })
      end.not_to raise_error
    end

    it "raises error for unexpected arguments" do
      expect do
        test_tool.validate_tool_arguments({ param1: "test", unexpected: "value" })
      end.to raise_error(Smolagents::AgentToolCallError, /unexpected input/)
    end
  end

  describe "ToolResult wrapping" do
    it "wraps results in ToolResult by default" do
      result = test_tool.call(param1: "test")
      expect(result).to be_a(Smolagents::ToolResult)
    end

    it "includes tool name in metadata" do
      result = test_tool.call(param1: "test")
      expect(result.tool_name).to eq("test_tool")
    end

    it "includes input arguments in metadata" do
      result = test_tool.call(param1: "test", param2: 42)
      expect(result.metadata[:inputs]).to eq({ param1: "test", param2: 42 })
    end

    it "includes output type in metadata" do
      result = test_tool.call(param1: "test")
      expect(result.metadata[:output_type]).to eq("string")
    end

    it "can opt out of wrapping with wrap_result: false" do
      result = test_tool.call(param1: "test", wrap_result: false)
      expect(result).to be_a(String)
      expect(result).to eq("Result: test, ")
    end

    it "does not double-wrap ToolResult returns" do
      tool_returning_result = Class.new(described_class) do
        self.tool_name = "result_tool"
        self.description = "Tool that returns ToolResult"
        self.inputs = { "value" => { "type" => "string", "description" => "Value" } }
        self.output_type = "string"

        def forward(value:)
          Smolagents::ToolResult.new("already wrapped: #{value}", tool_name: "inner_tool")
        end
      end.new

      result = tool_returning_result.call(value: "test")
      expect(result.tool_name).to eq("inner_tool")
      expect(result.data).to eq("already wrapped: test")
    end

    context "with error responses" do
      let(:error_tool_class) do
        Class.new(described_class) do
          self.tool_name = "error_tool"
          self.description = "Tool that returns errors"
          self.inputs = { "type" => { "type" => "string", "description" => "Error type" } }
          self.output_type = "string"

          def forward(type:)
            case type
            when "error"
              "Error: Something went wrong"
            when "unexpected"
              "An unexpected error occurred: test failure"
            else
              "Success"
            end
          end
        end
      end

      let(:error_tool) { error_tool_class.new }

      it "marks 'Error' responses as error results" do
        result = error_tool.call(type: "error")
        expect(result.error?).to be true
        expect(result.metadata[:error]).to include("Something went wrong")
      end

      it "marks 'An unexpected error' responses as error results" do
        result = error_tool.call(type: "unexpected")
        expect(result.error?).to be true
        expect(result.metadata[:error]).to include("unexpected error")
      end

      it "marks successful responses as success" do
        result = error_tool.call(type: "success")
        expect(result.success?).to be true
      end
    end

    context "with array results" do
      let(:array_tool_class) do
        Class.new(described_class) do
          self.tool_name = "array_tool"
          self.description = "Tool that returns arrays"
          self.inputs = {}
          self.output_type = "array"

          def forward
            [{ title: "Result 1" }, { title: "Result 2" }]
          end
        end
      end

      let(:array_tool) { array_tool_class.new }

      it "wraps array results as chainable ToolResult" do
        result = array_tool.call
        expect(result).to be_a(Smolagents::ToolResult)
        expect(result.count).to eq(2)
        expect(result.pluck(:title).to_a).to eq(["Result 1", "Result 2"])
      end

      it "supports Enumerable operations" do
        result = array_tool.call
        filtered = result.select { |r| r[:title].include?("1") }
        expect(filtered.count).to eq(1)
      end
    end
  end
end
