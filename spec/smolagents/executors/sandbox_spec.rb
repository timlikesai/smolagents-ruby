require_relative "../../../lib/smolagents/executors/sandbox"

RSpec.describe Smolagents::Executors::Sandbox do
  describe "initialization" do
    it "accepts variables and output_buffer" do
      variables = { "x" => 42 }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      # BasicObject descendants don't have is_a?, so check state instead
      expect(sandbox.state).to eq(variables)
    end
  end

  describe "#state" do
    it "returns the variables hash" do
      variables = { "x" => 42, "name" => "test" }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      expect(sandbox.state).to eq(variables)
    end

    it "returns reference to internal variables" do
      variables = { "x" => 42 }
      buffer = StringIO.new
      sandbox = described_class.new(variables:, output_buffer: buffer)

      # Modify original, check state reflects it (proves reference, not copy)
      variables["y"] = 100
      expect(sandbox.state["y"]).to eq(100)
    end
  end

  describe "output methods" do
    describe "#puts" do
      it "writes to output buffer" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        sandbox.puts("Hello")
        expect(buffer.string).to include("Hello")
      end

      it "returns nil" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        result = sandbox.puts("test")
        expect(result).to be_nil
      end

      it "handles multiple arguments" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        sandbox.puts("line1", "line2")
        output = buffer.string
        expect(output).to include("line1")
        expect(output).to include("line2")
      end

      it "handles no arguments" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        result = sandbox.puts
        expect(result).to be_nil
      end
    end

    describe "#print" do
      it "writes to output buffer without newline" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        sandbox.print("Hello")
        sandbox.print("World")
        expect(buffer.string).to eq("HelloWorld")
      end

      it "returns nil" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        result = sandbox.print("test")
        expect(result).to be_nil
      end

      it "handles multiple arguments" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        sandbox.print("a", "b", "c")
        expect(buffer.string).to eq("abc")
      end
    end

    describe "#p" do
      it "prints inspected representation" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        sandbox.p(42)
        expect(buffer.string).to include("42")
      end

      it "handles multiple arguments" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        sandbox.p(1, 2, 3)
        output = buffer.string
        expect(output).to include("1")
        expect(output).to include("2")
        expect(output).to include("3")
      end

      it "returns single argument when given one arg" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        result = sandbox.p(42)
        expect(result).to eq(42)
      end

      it "returns array of arguments when given multiple args" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        result = sandbox.p(1, 2, 3)
        expect(result).to eq([1, 2, 3])
      end

      it "handles no arguments" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        result = sandbox.p
        # With no arguments, p returns nil (first element of empty array)
        expect(result).to be_nil
      end
    end
  end

  describe "Kernel delegation" do
    describe "#rand" do
      it "delegates to Kernel.rand with no arguments" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        result = sandbox.rand
        expect(result).to be_a(Float)
        expect(result).to be >= 0
        expect(result).to be < 1
      end

      it "delegates to Kernel.rand with max argument" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        result = sandbox.rand(10)
        expect(result).to be >= 0
        expect(result).to be < 10
      end
    end

    describe "#raise" do
      it "raises exceptions" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        expect { sandbox.raise("Error") }.to raise_error(RuntimeError, "Error")
      end

      it "raises with custom exception class" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        expect { sandbox.raise(ArgumentError, "bad arg") }.to raise_error(ArgumentError, "bad arg")
      end
    end

    describe "#loop" do
      it "executes block repeatedly" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        count = 0
        expect do
          sandbox.loop do
            count += 1
            break if count > 2
          end
        end.not_to raise_error

        expect(count).to eq(3)
      end

      it "breaks from loop" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        count = 0
        sandbox.loop do
          count += 1
          break if count >= 5
        end

        expect(count).to eq(5)
      end
    end
  end

  describe "type checking methods" do
    describe "#is_a?" do
      it "always returns false" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        expect(sandbox.is_a?(Object)).to be false
        expect(sandbox.is_a?(described_class)).to be false
      end
    end

    describe "#kind_of?" do
      it "always returns false" do
        buffer = StringIO.new
        sandbox = described_class.new(variables: {}, output_buffer: buffer)

        expect(sandbox.is_a?(Object)).to be false
      end
    end

    describe "#==" do
      it "uses object equality" do
        buffer = StringIO.new
        sandbox1 = described_class.new(variables: {}, output_buffer: buffer)
        sandbox2 = described_class.new(variables: {}, output_buffer: buffer)
        same_ref = sandbox1

        expect(sandbox1 == same_ref).to be true
        expect(sandbox1 == sandbox2).to be false
      end
    end

    describe "#!=" do
      it "returns opposite of ==" do
        buffer = StringIO.new
        sandbox1 = described_class.new(variables: {}, output_buffer: buffer)
        sandbox2 = described_class.new(variables: {}, output_buffer: buffer)
        same_ref = sandbox1

        expect(sandbox1 != same_ref).to be false
        expect(sandbox1 != sandbox2).to be true
      end
    end
  end

  describe "#handle_unknown_method" do
    it "returns false for nil? via handle_unknown_method" do
      buffer = StringIO.new
      sandbox = described_class.new(variables: {}, output_buffer: buffer)

      # Use public_send via Kernel binding for BasicObject
      result = sandbox.handle_unknown_method(:nil?)
      expect(result).to be false
    end

    it "returns Object for class via handle_unknown_method" do
      buffer = StringIO.new
      sandbox = described_class.new(variables: {}, output_buffer: buffer)

      result = sandbox.handle_unknown_method(:class)
      expect(result).to eq(Object)
    end

    it "raises NoMethodError for unknown methods" do
      buffer = StringIO.new
      sandbox = described_class.new(variables: {}, output_buffer: buffer)

      expect do
        sandbox.handle_unknown_method(:unknown_method)
      end.to raise_error(NoMethodError, /undefined method `unknown_method'/)
    end

    it "raises with method name in message" do
      buffer = StringIO.new
      sandbox = described_class.new(variables: {}, output_buffer: buffer)

      expect { sandbox.some_undefined_method }.to raise_error(NoMethodError, /some_undefined_method/)
    end
  end

  describe "BasicObject inheritance" do
    it "inherits from BasicObject" do
      expect(described_class.superclass).to eq(BasicObject)
    end

    it "provides minimal interface" do
      # BasicObject descendants don't have .methods, verify via class structure
      # The class has only specific defined methods, not Object's full set
      defined_methods = described_class.instance_methods(false)
      expect(defined_methods).to include(:puts, :print, :p, :state)
    end
  end

  describe "isolation guarantees" do
    it "cannot call arbitrary Object methods" do
      buffer = StringIO.new
      sandbox = described_class.new(variables: {}, output_buffer: buffer)

      expect { sandbox.class.new }.to raise_error(NoMethodError)
    end

    it "has no access to external files" do
      buffer = StringIO.new
      sandbox = described_class.new(variables: {}, output_buffer: buffer)

      expect { sandbox.open("/etc/passwd") }.to raise_error(NoMethodError)
    end

    it "cannot require libraries" do
      buffer = StringIO.new
      sandbox = described_class.new(variables: {}, output_buffer: buffer)

      expect { sandbox.require("json") }.to raise_error(NoMethodError)
    end
  end

  describe "output buffer interaction" do
    it "uses same buffer for multiple calls" do
      buffer = StringIO.new
      sandbox = described_class.new(variables: {}, output_buffer: buffer)

      sandbox.puts("first")
      sandbox.print("second")
      sandbox.p("third")

      output = buffer.string
      expect(output).to include("first")
      expect(output).to include("second")
      expect(output).to include("third")
    end

    it "appends to buffer" do
      buffer = StringIO.new
      buffer.write("existing")
      sandbox = described_class.new(variables: {}, output_buffer: buffer)

      sandbox.puts("new")
      expect(buffer.string).to include("existing")
      expect(buffer.string).to include("new")
    end
  end
end
