RSpec.describe Smolagents::LocalRubyExecutor do
  let(:executor) { described_class.new }

  describe "#supports?" do
    it "supports Ruby" do
      expect(executor.supports?(:ruby)).to be true
    end

    it "does not support other languages" do
      expect(executor.supports?(:python)).to be false
      expect(executor.supports?(:javascript)).to be false
    end
  end

  describe "#execute" do
    it "executes simple Ruby code" do
      result = executor.execute("2 + 2", language: :ruby)
      expect(result.success?).to be true
      expect(result.output).to eq(4)
    end

    it "executes string operations" do
      result = executor.execute("'hello'.upcase", language: :ruby)
      expect(result.output).to eq("HELLO")
    end

    it "executes array operations" do
      result = executor.execute("[1, 2, 3].sum", language: :ruby)
      expect(result.output).to eq(6)
    end

    it "captures output from puts" do
      result = executor.execute("puts 'debug'; 42", language: :ruby)
      expect(result.output).to eq(42)
      expect(result.logs).to include("debug")
    end

    it "handles syntax errors" do
      result = executor.execute("def broken", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to include("syntax errors")
    end

    it "handles runtime errors" do
      result = executor.execute("1 / 0", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to include("ZeroDivisionError")
    end

    it "enforces timeout" do
      result = executor.execute("sleep 10", language: :ruby, timeout: 1)
      expect(result.failure?).to be true
      expect(result.error).to include("timeout")
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

    it "requires language to be :ruby" do
      expect do
        executor.execute("code", language: :python)
      end.to raise_error(ArgumentError, /not supported: python/)
    end

    it "truncates long output logs" do
      long_code = "10000.times { puts 'x' * 100 }"
      result = executor.execute(long_code, language: :ruby, timeout: 2)
      expect(result.logs.bytesize).to be <= 50_000
    end
  end

  describe "tool integration" do
    it "allows calling tools via method_missing" do
      tool = double("Tool")
      allow(tool).to receive(:call).with(query: "test").and_return("result")

      executor.send_tools({ "search" => tool })
      result = executor.execute("search(query: 'test')", language: :ruby)

      expect(result.success?).to be true
      expect(result.output).to eq("result")
    end

    it "handles tool errors gracefully" do
      tool = double("Tool")
      allow(tool).to receive(:call).and_raise(StandardError, "Tool failed")

      executor.send_tools({ "search" => tool })
      result = executor.execute("search(query: 'test')", language: :ruby)

      expect(result.failure?).to be true
      expect(result.error).to include("Tool failed")
    end
  end

  describe "variable integration" do
    it "allows accessing variables" do
      executor.send_variables({ "x" => 42 })
      result = executor.execute("x * 2", language: :ruby)

      expect(result.success?).to be true
      expect(result.output).to eq(84)
    end

    it "handles missing variables" do
      result = executor.execute("nonexistent_var", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to match(/undefined (local variable or )?method/)
    end
  end

  describe "FinalAnswerException handling" do
    before do
      final_answer_tool = double("FinalAnswerTool")
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
  end

  describe "operation counter" do
    it "prevents infinite loops" do
      infinite_loop = "i = 0; while true; i += 1; end"
      result = executor.execute(infinite_loop, language: :ruby, timeout: 1)

      expect(result.failure?).to be true
      expect(result.error).to match(/Operation limit exceeded|timeout/)
    end

    it "allows reasonable operation counts" do
      reasonable_loop = "1000.times { |i| i * 2 }"
      result = executor.execute(reasonable_loop, language: :ruby)

      expect(result.success?).to be true
    end
  end

  describe "sandbox isolation" do
    it "isolates execution environment" do
      executor.execute("@instance_var = 42", language: :ruby)

      result = executor.execute("@instance_var", language: :ruby)
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
  end
end
