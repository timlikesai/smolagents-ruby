# Shared examples for executor sandbox patterns.
# Extracting common patterns from RactorExecutor and LocalRubyExecutor specs.

RSpec.shared_examples "an executor" do
  describe "#execute" do
    it "returns an ExecutionResult" do
      result = executor.execute("42", language: :ruby)
      expect(result).to be_a(Smolagents::Executors::Executor::ExecutionResult)
    end

    it "returns output from successful execution" do
      result = executor.execute("2 + 2", language: :ruby)
      expect(result.success?).to be true
      expect(result.output).to eq(4)
    end

    it "reports failure state on errors" do
      result = executor.execute("1 / 0", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).not_to be_nil
    end
  end

  describe "sandbox isolation" do
    it "isolates instance variables between executions" do
      executor.execute("@ivar = 42", language: :ruby)
      result = executor.execute("@ivar", language: :ruby)
      expect(result.output).to be_nil
    end

    it "isolates local variables between executions" do
      executor.execute("local = 100", language: :ruby)
      result = executor.execute("defined?(local)", language: :ruby)
      expect(result.output).to be_nil
    end

    it "allows basic Ruby operations" do
      result = executor.execute("[1, 2, 3].map { |x| x * 2 }", language: :ruby)
      expect(result.success?).to be true
      expect(result.output).to eq([2, 4, 6])
    end

    it "supports string interpolation" do
      result = executor.execute('x = 42; "The answer is #{x}"', language: :ruby)
      expect(result.output).to eq("The answer is 42")
    end

    it "supports hash operations", max_time: 0.03 do
      result = executor.execute("{ a: 1, b: 2 }.values.sum", language: :ruby)
      expect(result.success?).to be true
      expect(result.output).to eq(3)
    end

    it "supports method chaining" do
      result = executor.execute('"hello".upcase.reverse', language: :ruby)
      expect(result.output).to eq("OLLEH")
    end
  end

  describe "output capture" do
    it "captures puts output in logs" do
      result = executor.execute("puts 'debug'; 42", language: :ruby)
      expect(result.output).to eq(42)
      expect(result.logs).to include("debug")
    end

    it "captures print output in logs" do
      result = executor.execute("print 'message'; 99", language: :ruby)
      expect(result.output).to eq(99)
      expect(result.logs).to include("message")
    end

    it "captures p output in logs" do
      result = executor.execute("p [1, 2, 3]; :done", language: :ruby)
      expect(result.output).to eq(:done)
      expect(result.logs).to include("[1, 2, 3]")
    end

    it "captures multiple output lines" do
      result = executor.execute("puts 'a'; puts 'b'; puts 'c'; nil", language: :ruby)
      expect(result.logs).to include("a")
      expect(result.logs).to include("b")
      expect(result.logs).to include("c")
    end
  end

  describe "tool integration" do
    it "calls tools via method_missing" do
      tool = double("Tool") # rubocop:disable RSpec/VerifiedDoubles -- duck-typed tool interface
      allow(tool).to receive(:call).with(query: "test").and_return("result")

      executor.send_tools({ "search" => tool })
      result = executor.execute("search(query: 'test')", language: :ruby)

      expect(result.success?).to be true
      expect(result.output).to eq("result")
      expect(tool).to have_received(:call).with(query: "test")
    end

    it "passes positional arguments to tools" do
      tool = double("Tool") # rubocop:disable RSpec/VerifiedDoubles -- duck-typed tool interface
      allow(tool).to receive(:call).with("arg1", "arg2").and_return("combined")

      executor.send_tools({ "combine" => tool })
      result = executor.execute("combine('arg1', 'arg2')", language: :ruby)

      expect(result.success?).to be true
      expect(tool).to have_received(:call).with("arg1", "arg2")
    end

    it "passes keyword arguments to tools" do
      tool = double("Tool") # rubocop:disable RSpec/VerifiedDoubles -- duck-typed tool interface
      allow(tool).to receive(:call).with(name: "value", count: 5).and_return("done")

      executor.send_tools({ "fetch" => tool })
      result = executor.execute("fetch(name: 'value', count: 5)", language: :ruby)

      expect(result.success?).to be true
      expect(tool).to have_received(:call).with(name: "value", count: 5)
    end

    it "handles tool errors gracefully" do
      tool = double("Tool") # rubocop:disable RSpec/VerifiedDoubles -- duck-typed tool interface
      allow(tool).to receive(:call).and_raise(StandardError, "Tool failed")

      executor.send_tools({ "broken_tool" => tool })
      result = executor.execute("broken_tool()", language: :ruby)

      expect(result.failure?).to be true
      expect(result.error).to include("Tool failed")
    end

    it "handles tool returning nil" do
      tool = double("Tool") # rubocop:disable RSpec/VerifiedDoubles -- duck-typed tool interface
      allow(tool).to receive(:call).and_return(nil)

      executor.send_tools({ "nullable" => tool })
      result = executor.execute("nullable()", language: :ruby)

      expect(result.success?).to be true
      expect(result.output).to be_nil
    end

    it "allows multiple tool calls in sequence" do
      tool1 = double("Tool1") # rubocop:disable RSpec/VerifiedDoubles -- duck-typed tool interface
      tool2 = double("Tool2") # rubocop:disable RSpec/VerifiedDoubles -- duck-typed tool interface
      allow(tool1).to receive(:call).and_return("first")
      allow(tool2).to receive(:call).and_return("second")

      executor.send_tools({ "first" => tool1, "second" => tool2 })
      result = executor.execute("a = first(); b = second(); [a, b]", language: :ruby)

      expect(result.success?).to be true
      expect(result.output).to eq(%w[first second])
    end
  end

  describe "variable integration" do
    it "allows accessing variables" do
      executor.send_variables({ "x" => 42 })
      result = executor.execute("x * 2", language: :ruby)

      expect(result.success?).to be true
      expect(result.output).to eq(84)
    end

    it "handles multiple variables" do
      executor.send_variables({ "a" => 10, "b" => 20, "c" => 30 })
      result = executor.execute("a + b + c", language: :ruby)

      expect(result.success?).to be true
      expect(result.output).to eq(60)
    end

    it "preserves variable types" do
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

    it "handles boolean variables" do
      executor.send_variables({ "flag" => true })
      result = executor.execute("!flag", language: :ruby)

      expect(result.success?).to be true
      expect(result.output).to be false
    end

    it "handles missing variables" do
      result = executor.execute("nonexistent_var", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/undefined (local variable or )?method|NoMethodError/)
    end
  end

  describe "FinalAnswerException handling" do
    before do
      final_answer_tool = double("FinalAnswerTool") # rubocop:disable RSpec/VerifiedDoubles -- duck-typed tool interface
      allow(final_answer_tool).to receive(:call) do |answer:|
        raise Smolagents::FinalAnswerException, answer
      end
      executor.send_tools({ "final_answer" => final_answer_tool })
    end

    it "catches FinalAnswerException and marks as final" do
      result = executor.execute("final_answer(answer: 'done')", language: :ruby)

      expect(result.success?).to be true
      expect(result.output).to eq("done")
      expect(result.is_final_answer).to be true
    end

    it "preserves logs when final_answer is called" do
      result = executor.execute("puts 'computing'; final_answer(answer: 'result')", language: :ruby)

      expect(result.success?).to be true
      expect(result.logs).to include("computing")
      expect(result.is_final_answer).to be true
    end
  end
end

RSpec.shared_examples "a safe executor" do
  describe "dangerous method blocking" do
    it "blocks eval" do
      result = executor.execute("eval('1 + 1')", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to include("Dangerous method call: eval")
    end

    it "blocks instance_eval" do
      result = executor.execute("instance_eval('1 + 1')", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/Dangerous method call|dangerous/i)
    end

    it "blocks system" do
      result = executor.execute("system('ls')", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to include("Dangerous method call: system")
    end

    it "blocks backticks" do
      result = executor.execute("`ls`", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/Dangerous method call|dangerous/i)
    end

    it "blocks exec" do
      result = executor.execute("exec('ls')", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/Dangerous method call|dangerous/i)
    end

    it "blocks fork" do
      result = executor.execute("fork { puts 'child' }", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/Dangerous method call|dangerous/i)
    end

    it "blocks spawn" do
      result = executor.execute("spawn('ls')", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/Dangerous method call|dangerous/i)
    end

    it "blocks require" do
      result = executor.execute("require 'fileutils'", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to include("Dangerous method call: require")
    end

    it "blocks require_relative" do
      result = executor.execute("require_relative 'secret'", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/Dangerous method call|dangerous/i)
    end

    it "blocks load" do
      result = executor.execute("load 'malicious.rb'", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/Dangerous method call|dangerous/i)
    end
  end

  describe "filesystem access blocking" do
    it "blocks File.read" do
      result = executor.execute("File.read('/etc/passwd')", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/dangerous/i)
    end

    it "blocks File.write" do
      result = executor.execute("File.write('/tmp/test', 'data')", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/dangerous/i)
    end

    it "blocks File.open" do
      result = executor.execute("File.open('/etc/passwd')", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/dangerous/i)
    end

    it "blocks Dir.glob" do
      result = executor.execute("Dir.glob('**/*')", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/dangerous/i)
    end

    it "blocks IO.read" do
      result = executor.execute("IO.read('/etc/passwd')", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/dangerous/i)
    end
  end

  describe "method access bypasses" do
    it "blocks __send__ bypass" do
      result = executor.execute("__send__(:system, 'ls')", language: :ruby)
      expect(result.failure?).to be true
    end

    it "blocks send bypass" do
      result = executor.execute("send(:system, 'ls')", language: :ruby)
      expect(result.failure?).to be true
    end

    it "blocks public_send bypass" do
      result = executor.execute("public_send(:system, 'ls')", language: :ruby)
      expect(result.failure?).to be true
    end

    it "blocks method bypass" do
      result = executor.execute("method(:system).call('ls')", language: :ruby)
      expect(result.failure?).to be true
    end
  end

  describe "constant access" do
    it "blocks ObjectSpace access" do
      result = executor.execute("ObjectSpace.each_object(String) {}", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/dangerous/i)
    end

    it "blocks Kernel direct access" do
      result = executor.execute("Kernel.system('ls')", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/dangerous/i)
    end
  end

  describe "operation limits" do
    let(:limited_executor) { described_class.new(max_operations: 50) }

    it "enforces operation limit" do
      result = limited_executor.execute("100.times { |i| i }", language: :ruby)

      expect(result.failure?).to be true
      expect(result.error).to include("Operation limit exceeded")
    end

    it "allows reasonable operation counts" do
      result = limited_executor.execute("5.times { |i| i * 2 }", language: :ruby)

      expect(result.success?).to be true
    end
  end

  describe "output limits" do
    let(:limited_executor) { described_class.new(max_output_length: 100) }

    it "truncates long output logs" do
      code = "50.times { puts 'x' * 50 }"
      result = limited_executor.execute(code, language: :ruby)
      expect(result.logs.bytesize).to be <= 100
    end
  end

  describe "error handling" do
    it "handles syntax errors" do
      result = executor.execute("def broken", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/syntax error/i)
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

    it "handles NameError" do
      result = executor.execute("UndefinedConstant", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/NameError|uninitialized/)
    end

    it "handles TypeError" do
      result = executor.execute("'string' + 42", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/TypeError|no implicit conversion/)
    end

    it "handles ArgumentError", :slow do
      result = executor.execute("[1, 2, 3].first(1, 2, 3)", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/ArgumentError|wrong number of arguments/)
    end
  end
end
