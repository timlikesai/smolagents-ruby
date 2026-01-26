RSpec.describe Smolagents::Concerns::ToolSchema do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ToolSchema
    end
  end

  let(:instance) { test_class.new }

  # Tool with symbol keys (common in Ruby code)
  let(:symbol_keyed_tool) do
    Smolagents::Tools::InlineTool.create(
      :greet,
      "Greet a person",
      name: String,
      formal: { type: "boolean", description: "Use formal greeting", nullable: true }
    ) { |name:, formal: false| "Hello, #{name}!" }
  end

  describe "#tool_properties" do
    it "handles symbol-keyed specs" do
      result = instance.tool_properties(symbol_keyed_tool)

      expect(result[:name][:type]).to eq("string")
      expect(result[:name][:description]).to eq("")
      expect(result[:formal][:type]).to eq("boolean")
      expect(result[:formal][:description]).to eq("Use formal greeting")
    end

    it "applies type mapper when provided" do
      mapper = ->(type) { type == "string" ? "text" : type }
      result = instance.tool_properties(symbol_keyed_tool, type_mapper: mapper)

      expect(result[:name][:type]).to eq("text")
      expect(result[:formal][:type]).to eq("boolean")
    end

    it "includes enum when present" do
      tool = Smolagents::Tools::InlineTool.create(
        :choose,
        "Choose an option",
        option: { type: "string", description: "Choice", enum: %w[a b c] }
      ) { |option:| option }

      result = instance.tool_properties(tool)

      expect(result[:option][:enum]).to eq(%w[a b c])
    end
  end

  describe "#tool_required_fields" do
    it "excludes nullable fields from required list" do
      result = instance.tool_required_fields(symbol_keyed_tool)

      expect(result).to eq([:name])
      expect(result).not_to include(:formal)
    end

    it "includes all fields when none are nullable" do
      tool = Smolagents::Tools::InlineTool.create(
        :add,
        "Add two numbers",
        a: Integer,
        b: Integer
      ) { |a:, b:| a + b }

      result = instance.tool_required_fields(tool)

      expect(result).to contain_exactly(:a, :b)
    end
  end

  describe "#json_schema_type" do
    it "maps known types" do
      expect(instance.json_schema_type("string")).to eq("string")
      expect(instance.json_schema_type("integer")).to eq("integer")
      expect(instance.json_schema_type("boolean")).to eq("boolean")
      expect(instance.json_schema_type("array")).to eq("array")
      expect(instance.json_schema_type("object")).to eq("object")
    end

    it "maps image and audio to string" do
      expect(instance.json_schema_type("image")).to eq("string")
      expect(instance.json_schema_type("audio")).to eq("string")
    end

    it "defaults unknown types to string" do
      expect(instance.json_schema_type("unknown")).to eq("string")
      expect(instance.json_schema_type("any")).to eq("string")
    end
  end
end
