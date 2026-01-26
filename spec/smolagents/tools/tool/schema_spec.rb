RSpec.describe Smolagents::Tools::Tool do
  describe "Tool schema module" do
    let(:test_tool_class) do
      Class.new(described_class) do
        self.tool_name = "schema_test"
        self.description = "Tool for schema testing"
        self.inputs = {
          query: { type: "string", description: "Search query" },
          limit: { type: "integer", description: "Result limit", nullable: true }
        }
        self.output_type = "array"
        self.output_schema = {
          type: "array",
          items: {
            type: "object",
            properties: {
              title: { type: "string" },
              url: { type: "string" }
            }
          }
        }

        def execute(query:, limit: 10)
          []
        end
      end
    end

    let(:tool) { test_tool_class.new }

    describe "#to_h" do
      it "returns hash with all metadata" do
        hash = tool.to_h

        expect(hash).to have_key(:name)
        expect(hash).to have_key(:description)
        expect(hash).to have_key(:inputs)
        expect(hash).to have_key(:output_type)
      end

      it "includes tool name" do
        hash = tool.to_h

        expect(hash[:name]).to eq("schema_test")
      end

      it "includes description" do
        hash = tool.to_h

        expect(hash[:description]).to eq("Tool for schema testing")
      end

      it "includes inputs schema" do
        hash = tool.to_h

        expect(hash[:inputs]).to have_key(:query)
        expect(hash[:inputs][:query][:type]).to eq("string")
      end

      it "includes output_type" do
        hash = tool.to_h

        expect(hash[:output_type]).to eq("array")
      end
    end

    describe "input schema structure" do
      it "includes type and description for each input" do
        hash = tool.to_h

        hash[:inputs].each_value do |schema|
          expect(schema).to have_key(:type)
          expect(schema).to have_key(:description)
        end
      end

      it "marks optional inputs as nullable" do
        hash = tool.to_h

        expect(hash[:inputs][:limit][:nullable]).to be(true)
      end

      it "marks required inputs without nullable" do
        hash = tool.to_h

        expect(hash[:inputs][:query][:nullable]).to be_falsy
      end

      it "supports complex input types" do
        complex_class = Class.new(described_class) do
          self.tool_name = "complex"
          self.description = "Complex schema"
          self.inputs = {
            data: {
              type: "object",
              description: "Complex object",
              properties: {
                nested: { type: "string" },
                count: { type: "integer" }
              }
            }
          }
          self.output_type = "object"

          def execute(data:) = data
        end

        tool = complex_class.new
        hash = tool.to_h

        expect(hash[:inputs][:data][:type]).to eq("object")
        expect(hash[:inputs][:data]).to have_key(:properties)
      end

      it "supports array input types" do
        array_class = Class.new(described_class) do
          self.tool_name = "array_tool"
          self.description = "Array input"
          self.inputs = {
            items: {
              type: "array",
              description: "List of items"
            }
          }
          self.output_type = "array"

          def execute(items:) = items
        end

        tool = array_class.new
        hash = tool.to_h

        expect(hash[:inputs][:items][:type]).to eq("array")
      end
    end

    describe "output schema" do
      it "includes output_schema when defined" do
        hash = tool.to_h

        expect(hash).to have_key(:output_schema)
      end

      it "structures output schema correctly" do
        hash = tool.to_h

        expect(hash[:output_schema][:type]).to eq("array")
        expect(hash[:output_schema]).to have_key(:items)
      end

      it "handles complex output schemas" do
        hash = tool.to_h

        items = hash[:output_schema][:items]
        expect(items[:type]).to eq("object")
        expect(items).to have_key(:properties)
        expect(items[:properties]).to have_key(:title)
        expect(items[:properties]).to have_key(:url)
      end

      it "returns nil for undefined output_schema" do
        simple_class = Class.new(described_class) do
          self.tool_name = "simple"
          self.description = "Simple"
          self.inputs = {}
          self.output_type = "string"

          def execute = "output"
        end

        tool = simple_class.new
        hash = tool.to_h

        expect(hash[:output_schema]).to be_nil
      end
    end

    describe "#format_for(:code)" do
      it "generates code-style format" do
        format = tool.format_for(:code)

        expect(format).to be_a(String)
        expect(format).to include(tool.name)
      end

      it "includes inputs in code format" do
        format = tool.format_for(:code)

        expect(format).to include("query")
        expect(format).to include("Search query")
      end

      it "includes description in code format" do
        format = tool.format_for(:code)

        expect(format).to include(tool.description)
      end

      it "is formatted for LLM consumption" do
        format = tool.format_for(:code)

        # Should be readable and structured
        expect(format.length).to be > 0
        expect(format).not_to include("<")
      end
    end

    describe "#format_for(:default)" do
      it "generates default format" do
        format = tool.format_for(:default)

        expect(format).to be_a(String)
        expect(format).to include(tool.name)
      end

      it "includes tool name" do
        format = tool.format_for(:default)

        expect(format).to include("schema_test")
      end

      it "includes description" do
        format = tool.format_for(:default)

        expect(format).to include(tool.description)
      end
    end

    describe "#format_for with unknown format" do
      it "raises ArgumentError for tool_calling format" do
        expect { tool.format_for(:tool_calling) }.to raise_error(ArgumentError, /Unknown tool format/)
      end

      it "lists available formats in error message" do
        expect { tool.format_for(:unknown) }.to raise_error(ArgumentError, /default, code, managed_agent/)
      end
    end

    describe "#validate_inputs_schema!" do
      it "accepts valid input schemas" do
        valid_inputs = {
          param1: { type: "string", description: "Param 1" },
          param2: { type: "integer", description: "Param 2" }
        }

        test_class = Class.new(described_class) do
          self.tool_name = "valid"
          self.description = "Valid tool"
          self.inputs = valid_inputs
          self.output_type = "string"
        end

        expect { test_class.new }.not_to raise_error
      end

      it "rejects non-hash inputs" do
        expect do
          Class.new(described_class) do
            self.tool_name = "invalid"
            self.description = "Invalid"
            self.inputs = "not a hash"
            self.output_type = "string"
          end
        end.to raise_error(Smolagents::ToolConfigurationError)
      end

      it "rejects missing type in input" do
        expect do
          Class.new(described_class) do
            self.tool_name = "no_type"
            self.description = "No type"
            self.inputs = { param: { description: "Missing type" } }
            self.output_type = "string"
          end
        end.to raise_error(Smolagents::ToolConfigurationError)
      end

      it "rejects missing description in input" do
        expect do
          Class.new(described_class) do
            self.tool_name = "no_desc"
            self.description = "No description"
            self.inputs = { param: { type: "string" } }
            self.output_type = "string"
          end
        end.to raise_error(Smolagents::ToolConfigurationError)
      end

      it "rejects invalid type value" do
        expect do
          Class.new(described_class) do
            self.tool_name = "invalid_type"
            self.description = "Invalid type"
            self.inputs = {
              param: { type: "not_a_type", description: "Bad type" }
            }
            self.output_type = "string"
          end
        end.to raise_error(Smolagents::ToolConfigurationError)
      end
    end

    describe "schema immutability" do
      it "stores inputs after setting" do
        tool.class.inputs = { param: { type: "string", description: "Test" } }

        expect(tool.inputs).to eq(param: { type: "string", description: "Test" })
      end

      it "freezes output_schema after setting" do
        tool.class.output_schema = { type: "object" }

        expect(tool.class.output_schema).to be_frozen
      end

      it "returns a hash from to_h" do
        hash = tool.to_h

        expect(hash).to be_a(Hash)
        expect(hash[:inputs]).to have_key(:query)
      end
    end
  end
end
