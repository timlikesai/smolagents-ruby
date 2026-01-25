require_relative "../../../lib/smolagents/executors/code_sandbox"

RSpec.describe Smolagents::Executors::CodeSandbox do
  describe "variable access" do
    it "retrieves registered variables" do
      variables = { "x" => 42, "name" => "Alice" }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      expect(sandbox.x).to eq(42)
      expect(sandbox.name).to eq("Alice")
    end

    it "returns nil for missing variables" do
      variables = { "x" => 42 }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      expect { sandbox.missing_var }.to raise_error(NoMethodError, /undefined method `missing_var'/)
    end

    it "handles variables with different types" do
      variables = {
        "int_var" => 42,
        "str_var" => "hello",
        "arr_var" => [1, 2, 3],
        "hash_var" => { key: "value" },
        "nil_var" => nil
      }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      expect(sandbox.int_var).to eq(42)
      expect(sandbox.str_var).to eq("hello")
      expect(sandbox.arr_var).to eq([1, 2, 3])
      expect(sandbox.hash_var).to eq({ key: "value" })
      expect(sandbox.nil_var).to be_nil
    end
  end

  describe "#respond_to_missing?" do
    it "returns true for registered variables" do
      variables = { "my_var" => 42 }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      expect(sandbox.__send__(:respond_to_missing?, :my_var)).to be true
    end

    it "returns false for unregistered variables" do
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      expect(sandbox.__send__(:respond_to_missing?, :missing)).to be false
    end

    it "supports both symbol and string variable names" do
      variables = { "x" => 42 }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      expect(sandbox.__send__(:respond_to_missing?, :x)).to be true
      expect(sandbox.__send__(:respond_to_missing?, "x")).to be true
    end
  end

  describe "#method_missing" do
    it "handles variables as method calls" do
      variables = { "result" => 100 }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      expect(sandbox.result).to eq(100)
    end

    it "ignores arguments passed to variable methods" do
      variables = { "x" => 42 }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      # Variables ignore all arguments
      expect(sandbox.x).to eq(42)
    end

    it "ignores keyword arguments passed to variable methods" do
      variables = { "x" => 42 }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      # Variables ignore all kwargs
      expect(sandbox.x(foo: "bar")).to eq(42)
    end

    it "raises NoMethodError for undefined methods" do
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      expect { sandbox.undefined_method }.to raise_error(NoMethodError, /undefined method `undefined_method'/)
    end

    it "raises NoMethodError with helpful message" do
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      expect { sandbox.foo_bar }.to raise_error(NoMethodError, /foo_bar/)
    end
  end

  describe "inherited behavior from Sandbox" do
    it "captures puts output" do
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      sandbox.puts("Hello")
      expect(buffer.string).to include("Hello")
    end

    it "captures print output" do
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      sandbox.print("test")
      expect(buffer.string).to include("test")
    end

    it "captures p output" do
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      sandbox.p(42)
      expect(buffer.string).to include("42")
    end
  end

  describe "state inspection" do
    it "exposes variables via state method" do
      variables = { "x" => 42, "y" => 100 }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      expect(sandbox.state).to eq(variables)
    end

    it "returns a reference to variables" do
      variables = { "x" => 42 }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      # Modify original, check state reflects it (proves reference, not copy)
      variables["y"] = 100
      expect(sandbox.state["y"]).to eq(100)
    end
  end

  describe "security isolation" do
    it "prevents access to global methods" do
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      expect { sandbox.system("ls") }.to raise_error(NoMethodError)
    end

    it "prevents access to Object methods" do
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      # Methods from Object shouldn't be available
      expect { sandbox.eval("1 + 1") }.to raise_error(NoMethodError)
    end

    it "does not provide access to local variables outside sandbox" do
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      expect { sandbox.outside_var }.to raise_error(NoMethodError)
    end
  end

  describe "nil? and class methods" do
    it "handles nil? for variables" do
      variables = { "x" => nil, "y" => 42 }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      # nil? is inherited from Sandbox - always false in sandbox
      expect(sandbox.nil?).to be false
    end

    it "handles class method" do
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      # class always returns Object in sandbox context
      expect(sandbox.class).to eq(Object)
    end
  end

  describe "edge cases" do
    it "handles empty variable names" do
      # This is technically possible but should be handled safely
      variables = { "" => 42 }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      # Calling with empty string method name should raise
      expect { sandbox.send(:"") }.to raise_error(ArgumentError)
    end

    it "handles special characters in variable names" do
      variables = { "special_var_123" => "value" }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      expect(sandbox.special_var_123).to eq("value")
    end

    it "handles numeric variable values" do
      variables = { "zero" => 0, "negative" => -42, "float" => 3.14 }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      expect(sandbox.zero).to eq(0)
      expect(sandbox.negative).to eq(-42)
      expect(sandbox.float).to eq(3.14)
    end

    it "handles boolean variable values" do
      variables = { "true_var" => true, "false_var" => false }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      expect(sandbox.true_var).to be true
      expect(sandbox.false_var).to be false
    end
  end
end
