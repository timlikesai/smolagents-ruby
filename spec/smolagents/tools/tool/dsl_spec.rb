RSpec.describe Smolagents::Tools::Tool::Dsl do
  describe "Tool DSL module" do
    let(:test_tool_class) do
      Class.new(Smolagents::Tools::Tool) do
        self.tool_name = "test_tool"
        self.description = "A test tool for DSL"
        self.inputs = { query: { type: "string", description: "Search query" } }
        self.output_type = "string"
      end
    end

    let(:tool) { test_tool_class.new }

    describe "AUTHORIZED_TYPES" do
      it "includes standard types" do
        types = described_class::AUTHORIZED_TYPES

        expect(types).to include("string", "integer", "number", "boolean")
      end

      it "includes complex types" do
        types = described_class::AUTHORIZED_TYPES

        expect(types).to include("array", "object")
      end

      it "includes media types" do
        types = described_class::AUTHORIZED_TYPES

        expect(types).to include("image", "audio")
      end

      it "includes special types" do
        types = described_class::AUTHORIZED_TYPES

        expect(types).to include("any", "null")
      end

      it "is frozen for immutability" do
        expect(described_class::AUTHORIZED_TYPES).to be_frozen
      end
    end

    describe "#tool_name=" do
      it "sets tool name" do
        test_tool_class.tool_name = "new_name"

        expect(test_tool_class.tool_name).to eq("new_name")
      end

      it "converts to string" do
        test_tool_class.tool_name = :symbol_name

        expect(test_tool_class.tool_name).to be_a(String)
        expect(test_tool_class.tool_name).to eq("symbol_name")
      end

      it "freezes the value" do
        test_tool_class.tool_name = "frozen_name"

        expect(test_tool_class.tool_name).to be_frozen
      end

      it "handles nil" do
        test_tool_class.tool_name = nil

        expect(test_tool_class.tool_name).to be_nil
      end
    end

    describe "#description=" do
      it "sets description" do
        test_tool_class.description = "New description"

        expect(test_tool_class.description).to eq("New description")
      end

      it "converts to string" do
        test_tool_class.description = :symbol_description

        expect(test_tool_class.description).to be_a(String)
      end

      it "freezes the value" do
        test_tool_class.description = "Frozen description"

        expect(test_tool_class.description).to be_frozen
      end
    end

    describe "#output_type=" do
      it "sets output type" do
        test_tool_class.output_type = "number"

        expect(test_tool_class.output_type).to eq("number")
      end

      it "converts to string" do
        test_tool_class.output_type = :symbol_type

        expect(test_tool_class.output_type).to be_a(String)
      end

      it "freezes the value" do
        test_tool_class.output_type = "boolean"

        expect(test_tool_class.output_type).to be_frozen
      end

      it "defaults to 'any'" do
        new_class = Class.new(Smolagents::Tools::Tool)

        expect(new_class.output_type).to eq("any")
      end
    end

    describe "#output_schema=" do
      it "sets output schema" do
        schema = { type: "object", properties: { id: { type: "integer" } } }
        test_tool_class.output_schema = schema

        expect(test_tool_class.output_schema).to include(:type, :properties)
      end

      it "freezes the schema" do
        schema = { type: "object" }
        test_tool_class.output_schema = schema

        expect(test_tool_class.output_schema).to be_frozen
      end

      it "deep freezes nested structures" do
        schema = { properties: { nested: { type: "string" } } }
        test_tool_class.output_schema = schema

        expect(test_tool_class.output_schema[:properties]).to be_frozen
      end

      it "handles nil" do
        test_tool_class.output_schema = nil

        expect(test_tool_class.output_schema).to be_nil
      end
    end

    describe "#inputs=" do
      it "sets inputs hash" do
        inputs = {
          param1: { type: "string", description: "First" },
          param2: { type: "integer", description: "Second" }
        }
        test_tool_class.inputs = inputs

        expect(test_tool_class.inputs).to have_key(:param1)
        expect(test_tool_class.inputs).to have_key(:param2)
      end

      it "symbolizes keys" do
        inputs = {
          "param1" => { type: "string", description: "First" }
        }
        test_tool_class.inputs = inputs

        expect(test_tool_class.inputs).to have_key(:param1)
      end

      it "validates inputs schema" do
        invalid_inputs = "not a hash"

        expect do
          test_tool_class.inputs = invalid_inputs
        end.to raise_error(Smolagents::ToolConfigurationError)
      end

      it "raises error for invalid type in input" do
        invalid_inputs = {
          param: { type: "invalid_type", description: "Test" }
        }

        expect do
          test_tool_class.inputs = invalid_inputs
        end.to raise_error(Smolagents::ToolConfigurationError)
      end

      it "accepts valid input types" do
        valid_inputs = {
          param1: { type: "string", description: "String param" },
          param2: { type: "integer", description: "Integer param" },
          param3: { type: "array", description: "Array param" }
        }

        expect { test_tool_class.inputs = valid_inputs }.not_to raise_error
      end

      it "stores the inputs" do
        inputs = { param: { type: "string", description: "Test" } }
        test_tool_class.inputs = inputs

        expect(test_tool_class.inputs).to eq(param: { type: "string", description: "Test" })
      end
    end

    describe ".inherited" do
      it "initializes subclass attributes" do
        subclass = Class.new(test_tool_class)

        expect(subclass.tool_name).to be_nil
        expect(subclass.description).to be_nil
        expect(subclass.inputs).to eq({}.freeze)
        expect(subclass.output_type).to eq("any")
        expect(subclass.output_schema).to be_nil
      end

      it "creates independent attributes for subclass" do
        subclass1 = Class.new(test_tool_class)
        subclass2 = Class.new(test_tool_class)

        subclass1.tool_name = "tool1"
        subclass2.tool_name = "tool2"

        expect(subclass1.tool_name).to eq("tool1")
        expect(subclass2.tool_name).to eq("tool2")
      end

      it "does not affect parent class" do
        parent_name = test_tool_class.tool_name
        subclass = Class.new(test_tool_class)
        subclass.tool_name = "subclass_name"

        expect(test_tool_class.tool_name).to eq(parent_name)
        expect(subclass.tool_name).to eq("subclass_name")
      end
    end

    describe "#tool_name, #description, #inputs, #output_type accessors" do
      it "provides reader methods" do
        expect(tool).to respond_to(:name)
        expect(tool).to respond_to(:description)
        expect(tool).to respond_to(:inputs)
        expect(tool).to respond_to(:output_type)
      end

      it "delegates to class attributes" do
        expect(tool.name).to eq(test_tool_class.tool_name)
        expect(tool.description).to eq(test_tool_class.description)
        expect(tool.inputs).to eq(test_tool_class.inputs)
        expect(tool.output_type).to eq(test_tool_class.output_type)
      end
    end

    describe "input validation" do
      it "requires type key in each input" do
        invalid_inputs = {
          param: { description: "No type specified" }
        }

        expect do
          test_tool_class.inputs = invalid_inputs
        end.to raise_error(Smolagents::ToolConfigurationError)
      end

      it "requires description key in each input" do
        invalid_inputs = {
          param: { type: "string" }
        }

        expect do
          test_tool_class.inputs = invalid_inputs
        end.to raise_error(Smolagents::ToolConfigurationError)
      end

      it "validates against AUTHORIZED_TYPES" do
        invalid_inputs = {
          param: { type: "custom_type", description: "Invalid type" }
        }

        expect do
          test_tool_class.inputs = invalid_inputs
        end.to raise_error(Smolagents::ToolConfigurationError)
      end

      it "allows nested objects" do
        valid_inputs = {
          data: {
            type: "object",
            description: "Complex object",
            properties: { nested: { type: "string" } }
          }
        }

        expect { test_tool_class.inputs = valid_inputs }.not_to raise_error
      end

      it "allows arrays" do
        valid_inputs = {
          items: {
            type: "array",
            description: "List of items"
          }
        }

        expect { test_tool_class.inputs = valid_inputs }.not_to raise_error
      end

      it "allows nullable inputs" do
        valid_inputs = {
          optional_param: {
            type: "string",
            description: "Optional parameter",
            nullable: true
          }
        }

        expect { test_tool_class.inputs = valid_inputs }.not_to raise_error
      end
    end

    describe "output_type setting" do
      it "does not validate against AUTHORIZED_TYPES" do
        # output_type accepts any value - validation happens at usage time if needed
        expect do
          test_tool_class.output_type = "invalid_type"
        end.not_to raise_error
        expect(test_tool_class.output_type).to eq("invalid_type")
      end

      it "accepts all authorized types" do
        described_class::AUTHORIZED_TYPES.each do |type|
          test_class = Class.new(Smolagents::Tools::Tool)
          expect { test_class.output_type = type }.not_to raise_error
        end
      end
    end
  end
end
