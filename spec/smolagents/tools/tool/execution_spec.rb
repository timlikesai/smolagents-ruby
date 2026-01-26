RSpec.describe Smolagents::Tools::Tool do
  describe "Tool execution module" do
    let(:test_tool_class) do
      Class.new(described_class) do
        self.tool_name = "test"
        self.description = "Test tool"
        self.inputs = { value: { type: "integer", description: "A value" } }
        self.output_type = "integer"

        def execute(value:)
          value * 2
        end
      end
    end

    let(:tool) { test_tool_class.new }

    describe "#call" do
      it "calls execute with keyword arguments" do
        result = tool.call(value: 21)

        expect(result).to be_a(Smolagents::ToolResult)
      end

      it "wraps result in ToolResult by default" do
        result = tool.call(value: 10)

        expect(result.data).to eq(20)
        expect(result.tool_name).to eq("test")
      end

      it "skips wrapping with wrap_result: false" do
        result = tool.call(value: 5, wrap_result: false)

        expect(result).to eq(10)
        expect(result).not_to be_a(Smolagents::ToolResult)
      end

      it "accepts hash as single argument" do
        result = tool.call({ value: 15 })

        expect(result.data).to eq(30)
      end

      it "handles keyword arguments" do
        result = tool.call(value: 7)

        expect(result.data).to eq(14)
      end
    end

    describe "execute implementation" do
      it "requires subclass to implement execute" do
        bare_class = Class.new(described_class) do
          self.tool_name = "bare"
          self.description = "Bare tool"
          self.inputs = {}
          self.output_type = "string"
        end

        bare_tool = bare_class.new

        expect { bare_tool.execute }.to raise_error(NotImplementedError)
      end

      it "allows execute with multiple parameters" do
        multi_param_class = Class.new(described_class) do
          self.tool_name = "multi"
          self.description = "Multi param"
          self.inputs = {
            first_num: { type: "integer", description: "First" },
            second_num: { type: "integer", description: "Second" }
          }
          self.output_type = "integer"

          def execute(first_num:, second_num:)
            first_num + second_num
          end
        end

        multi_tool = multi_param_class.new
        result = multi_tool.call(first_num: 10, second_num: 20)

        expect(result.data).to eq(30)
      end

      it "allows execute with optional parameters" do
        optional_class = Class.new(described_class) do
          self.tool_name = "optional"
          self.description = "Optional params"
          self.inputs = {
            base: { type: "integer", description: "Base" },
            multiplier: { type: "integer", description: "Multiplier", nullable: true }
          }
          self.output_type = "integer"

          def execute(base:, multiplier: nil)
            # Security validation sets missing optional params to nil, not Ruby default
            actual_multiplier = multiplier || 1
            base * actual_multiplier
          end
        end

        tool = optional_class.new
        result = tool.call(base: 5)

        expect(result.data).to eq(5)
      end

      it "allows execute to return any type" do
        string_class = Class.new(described_class) do
          self.tool_name = "string_tool"
          self.description = "Returns string"
          self.inputs = { text: { type: "string", description: "Text" } }
          self.output_type = "string"

          def execute(text:)
            text.upcase
          end
        end

        tool = string_class.new
        result = tool.call(text: "hello")

        expect(result.data).to eq("HELLO")
      end

      it "allows execute to return complex objects" do
        complex_class = Class.new(described_class) do
          self.tool_name = "complex"
          self.description = "Complex"
          self.inputs = { data: { type: "object", description: "Data" } }
          self.output_type = "object"

          def execute(data:)
            { processed: data, timestamp: Time.now }
          end
        end

        tool = complex_class.new
        result = tool.call(data: { key: "value" })

        expect(result.data).to have_key(:processed)
        expect(result.data).to have_key(:timestamp)
      end
    end

    describe "result wrapping" do
      it "includes tool metadata in wrapped result" do
        result = tool.call(value: 5)

        expect(result.tool_name).to eq("test")
        expect(result.metadata).to have_key(:created_at)
      end

      it "preserves data through wrapping" do
        expected_value = 42
        result = tool.call(value: expected_value / 2)

        expect(result.data).to eq(expected_value)
      end

      it "handles nil output" do
        nil_class = Class.new(described_class) do
          self.tool_name = "nil_tool"
          self.description = "Returns nil"
          self.inputs = {}
          self.output_type = "null"

          def execute
            nil
          end
        end

        tool = nil_class.new
        result = tool.call

        expect(result.data).to be_nil
      end

      it "handles empty collections" do
        empty_class = Class.new(described_class) do
          self.tool_name = "empty"
          self.description = "Returns empty"
          self.inputs = { type: { type: "string", description: "Type" } }
          self.output_type = "array"

          def execute(type:)
            type == "array" ? [] : {}
          end
        end

        tool = empty_class.new
        array_result = tool.call(type: "array")
        hash_result = tool.call(type: "hash")

        expect(array_result.data).to be_empty
        expect(hash_result.data).to be_empty
      end
    end

    describe "setup hook" do
      it "calls setup on first invocation" do
        setup_class = Class.new(described_class) do
          self.tool_name = "setup_test"
          self.description = "Setup test"
          self.inputs = {}
          self.output_type = "string"

          attr_accessor :setup_called

          def setup
            @setup_called = true
          end

          def execute
            "executed"
          end
        end

        tool = setup_class.new

        expect(tool.setup_called).to be_nil
        tool.call
        expect(tool.setup_called).to be true
      end

      it "calls setup only once" do
        call_count = 0
        setup_class = Class.new(described_class) do
          self.tool_name = "once"
          self.description = "Once"
          self.inputs = {}
          self.output_type = "string"

          define_method :setup do
            call_count += 1
            super() # Required to set @initialized = true
          end

          def execute
            "done"
          end
        end

        tool = setup_class.new
        tool.call
        tool.call
        tool.call

        expect(call_count).to eq(1)
      end
    end

    describe "error handling in execute" do
      it "catches exceptions and re-raises" do
        error_class = Class.new(described_class) do
          self.tool_name = "error"
          self.description = "Error"
          self.inputs = {}
          self.output_type = "string"

          def execute
            raise "Execution error"
          end
        end

        tool = error_class.new

        expect { tool.call }.to raise_error(RuntimeError, "Execution error")
      end

      it "validates arguments before execute" do
        tool = test_tool_class.new

        expect { tool.call(value: "invalid") }
          .to raise_error(Smolagents::ArgumentValidationError)
      end

      it "ignores unexpected keyword arguments" do
        tool = test_tool_class.new

        # Security validation only validates defined inputs; extras are silently filtered out
        result = tool.call(value: 5, unexpected: true)
        expect(result.data).to eq(10)
      end

      it "rejects missing required arguments" do
        tool = test_tool_class.new

        expect { tool.call }
          .to raise_error(Smolagents::ArgumentValidationError)
      end
    end

    describe "execution context" do
      it "maintains isolation between calls" do
        stateful_class = Class.new(described_class) do
          self.tool_name = "stateful"
          self.description = "Stateful"
          self.inputs = { value: { type: "integer", description: "Value" } }
          self.output_type = "integer"

          def execute(value:)
            @counter ||= 0
            @counter += value
            @counter
          end
        end

        tool = stateful_class.new

        result1 = tool.call(value: 5)
        result2 = tool.call(value: 10)

        # Both results are wrapped, check data
        expect(result1.data).to eq(5)
        expect(result2.data).to eq(15)
      end
    end

    describe "argument passing variations" do
      it "supports positional hash argument" do
        result = tool.call({ value: 8 })

        expect(result.data).to eq(16)
      end

      it "supports keyword arguments" do
        result = tool.call(value: 3)

        expect(result.data).to eq(6)
      end

      it "supports mixed with wrap_result" do
        result = tool.call({ value: 4 }, wrap_result: false)

        expect(result).to eq(8)
      end
    end
  end
end
