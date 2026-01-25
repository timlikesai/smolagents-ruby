require "smolagents/models/support/tool_schema"

RSpec.describe Smolagents::Models::ModelSupport::ToolSchema do
  let(:model_class) do
    Class.new do
      include Smolagents::Models::ModelSupport::ToolSchema

      # Mock the tool property extraction methods from Concerns::ToolSchema
      def tool_properties(tool, type_mapper: nil)
        tool.instance_variable_get(:@parameters).each_with_object({}) do |(name, param), hash|
          param_type = type_mapper ? type_mapper.call(param[:type]) : param[:type]
          hash[name] = { type: param_type, description: param[:description] }
        end
      end

      def tool_required_fields(tool)
        tool.instance_variable_get(:@parameters).select { |_, p| p[:required] }.keys
      end

      def json_schema_type(type)
        case type
        when "integer" then "integer"
        when "boolean" then "boolean"
        when "array" then "array"
        else "string" # Default for "string" and unknown types
        end
      end
    end
  end
  let(:model) { model_class.new }

  describe "#extract_tool_schema" do
    let(:tool) do
      tool = double(name: "search", description: "Search the web")
      tool.instance_variable_set(:@parameters, {
                                   query: { type: "string", description: "Search query", required: true },
                                   max_results: { type: "integer", description: "Max results", required: false }
                                 })
      tool
    end

    it "returns a hash with schema components" do
      result = model.extract_tool_schema(tool)

      expect(result).to be_a(Hash)
      expect(result).to have_key(:name)
      expect(result).to have_key(:description)
      expect(result).to have_key(:properties)
      expect(result).to have_key(:required)
    end

    it "includes tool name" do
      result = model.extract_tool_schema(tool)

      expect(result[:name]).to eq("search")
    end

    it "includes tool description" do
      result = model.extract_tool_schema(tool)

      expect(result[:description]).to eq("Search the web")
    end

    it "extracts tool properties" do
      result = model.extract_tool_schema(tool)

      expect(result[:properties]).to have_key(:query)
      expect(result[:properties]).to have_key(:max_results)
    end

    it "includes property descriptions" do
      result = model.extract_tool_schema(tool)

      expect(result[:properties][:query][:description]).to eq("Search query")
      expect(result[:properties][:max_results][:description]).to eq("Max results")
    end

    it "identifies required fields" do
      result = model.extract_tool_schema(tool)

      expect(result[:required]).to include(:query)
      expect(result[:required]).not_to include(:max_results)
    end

    context "with type_mapper" do
      it "applies type transformation" do
        type_mapper = ->(type) { type == "string" ? "text" : type }

        result = model.extract_tool_schema(tool, type_mapper:)

        # The type_mapper would be used in tool_properties
        # In this mock, we'll just verify it's used
        expect(result[:properties][:query]).to have_key(:type)
      end

      it "maps custom types" do
        custom_mapper = lambda { |type|
          case type
          when "string" then "json_string"
          when "integer" then "json_integer"
          else type
          end
        }

        result = model.extract_tool_schema(tool, type_mapper: custom_mapper)

        expect(result[:properties][:query][:type]).to eq("json_string")
      end
    end

    context "with multiple parameters" do
      let(:complex_tool) do
        tool = double(name: "calculator", description: "Perform calculations")
        tool.instance_variable_set(:@parameters, {
                                     expression: { type: "string", description: "Math expression", required: true },
                                     precision: { type: "integer", description: "Decimal places", required: false },
                                     use_radians: { type: "boolean", description: "Use radians", required: false }
                                   })
        tool
      end

      it "handles multiple parameter types" do
        result = model.extract_tool_schema(complex_tool)

        expect(result[:properties].length).to eq(3)
        expect(result[:properties][:expression]).to have_key(:type)
        expect(result[:properties][:precision]).to have_key(:type)
        expect(result[:properties][:use_radians]).to have_key(:type)
      end

      it "correctly identifies all required fields" do
        result = model.extract_tool_schema(complex_tool)

        expect(result[:required]).to eq([:expression])
      end
    end

    context "with no required fields" do
      let(:optional_tool) do
        tool = double(name: "greet", description: "Greet someone")
        tool.instance_variable_set(:@parameters, {
                                     name: { type: "string", description: "Person name", required: false },
                                     greeting: { type: "string", description: "Custom greeting", required: false }
                                   })
        tool
      end

      it "returns empty required array" do
        result = model.extract_tool_schema(optional_tool)

        expect(result[:required]).to be_empty
      end
    end

    context "with no parameters" do
      let(:no_param_tool) do
        tool = double(name: "status", description: "Get status")
        tool.instance_variable_set(:@parameters, {})
        tool
      end

      it "returns empty properties" do
        result = model.extract_tool_schema(no_param_tool)

        expect(result[:properties]).to be_empty
        expect(result[:required]).to be_empty
      end
    end
  end

  describe "#build_parameters_schema" do
    let(:schema) do
      {
        name: "search",
        description: "Search",
        properties: { query: { type: "string" } },
        required: ["query"]
      }
    end

    it "wraps schema in JSON Schema object format" do
      result = model.build_parameters_schema(schema)

      expect(result).to be_a(Hash)
      expect(result).to have_key(:type)
      expect(result).to have_key(:properties)
      expect(result).to have_key(:required)
    end

    it "sets type to object" do
      result = model.build_parameters_schema(schema)

      expect(result[:type]).to eq("object")
    end

    it "includes properties from extracted schema" do
      result = model.build_parameters_schema(schema)

      expect(result[:properties]).to eq({ query: { type: "string" } })
    end

    it "includes required fields from extracted schema" do
      result = model.build_parameters_schema(schema)

      expect(result[:required]).to eq(["query"])
    end

    it "handles empty properties" do
      schema = {
        name: "status",
        description: "Get status",
        properties: {},
        required: []
      }

      result = model.build_parameters_schema(schema)

      expect(result[:properties]).to eq({})
      expect(result[:required]).to eq([])
    end

    it "preserves property structure" do
      complex_schema = {
        name: "config",
        description: "Configure settings",
        properties: {
          debug: { type: "boolean", description: "Enable debug" },
          port: { type: "integer", description: "Server port", minimum: 1, maximum: 65_535 }
        },
        required: ["port"]
      }

      result = model.build_parameters_schema(complex_schema)

      expect(result[:properties][:debug]).to include(type: "boolean", description: "Enable debug")
      expect(result[:properties][:port]).to include(minimum: 1, maximum: 65_535)
    end
  end

  describe "integration workflow" do
    it "extracts schema then builds parameters" do
      tool = double(name: "search", description: "Search")
      tool.instance_variable_set(:@parameters, {
                                   query: { type: "string", description: "Query", required: true }
                                 })

      extracted = model.extract_tool_schema(tool)
      parameters = model.build_parameters_schema(extracted)

      expect(parameters[:type]).to eq("object")
      expect(parameters[:properties]).to have_key(:query)
      expect(parameters[:required]).to include(:query)
    end

    it "supports provider-specific type mapping in workflow" do
      tool = double(name: "search", description: "Search")
      tool.instance_variable_set(:@parameters, {
                                   query: { type: "string", description: "Query", required: true }
                                 })

      mapper = ->(t) { t == "string" ? "text" : t }
      extracted = model.extract_tool_schema(tool, type_mapper: mapper)

      expect(extracted[:properties][:query][:type]).to eq("text")
    end
  end

  describe "schema structure validation" do
    it "produces valid JSON Schema for tool parameters" do
      tool = double(name: "search", description: "Search")
      tool.instance_variable_set(:@parameters, {
                                   query: { type: "string", required: true },
                                   limit: { type: "integer", required: false }
                                 })

      extracted = model.extract_tool_schema(tool)
      parameters = model.build_parameters_schema(extracted)

      # Validate JSON Schema structure
      expect(parameters).to have_key(:type)
      expect(parameters[:type]).to eq("object")
      expect(parameters).to have_key(:properties)
      expect(parameters).to have_key(:required)
      expect(parameters[:required]).to be_an(Array)
    end

    it "maintains property type information" do
      tool = double(name: "calc", description: "Calculate")
      tool.instance_variable_set(:@parameters, {
                                   numbers: { type: "array", required: true },
                                   operation: { type: "string", required: true }
                                 })

      extracted = model.extract_tool_schema(tool)
      parameters = model.build_parameters_schema(extracted)

      expect(parameters[:properties][:numbers][:type]).to eq("array")
      expect(parameters[:properties][:operation][:type]).to eq("string")
    end
  end
end
