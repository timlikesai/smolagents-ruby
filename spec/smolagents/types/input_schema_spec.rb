require "smolagents"

RSpec.describe Smolagents::InputSchema do
  describe ".from_mcp_property" do
    it "creates InputSchema from MCP property spec" do
      spec = { "type" => "string", "description" => "A test parameter" }
      schema = described_class.from_mcp_property("test_param", spec, ["test_param"])

      expect(schema.name).to eq(:test_param)
      expect(schema.type).to eq("string")
      expect(schema.description).to eq("A test parameter")
      expect(schema.required).to be true
      expect(schema.nullable).to be false
    end

    it "handles optional parameters" do
      spec = { "type" => "integer", "description" => "Optional count" }
      schema = described_class.from_mcp_property("count", spec, [])

      expect(schema.name).to eq(:count)
      expect(schema.required).to be false
      expect(schema.nullable).to be true
    end

    it "provides default description when missing" do
      spec = { "type" => "string" }
      schema = described_class.from_mcp_property("param", spec, [])

      expect(schema.description).to eq("No description provided")
    end

    it "handles symbol keys in spec" do
      spec = { type: "boolean", description: "A flag" }
      schema = described_class.from_mcp_property("flag", spec, ["flag"])

      expect(schema.type).to eq("boolean")
      expect(schema.description).to eq("A flag")
    end

    it "handles empty spec hash" do
      schema = described_class.from_mcp_property("param", {}, [])

      expect(schema.type).to eq("any")
      expect(schema.description).to eq("No description provided")
    end

    it "handles non-hash spec" do
      schema = described_class.from_mcp_property("param", nil, [])

      expect(schema.type).to eq("any")
      expect(schema.description).to eq("No description provided")
    end
  end

  describe ".from_mcp_input_schema" do
    it "converts full MCP input schema to InputSchema array" do
      input_schema = {
        "properties" => {
          "name" => { "type" => "string", "description" => "User name" },
          "age" => { "type" => "integer", "description" => "User age" }
        },
        "required" => ["name"]
      }

      schemas = described_class.from_mcp_input_schema(input_schema)

      expect(schemas.length).to eq(2)
      expect(schemas.map(&:name)).to contain_exactly(:name, :age)

      name_schema = schemas.find { |s| s.name == :name }
      expect(name_schema.required).to be true
      expect(name_schema.nullable).to be false

      age_schema = schemas.find { |s| s.name == :age }
      expect(age_schema.required).to be false
      expect(age_schema.nullable).to be true
    end

    it "handles symbol keys in input schema" do
      input_schema = {
        properties: {
          "param" => { "type" => "string" }
        },
        required: ["param"]
      }

      schemas = described_class.from_mcp_input_schema(input_schema)
      expect(schemas.length).to eq(1)
      expect(schemas.first.required).to be true
    end

    it "returns empty array for non-hash input" do
      expect(described_class.from_mcp_input_schema(nil)).to eq([])
      expect(described_class.from_mcp_input_schema("invalid")).to eq([])
    end

    it "handles missing properties" do
      input_schema = { "required" => ["something"] }
      expect(described_class.from_mcp_input_schema(input_schema)).to eq([])
    end

    it "handles missing required list" do
      input_schema = {
        "properties" => {
          "param" => { "type" => "string" }
        }
      }

      schemas = described_class.from_mcp_input_schema(input_schema)
      expect(schemas.first.required).to be false
    end
  end

  describe "type normalization" do
    it "normalizes known types" do
      %w[string boolean integer number array object null].each do |type|
        spec = { "type" => type }
        schema = described_class.from_mcp_property("param", spec, [])
        expect(schema.type).to eq(type)
      end
    end

    it "normalizes unknown types to 'any'" do
      spec = { "type" => "unknown_type" }
      schema = described_class.from_mcp_property("param", spec, [])
      expect(schema.type).to eq("any")
    end

    it "handles array types with single non-null type" do
      spec = { "type" => %w[string null] }
      schema = described_class.from_mcp_property("param", spec, [])
      expect(schema.type).to eq("string")
    end

    it "handles array types with multiple non-null types as 'any'" do
      spec = { "type" => %w[string integer] }
      schema = described_class.from_mcp_property("param", spec, [])
      expect(schema.type).to eq("any")
    end
  end

  describe "#to_tool_input" do
    it "returns hash format for Tool.inputs" do
      schema = described_class.new(
        name: :test,
        type: "string",
        description: "Test description",
        required: true,
        nullable: false
      )

      result = schema.to_tool_input
      expect(result).to eq({
                             type: "string",
                             description: "Test description",
                             nullable: false
                           })
    end
  end

  describe "#to_h" do
    it "returns complete hash representation" do
      schema = described_class.new(
        name: :test,
        type: "string",
        description: "Test description",
        required: true,
        nullable: false
      )

      result = schema.to_h
      expect(result).to eq({
                             name: :test,
                             type: "string",
                             description: "Test description",
                             required: true,
                             nullable: false
                           })
    end
  end

  describe "immutability" do
    it "is immutable via Data.define" do
      schema = described_class.new(
        name: :test,
        type: "string",
        description: "Test",
        required: true,
        nullable: false
      )

      expect { schema.name = :other }.to raise_error(NoMethodError)
    end
  end
end
