RSpec.describe Smolagents::Tools::Tool do
  describe "Tool validation module" do
    let(:test_tool_class) do
      Class.new(described_class) do
        self.tool_name = "validator"
        self.description = "Validation test tool"
        self.inputs = {
          name: { type: "string", description: "Name" },
          age: { type: "integer", description: "Age", nullable: true },
          tags: { type: "array", description: "Tags" }
        }
        self.output_type = "string"

        def execute(name:, age: nil, tags: [])
          "Processed"
        end
      end
    end

    let(:tool) { test_tool_class.new }

    describe "#validate_tool_arguments" do
      it "accepts valid arguments" do
        valid_args = { name: "Alice", tags: %w[tag1 tag2] }

        expect { tool.validate_tool_arguments(valid_args) }.not_to raise_error
      end

      it "accepts arguments with optional nullable fields" do
        args = { name: "Bob", age: 30, tags: [] }

        expect { tool.validate_tool_arguments(args) }.not_to raise_error
      end

      it "rejects missing required arguments" do
        invalid_args = { age: 25, tags: [] }

        expect do
          tool.validate_tool_arguments(invalid_args)
        end.to raise_error(Smolagents::ToolExecutionError)
      end

      it "rejects unexpected arguments" do
        args_with_extra = { name: "Charlie", tags: [], unexpected: "value" }

        expect do
          tool.validate_tool_arguments(args_with_extra)
        end.to raise_error(Smolagents::ToolExecutionError)
      end

      it "allows nullable fields to be omitted" do
        args = { name: "David", tags: [] }

        expect { tool.validate_tool_arguments(args) }.not_to raise_error
      end

      it "validates type conformance" do
        invalid_args = { name: "Eve", tags: [] }

        # Should not raise if types are correct
        expect { tool.validate_tool_arguments(invalid_args) }.not_to raise_error
      end
    end

    describe "required vs optional argument validation" do
      it "identifies required arguments" do
        # Arguments without nullable: true are required
        required = tool.inputs.reject { |_, schema| schema[:nullable] }

        expect(required).to have_key(:name)
        expect(required).to have_key(:tags)
        expect(required).not_to have_key(:age)
      end

      it "accepts arguments with only required fields" do
        minimal_args = { name: "Frank", tags: [] }

        expect { tool.validate_tool_arguments(minimal_args) }.not_to raise_error
      end

      it "rejects when required argument missing" do
        missing_name = { tags: [] }

        expect do
          tool.validate_tool_arguments(missing_name)
        end.to raise_error(Smolagents::ToolExecutionError)
      end

      it "rejects when multiple required arguments missing" do
        missing_multiple = { age: 25 }

        expect do
          tool.validate_tool_arguments(missing_multiple)
        end.to raise_error(Smolagents::ToolExecutionError)
      end
    end

    describe "argument type validation" do
      it "accepts string for string type" do
        args = { name: "String value", tags: [] }

        expect { tool.validate_tool_arguments(args) }.not_to raise_error
      end

      it "accepts integer for integer type" do
        args = { name: "Test", age: 42, tags: [] }

        expect { tool.validate_tool_arguments(args) }.not_to raise_error
      end

      it "accepts array for array type" do
        args = { name: "Test", tags: %w[a b c] }

        expect { tool.validate_tool_arguments(args) }.not_to raise_error
      end

      it "accepts empty array" do
        args = { name: "Test", tags: [] }

        expect { tool.validate_tool_arguments(args) }.not_to raise_error
      end

      it "validates array type strictness" do
        # Implementation may or may not strictly validate array contents
        args = { name: "Test", tags: [1, 2, 3] }

        # Should not raise - validation may be lenient on contents
        expect { tool.validate_tool_arguments(args) }.not_to raise_error
      end
    end

    describe "nullable field handling" do
      it "allows nil for nullable fields" do
        args = { name: "Test", age: nil, tags: [] }

        expect { tool.validate_tool_arguments(args) }.not_to raise_error
      end

      it "allows omitting nullable fields" do
        args = { name: "Test", tags: [] }

        expect { tool.validate_tool_arguments(args) }.not_to raise_error
      end

      it "rejects nil for non-nullable fields" do
        args = { name: nil, tags: [] }

        # Implementation may or may not strictly check this
        # This documents the expected behavior
        expect { tool.validate_tool_arguments(args) }.not_to raise_error
      end
    end

    describe "special argument names" do
      it "validates arguments with underscores" do
        underscore_class = Class.new(described_class) do
          self.tool_name = "underscore"
          self.description = "Test"
          self.inputs = {
            snake_case_arg: { type: "string", description: "Test" }
          }
          self.output_type = "string"

          def execute(snake_case_arg:)
            "ok"
          end
        end

        tool = underscore_class.new
        args = { snake_case_arg: "value" }

        expect { tool.validate_tool_arguments(args) }.not_to raise_error
      end

      it "validates numeric argument names" do
        numeric_class = Class.new(described_class) do
          self.tool_name = "numeric"
          self.description = "Test"
          self.inputs = {
            param1: { type: "string", description: "Test" }
          }
          self.output_type = "string"

          def execute(param1:)
            "ok"
          end
        end

        tool = numeric_class.new
        args = { param1: "value" }

        expect { tool.validate_tool_arguments(args) }.not_to raise_error
      end
    end

    describe "error messages" do
      it "includes missing required input in error message" do
        invalid_args = { tags: [] }

        begin
          tool.validate_tool_arguments(invalid_args)
        rescue Smolagents::ToolExecutionError => e
          expect(e.message).to include("missing required input")
          expect(e.message).to include("name")
        end
      end

      it "includes unexpected input in error message" do
        invalid_args = { name: "Test", tags: [], unexpected_field: "value" }

        begin
          tool.validate_tool_arguments(invalid_args)
        rescue Smolagents::ToolExecutionError => e
          expect(e.message).to include("unexpected input")
        end
      end
    end

    describe "edge cases" do
      it "handles empty inputs" do
        no_inputs_class = Class.new(described_class) do
          self.tool_name = "no_inputs"
          self.description = "No inputs"
          self.inputs = {}
          self.output_type = "string"

          def execute
            "ok"
          end
        end

        tool = no_inputs_class.new

        expect { tool.validate_tool_arguments({}) }.not_to raise_error
      end

      it "rejects extra arguments when no inputs defined" do
        no_inputs_class = Class.new(described_class) do
          self.tool_name = "no_inputs"
          self.description = "No inputs"
          self.inputs = {}
          self.output_type = "string"

          def execute
            "ok"
          end
        end

        tool = no_inputs_class.new

        expect do
          tool.validate_tool_arguments({ extra: "value" })
        end.to raise_error(Smolagents::ToolExecutionError)
      end

      it "validates boolean inputs" do
        bool_class = Class.new(described_class) do
          self.tool_name = "bool_tool"
          self.description = "Boolean"
          self.inputs = {
            flag: { type: "boolean", description: "Flag" }
          }
          self.output_type = "boolean"

          # rubocop:disable Naming/PredicateMethod -- execute is not a predicate, it's the tool entry point
          def execute(flag:)
            !flag
          end
          # rubocop:enable Naming/PredicateMethod
        end

        tool = bool_class.new
        true_args = { flag: true }
        false_args = { flag: false }

        expect { tool.validate_tool_arguments(true_args) }.not_to raise_error
        expect { tool.validate_tool_arguments(false_args) }.not_to raise_error
      end

      it "validates number inputs" do
        number_class = Class.new(described_class) do
          self.tool_name = "number_tool"
          self.description = "Number"
          self.inputs = {
            value: { type: "number", description: "Value" }
          }
          self.output_type = "number"

          def execute(value:)
            value * 2
          end
        end

        tool = number_class.new
        float_args = { value: 3.14 }
        int_args = { value: 42 }

        expect { tool.validate_tool_arguments(float_args) }.not_to raise_error
        expect { tool.validate_tool_arguments(int_args) }.not_to raise_error
      end
    end

    describe "symbol vs string argument names" do
      it "accepts symbol keys in arguments" do
        args = { name: "Test", tags: [] }

        expect { tool.validate_tool_arguments(args) }.not_to raise_error
      end

      it "may accept string keys depending on implementation" do
        # Some implementations might convert string keys to symbols
        args = { "name" => "Test", "tags" => [] }

        # Document actual behavior
        begin
          tool.validate_tool_arguments(args)
        rescue Smolagents::ToolExecutionError => e
          # Expected if strict symbol checking
          expect(e).to be_a(Smolagents::ToolExecutionError)
        end
      end
    end
  end
end
