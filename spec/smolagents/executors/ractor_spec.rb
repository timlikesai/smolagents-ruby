RSpec.describe Smolagents::RactorExecutor do
  let(:executor) { described_class.new }

  it_behaves_like "a ruby executor"

  describe "initialization" do
    it "creates executor with default max_operations" do
      exec = described_class.new
      expect(exec.send(:max_operations)).to eq(Smolagents::Executors::Executor::DEFAULT_MAX_OPERATIONS)
    end

    it "creates executor with custom max_operations" do
      exec = described_class.new(max_operations: 50_000)
      expect(exec.send(:max_operations)).to eq(50_000)
    end

    it "creates executor with custom max_output_length" do
      exec = described_class.new(max_output_length: 25_000)
      expect(exec.send(:max_output_length)).to eq(25_000)
    end

    it "stores both custom limits" do
      exec = described_class.new(max_operations: 75_000, max_output_length: 30_000)
      expect(exec.send(:max_operations)).to eq(75_000)
      expect(exec.send(:max_output_length)).to eq(30_000)
    end
  end

  describe "#supports?" do
    it "returns true for :ruby" do
      expect(executor.supports?(:ruby)).to be true
    end

    it "returns false for other languages" do
      expect(executor.supports?(:python)).to be false
      expect(executor.supports?(:javascript)).to be false
    end

    it "converts string language to symbol for comparison" do
      # The implementation converts to_sym, so "ruby" becomes :ruby
      result = executor.supports?("ruby")
      # Actually, it does convert, so this should be true
      expect(result).to be true
    end
  end

  describe "#execute" do
    context "without tools" do
      it "executes simple code in isolated Ractor" do
        result = executor.execute("[1, 2, 3].sum", language: :ruby)
        expect(result.success?).to be true
        expect(result.output).to eq(6)
      end

      it "returns output from Ractor execution" do
        result = executor.execute("'hello'.upcase", language: :ruby)
        expect(result.success?).to be true
        expect(result.output).to eq("HELLO")
      end

      it "captures puts output in logs" do
        result = executor.execute("puts 'debug'; 42", language: :ruby)
        expect(result.success?).to be true
        expect(result.output).to eq(42)
        expect(result.logs).to include("debug")
      end

      it "captures print output in logs" do
        result = executor.execute("print 'no newline'; 99", language: :ruby)
        expect(result.success?).to be true
        expect(result.output).to eq(99)
        expect(result.logs).to include("no newline")
      end

      it "captures p output in logs" do
        result = executor.execute("p [1, 2, 3]; :symbol", language: :ruby)
        expect(result.success?).to be true
        expect(result.output).to eq(:symbol)
        expect(result.logs).to include("[1, 2, 3]")
      end

      it "handles syntax errors" do
        result = executor.execute("def broken", language: :ruby)
        expect(result.failure?).to be true
        expect(result.error).to include("syntax error")
      end

      it "handles runtime errors" do
        result = executor.execute("1 / 0", language: :ruby)
        expect(result.failure?).to be true
        expect(result.error).to include("ZeroDivisionError")
      end

      it "handles undefined method calls" do
        result = executor.execute("nonexistent_method", language: :ruby)
        expect(result.failure?).to be true
        expect(result.error).to match(/undefined|NoMethodError/)
      end

      it "enforces operation limit" do
        limited = described_class.new(max_operations: 100)
        result = limited.execute("1000.times { |i| i }", language: :ruby)
        expect(result.failure?).to be true
        expect(result.error).to include("Operation limit exceeded")
      end

      it "allows operations within limit" do
        limited = described_class.new(max_operations: 1000)
        result = limited.execute("5.times { |i| i * 2 }", language: :ruby)
        expect(result.success?).to be true
      end

      it "truncates long output logs" do
        executor_with_limit = described_class.new(max_output_length: 100)
        code = "50.times { puts 'x' * 50 }"
        result = executor_with_limit.execute(code, language: :ruby)
        expect(result.logs.bytesize).to be <= 100
      end

      it "blocks eval" do
        result = executor.execute("eval('1 + 1')", language: :ruby)
        expect(result.failure?).to be true
        expect(result.error).to include("Dangerous method call: eval")
      end

      it "blocks system" do
        result = executor.execute("system('ls')", language: :ruby)
        expect(result.failure?).to be true
        expect(result.error).to include("Dangerous method call: system")
      end

      it "blocks File access" do
        result = executor.execute("File.read('/etc/passwd')", language: :ruby)
        expect(result.failure?).to be true
        expect(result.error).to match(/dangerous/i)
      end

      it "blocks require" do
        result = executor.execute("require 'fileutils'", language: :ruby)
        expect(result.failure?).to be true
        expect(result.error).to include("Dangerous method call: require")
      end
    end

    context "with tools" do
      let(:mock_tool) { instance_double(Smolagents::Tools::Tool) }

      before do
        allow(mock_tool).to receive(:call).with(query: "test").and_return("found something")
      end

      it "executes code with tool support" do
        executor.send_tools({ "search" => mock_tool })
        result = executor.execute("search(query: 'test')", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq("found something")
        expect(mock_tool).to have_received(:call).with(query: "test")
      end

      it "handles tool errors gracefully" do
        failing_tool = instance_double(Smolagents::Tools::Tool)
        allow(failing_tool).to receive(:call).and_raise(StandardError, "Tool failed")

        executor.send_tools({ "broken_tool" => failing_tool })
        result = executor.execute("broken_tool()", language: :ruby)

        expect(result.failure?).to be true
        expect(result.error).to include("StandardError: Tool failed")
      end

      it "handles unknown tool calls" do
        executor.send_tools({ "search" => mock_tool })
        result = executor.execute("nonexistent_tool()", language: :ruby)

        expect(result.failure?).to be true
        expect(result.error).to match(/undefined|NoMethodError/)
      end

      it "passes positional arguments to tools" do
        tool = instance_double(Smolagents::Tools::Tool)
        allow(tool).to receive(:call).with("arg1", "arg2").and_return("result")

        executor.send_tools({ "process" => tool })
        result = executor.execute("process('arg1', 'arg2')", language: :ruby)

        expect(result.success?).to be true
        expect(tool).to have_received(:call).with("arg1", "arg2")
      end

      it "passes keyword arguments to tools" do
        tool = instance_double(Smolagents::Tools::Tool)
        allow(tool).to receive(:call).with(name: "value", count: 5).and_return("result")

        executor.send_tools({ "fetch" => tool })
        result = executor.execute("fetch(name: 'value', count: 5)", language: :ruby)

        expect(result.success?).to be true
        expect(tool).to have_received(:call).with(name: "value", count: 5)
      end

      it "passes mixed positional and keyword arguments" do
        tool = instance_double(Smolagents::Tools::Tool)
        allow(tool).to receive(:call).with("pos", key: "val").and_return("result")

        executor.send_tools({ "combined" => tool })
        result = executor.execute("combined('pos', key: 'val')", language: :ruby)

        expect(result.success?).to be true
        expect(tool).to have_received(:call).with("pos", key: "val")
      end

      it "handles tool returning nil" do
        tool = instance_double(Smolagents::Tools::Tool)
        allow(tool).to receive(:call).and_return(nil)

        executor.send_tools({ "nullable" => tool })
        result = executor.execute("nullable()", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to be_nil
      end

      it "handles tool returning complex objects" do
        tool = instance_double(Smolagents::Tools::Tool)
        expected_output = { data: [1, 2, 3], status: "ok" }
        allow(tool).to receive(:call).and_return(expected_output)

        executor.send_tools({ "complex" => tool })
        result = executor.execute("complex()", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq(expected_output)
      end

      it "allows multiple tool calls in sequence" do
        tool1 = instance_double(Smolagents::Tools::Tool)
        tool2 = instance_double(Smolagents::Tools::Tool)
        allow(tool1).to receive(:call).and_return("first")
        allow(tool2).to receive(:call).and_return("second")

        executor.send_tools({ "first" => tool1, "second" => tool2 })
        result = executor.execute("a = first(); b = second(); [a, b]", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq(%w[first second])
      end
    end

    context "with FinalAnswerException" do
      it "catches FinalAnswerException and marks as final" do
        final_tool = instance_double(Smolagents::Tools::Tool)
        allow(final_tool).to receive(:call) do |answer:|
          raise Smolagents::FinalAnswerException, answer
        end

        executor.send_tools({ "final_answer" => final_tool })
        result = executor.execute("final_answer(answer: 'done')", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq("done")
        expect(result.is_final_answer).to be true
      end

      it "preserves logs when final_answer is called" do
        final_tool = instance_double(Smolagents::Tools::Tool)
        allow(final_tool).to receive(:call) do |answer:|
          raise Smolagents::FinalAnswerException, answer
        end

        executor.send_tools({ "final_answer" => final_tool })
        result = executor.execute("puts 'computing'; final_answer(answer: 'result')", language: :ruby)

        expect(result.success?).to be true
        expect(result.logs).to include("computing")
        expect(result.is_final_answer).to be true
      end
    end

    context "with variables" do
      it "accesses passed variables" do
        executor.send_variables({ "x" => 42, "y" => 8 })
        result = executor.execute("x + y", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq(50)
      end

      it "preserves variable types across boundary" do
        executor.send_variables({ "arr" => [1, 2, 3], "hash" => { key: "value" } })
        result = executor.execute("[arr.class, hash.class]", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq([Array, Hash])
      end

      it "handles string variables" do
        executor.send_variables({ "message" => "Hello" })
        result = executor.execute("message.upcase", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq("HELLO")
      end

      it "handles symbol variables" do
        executor.send_variables({ "sym" => :status })
        result = executor.execute("sym.to_s", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq("status")
      end

      it "handles numeric variables" do
        executor.send_variables({ "num" => 3.14 })
        result = executor.execute("(num * 2).round(1)", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq(6.3)
      end

      it "handles boolean variables" do
        executor.send_variables({ "flag" => true })
        result = executor.execute("!flag", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to be false
      end

      it "handles nil variables" do
        executor.send_variables({ "empty" => nil })
        result = executor.execute("empty.nil?", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to be true
      end

      it "handles nested arrays" do
        executor.send_variables({ "data" => [[1, 2], [3, 4]] })
        result = executor.execute("data[0][1]", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq(2)
      end

      it "handles nested hashes" do
        executor.send_variables({ "config" => { server: { host: "localhost", port: 3000 } } })
        result = executor.execute("config[:server][:port]", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq(3000)
      end
    end

    context "when validating parameters" do
      it "rejects non-:ruby language" do
        expect do
          executor.execute("code", language: :python)
        end.to raise_error(ArgumentError, /not supported: python/)
      end

      it "accepts timeout parameter for compatibility" do
        result = executor.execute("42", language: :ruby, timeout: 30)
        expect(result.success?).to be true
        expect(result.output).to eq(42)
      end

      it "ignores additional options" do
        result = executor.execute("42", language: :ruby, foo: "bar", baz: 123)
        expect(result.success?).to be true
        expect(result.output).to eq(42)
      end

      it "requires code parameter" do
        expect do
          executor.execute(nil, language: :ruby)
        end.to raise_error(ArgumentError)
      end
    end

    context "with Ractor-specific isolation" do
      it "provides true isolation by blocking global variable access" do
        result = executor.execute("$global = 100", language: :ruby)
        expect(result.failure?).to be true
        expect(result.error).to match(/global variable|Ractor::IsolationError/i)
      end

      it "each execution gets fresh Ractor state" do
        # Each Ractor is separate, so local variables don't persist between calls
        result1 = executor.execute("x = 42; x", language: :ruby)
        expect(result1.success?).to be true
        expect(result1.output).to eq(42)

        # Second execution in a new Ractor can use same variable name with different value
        result2 = executor.execute("x = 100; x", language: :ruby)
        expect(result2.success?).to be true
        expect(result2.output).to eq(100)
      end

      it "handles complex data structures" do
        result = executor.execute('{ a: [1, 2, 3], b: { nested: "value" } }', language: :ruby)
        expect(result.success?).to be true
        expect(result.output).to eq({ a: [1, 2, 3], b: { nested: "value" } })
      end
    end

    context "when handling errors" do
      it "catches InterpreterError" do
        # Create a scenario where InterpreterError is raised (unsafe code)
        result = executor.execute("__send__(:system, 'ls')", language: :ruby)
        expect(result.failure?).to be true
      end

      it "handles Ractor::RemoteError from isolated execution" do
        # This will cause an error in the Ractor
        result = executor.execute("raise 'Custom error'", language: :ruby)
        expect(result.failure?).to be true
        expect(result.error).to match(/RuntimeError|Custom error/)
      end
    end
  end

  describe "#prepare_for_ractor" do
    context "with primitive types" do
      it "passes through nil" do
        result = executor.send(:prepare_for_ractor, nil)
        expect(result).to be_nil
      end

      it "passes through true" do
        result = executor.send(:prepare_for_ractor, true)
        expect(result).to be true
      end

      it "passes through false" do
        result = executor.send(:prepare_for_ractor, false)
        expect(result).to be false
      end

      it "passes through integers" do
        result = executor.send(:prepare_for_ractor, 42)
        expect(result).to eq(42)
      end

      it "passes through floats" do
        result = executor.send(:prepare_for_ractor, 3.14)
        expect(result).to eq(3.14)
      end

      it "passes through symbols" do
        result = executor.send(:prepare_for_ractor, :symbol)
        expect(result).to eq(:symbol)
      end
    end

    context "with strings" do
      it "freezes unfrozen strings" do
        str = "hello"
        result = executor.send(:prepare_for_ractor, str)
        expect(result).to be_frozen
        expect(result).to eq("hello")
      end

      it "passes frozen strings through" do
        str = "hello".freeze
        result = executor.send(:prepare_for_ractor, str)
        expect(result).to be_frozen
        expect(result).to equal(str)
      end

      it "preserves string content when freezing" do
        str = "test content"
        result = executor.send(:prepare_for_ractor, str)
        expect(result).to eq("test content")
      end
    end

    context "with arrays" do
      it "freezes arrays" do
        arr = [1, 2, 3]
        result = executor.send(:prepare_for_ractor, arr)
        expect(result).to be_frozen
        expect(result).to eq([1, 2, 3])
      end

      it "recursively prepares array contents" do
        arr = [1, "string", { nested: "hash" }]
        result = executor.send(:prepare_for_ractor, arr)

        expect(result).to be_frozen
        expect(result[1]).to be_frozen
        expect(result[2]).to be_frozen
      end

      it "handles nested arrays" do
        arr = [[1, 2], [3, 4]]
        result = executor.send(:prepare_for_ractor, arr)

        expect(result).to be_frozen
        expect(result[0]).to be_frozen
        expect(result[1]).to be_frozen
      end

      it "handles empty arrays" do
        arr = []
        result = executor.send(:prepare_for_ractor, arr)
        expect(result).to be_frozen
        expect(result).to be_empty
      end
    end

    context "with hashes" do
      it "freezes hashes" do
        hash = { a: 1, b: 2 }
        result = executor.send(:prepare_for_ractor, hash)

        expect(result).to be_frozen
        expect(result).to eq({ a: 1, b: 2 })
      end

      it "recursively prepares hash keys" do
        hash = { "key1" => "value1", "key2" => "value2" }
        result = executor.send(:prepare_for_ractor, hash)

        expect(result).to be_frozen
        result.each_key { |k| expect(k).to be_frozen }
      end

      it "recursively prepares hash values" do
        hash = { a: "string", b: [1, 2], c: { nested: true } }
        result = executor.send(:prepare_for_ractor, hash)

        expect(result).to be_frozen
        expect(result[:a]).to be_frozen
        expect(result[:b]).to be_frozen
        expect(result[:c]).to be_frozen
      end

      it "handles nested hashes" do
        hash = { outer: { inner: { value: 42 } } }
        result = executor.send(:prepare_for_ractor, hash)

        expect(result).to be_frozen
        expect(result[:outer]).to be_frozen
        expect(result[:outer][:inner]).to be_frozen
      end

      it "handles empty hashes" do
        hash = {}
        result = executor.send(:prepare_for_ractor, hash)
        expect(result).to be_frozen
        expect(result).to be_empty
      end
    end

    context "with complex types" do
      it "processes Range (stays as Range since shareable)" do
        range = (1..5)
        result = executor.send(:prepare_for_ractor, range)

        # Range is shareable, so it passes through
        expect(result).to eq(range)
      end

      it "converts Set to array" do
        set = Set.new([1, 2, 3])
        result = executor.send(:prepare_for_ractor, set)

        expect(result).to include(1, 2, 3)
        expect(result).to be_frozen
      end

      it "passes Data.define objects through unchanged (Ruby 4.0 - natively shareable)" do
        # Data.define with primitive values is Ractor-shareable by design
        data = Data.define(:x, :y).new(10, 20)
        result = executor.send(:prepare_for_ractor, data)

        # Data.define objects pass through unchanged - no conversion needed
        expect(Ractor.shareable?(data)).to be true
        expect(result).to equal(data) # Same object, not converted
        expect(result.x).to eq(10)
        expect(result.y).to eq(20)
      end

      it "converts objects with to_h to frozen hash" do
        # Any object with to_h gets converted - covers external/legacy types
        obj = Class.new do
          def to_h = { a: 1, b: 2 }
        end.new

        result = executor.send(:prepare_for_ractor, obj)

        expect(result).to eq({ a: 1, b: 2 })
        expect(result).to be_frozen
      end

      it "falls back to string representation for unknown objects" do
        obj = Object.new
        result = executor.send(:prepare_for_ractor, obj)

        expect(result).to be_a(String)
        expect(result).to be_frozen
      end
    end
  end

  describe "#safe_serialize" do
    it "converts Range to frozen array" do
      obj = (1..3)
      result = executor.send(:safe_serialize, obj)

      expect(result).to eq([1, 2, 3])
      expect(result).to be_frozen
    end

    it "converts Set to frozen array" do
      obj = Set.new([1, 2, 3])
      result = executor.send(:safe_serialize, obj)

      expect(result).to be_a(Array)
      expect(result).to be_frozen
    end

    it "converts Data.define to frozen hash when explicitly serialized" do
      # safe_serialize explicitly converts Data to hash
      data = Data.define(:x, :y).new(42, 84)
      result = executor.send(:safe_serialize, data)

      expect(result).to eq({ x: 42, y: 84 })
      expect(result).to be_frozen
    end

    it "converts objects with to_a to frozen array" do
      obj = (1..3)
      result = executor.send(:safe_serialize, obj)

      expect(result).to eq([1, 2, 3])
      expect(result).to be_frozen
    end

    it "falls back to string representation" do
      obj = Object.new
      result = executor.send(:safe_serialize, obj)

      expect(result).to be_a(String)
      expect(result).to be_frozen
    end

    it "preserves nested Data.define objects (natively shareable)" do
      inner = Data.define(:x).new(42)
      obj = { nested: inner }

      result = executor.send(:prepare_for_ractor, obj)

      expect(result).to be_a(Hash)
      # Data.define is shareable, so it passes through unchanged
      expect(result[:nested]).to be_a(Data)
      expect(result[:nested].x).to eq(42)
      expect(result).to be_frozen
    end

    it "recursively converts nested objects with to_h" do
      inner = Class.new do
        def to_h = { x: 42 }
      end.new
      obj = { nested: inner }

      result = executor.send(:prepare_for_ractor, obj)

      expect(result).to be_a(Hash)
      expect(result[:nested]).to eq({ x: 42 })
      expect(result).to be_frozen
    end
  end

  describe "#prepare_variables" do
    it "prepares all variables for Ractor" do
      executor.send_variables({
                                "x" => 42,
                                "str" => "hello",
                                "arr" => [1, 2, 3]
                              })

      vars = executor.send(:prepare_variables)

      expect(vars["x"]).to eq(42)
      expect(vars["str"]).to be_frozen
      expect(vars["arr"]).to be_frozen
    end

    it "returns empty hash when no variables" do
      vars = executor.send(:prepare_variables)
      expect(vars).to eq({})
    end

    it "preserves variable names" do
      executor.send_variables({ "important" => 123 })
      vars = executor.send(:prepare_variables)

      expect(vars.keys).to include("important")
    end
  end

  describe "CodeSandbox" do
    let(:sandbox_class) { Smolagents::Executors::CodeSandbox }

    describe "initialization" do
      it "supports basic execution without tools" do
        # Verify CodeSandbox works via actual execution
        executor.send_variables({ "x" => 42 })
        result = executor.execute("x * 2", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq(84)
      end
    end

    describe "variable access" do
      it "returns variable value when name matches" do
        # Test via execute since sandbox uses method_missing
        executor.send_variables({ "x" => 42 })
        result = executor.execute("x", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq(42)
      end

      it "raises NoMethodError for unknown methods" do
        # Test via execute
        result = executor.execute("unknown_variable", language: :ruby)
        expect(result.failure?).to be true
      end

      it "handles multiple variables" do
        executor.send_variables({ "a" => 10, "b" => 20, "c" => 30 })
        result = executor.execute("a + b + c", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq(60)
      end
    end

    describe "output methods" do
      it "puts to output buffer" do
        result = executor.execute("puts 'line1'; nil", language: :ruby)

        expect(result.logs).to include("line1")
      end

      it "print to output buffer without newline" do
        result = executor.execute("print 'text'; nil", language: :ruby)

        expect(result.logs).to include("text")
      end

      it "p inspects and outputs to buffer" do
        result = executor.execute("p [1, 2, 3]; nil", language: :ruby)

        expect(result.logs).to include("[1, 2, 3]")
      end

      it "captures multiple output lines" do
        result = executor.execute("puts 'a'; puts 'b'; puts 'c'; nil", language: :ruby)

        expect(result.logs).to include("a")
        expect(result.logs).to include("b")
        expect(result.logs).to include("c")
      end
    end

    describe "nil?, class methods" do
      it "handles nil? method" do
        result = executor.execute("nil?", language: :ruby)
        expect(result.success?).to be true
        expect(result.output).to be false
      end

      it "accesses class method on object" do
        result = executor.execute("42.class", language: :ruby)
        expect(result.success?).to be true
        expect(result.output).to eq(Integer)
      end
    end

    describe "comparison methods" do
      it "handles == method" do
        executor.send_variables({ "x" => 5 })
        result = executor.execute("x == 5", language: :ruby)
        expect(result.success?).to be true
        expect(result.output).to be true
      end

      it "handles != method" do
        executor.send_variables({ "x" => 5 })
        result = executor.execute("x != 10", language: :ruby)
        expect(result.success?).to be true
        expect(result.output).to be true
      end
    end

    describe "type checking" do
      it "object methods work in sandbox" do
        result = executor.execute("[1, 2].length", language: :ruby)
        expect(result.success?).to be true
        expect(result.output).to eq(2)
      end
    end
  end

  describe "ToolSandbox" do
    let(:sandbox_class) { Smolagents::Executors::ToolSandbox }

    describe "initialization" do
      it "supports basic execution with tools" do
        # Verify ToolSandbox works via actual execution
        executor.send_variables({ "x" => 42 })
        tool = instance_double(Smolagents::Tools::Tool)
        allow(tool).to receive(:call).with(no_args).and_return(8)
        executor.send_tools({ "helper" => tool })

        result = executor.execute("x + helper()", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq(50)
      end
    end

    describe "variable access with tools" do
      it "returns variable value when name matches" do
        executor.send_variables({ "x" => 42 })
        tool = instance_double(Smolagents::Tools::Tool)
        allow(tool).to receive(:call).and_return("tool result")
        executor.send_tools({ "process" => tool })

        result = executor.execute("x", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq(42)
      end

      it "handles multiple variables and tools" do
        executor.send_variables({ "a" => 10, "b" => 20 })
        tool = instance_double(Smolagents::Tools::Tool)
        allow(tool).to receive(:call).and_return(5)
        executor.send_tools({ "helper" => tool })

        result = executor.execute("a + b", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq(30)
      end

      it "raises NoMethodError for unknown names" do
        executor.send_tools({ "known" => instance_double(Smolagents::Tools::Tool) })
        result = executor.execute("unknown_name", language: :ruby)

        expect(result.failure?).to be true
      end
    end

    describe "output methods in tool context" do
      it "puts to output buffer" do
        tool = instance_double(Smolagents::Tools::Tool)
        allow(tool).to receive(:call).and_return("result")
        executor.send_tools({ "process" => tool })

        result = executor.execute("puts 'output'; nil", language: :ruby)

        expect(result.logs).to include("output")
      end

      it "print to output buffer" do
        tool = instance_double(Smolagents::Tools::Tool)
        allow(tool).to receive(:call).and_return("result")
        executor.send_tools({ "process" => tool })

        result = executor.execute("print 'text'; nil", language: :ruby)

        expect(result.logs).to include("text")
      end

      it "p inspects and outputs" do
        tool = instance_double(Smolagents::Tools::Tool)
        allow(tool).to receive(:call).and_return("result")
        executor.send_tools({ "process" => tool })

        result = executor.execute("p 42; nil", language: :ruby)

        expect(result.logs).to include("42")
      end
    end

    describe "special methods in tool context" do
      it "handles nil? method" do
        tool = instance_double(Smolagents::Tools::Tool)
        allow(tool).to receive(:call).and_return("result")
        executor.send_tools({ "process" => tool })

        result = executor.execute("nil?", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to be false
      end

      it "accesses class on objects with tools available" do
        tool = instance_double(Smolagents::Tools::Tool)
        allow(tool).to receive(:call).and_return("result")
        executor.send_tools({ "process" => tool })

        result = executor.execute("'string'.class", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq(String)
      end
    end

    describe "comparison and type checking" do
      let(:tool) { instance_double(Smolagents::Tools::Tool) }

      before do
        allow(tool).to receive(:call).and_return("result")
        executor.send_tools({ "process" => tool })
      end

      it "handles == comparison" do
        executor.send_variables({ "x" => 5 })
        result = executor.execute("x == 5", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to be true
      end

      it "handles != comparison" do
        executor.send_variables({ "x" => 5 })
        result = executor.execute("x != 10", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to be true
      end
    end
  end

  describe "FinalAnswerSignal" do
    let(:signal_class) { Smolagents::Executors::FinalAnswerSignal }

    describe "initialization" do
      it "stores the value" do
        signal = signal_class.new("the answer")
        expect(signal.value).to eq("the answer")
      end

      it "is a StandardError" do
        signal = signal_class.new("value")
        expect(signal).to be_a(StandardError)
      end

      it "has a message" do
        signal = signal_class.new("anything")
        expect(signal.message).to eq("Final answer")
      end
    end

    describe "value preservation" do
      it "preserves string value" do
        signal = signal_class.new("result")
        expect(signal.value).to eq("result")
      end

      it "preserves numeric value" do
        signal = signal_class.new(42)
        expect(signal.value).to eq(42)
      end

      it "preserves complex value" do
        data = { status: "ok", data: [1, 2, 3] }
        signal = signal_class.new(data)
        expect(signal.value).to eq(data)
      end

      it "preserves nil value" do
        signal = signal_class.new(nil)
        expect(signal.value).to be_nil
      end
    end
  end

  describe "MAX_MESSAGE_ITERATIONS constant" do
    it "is set to 10_000" do
      expect(Smolagents::Executors::Ractor::MAX_MESSAGE_ITERATIONS).to eq(10_000)
    end
  end
end
