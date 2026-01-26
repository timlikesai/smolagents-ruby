require "spec_helper"

RSpec.describe Smolagents::Security do
  describe "module structure" do
    it "defines VIOLATION_TYPES constant" do
      expect(described_class::VIOLATION_TYPES).to be_an(Array)
      expect(described_class::VIOLATION_TYPES).to be_frozen
    end

    it "includes all expected violation types" do
      expected = %i[dangerous_method dangerous_constant backtick_execution
                    dangerous_pattern dangerous_import syntax_error]
      expect(described_class::VIOLATION_TYPES).to match_array(expected)
    end

    it "defines VIOLATION_MESSAGES constant" do
      expect(described_class::VIOLATION_MESSAGES).to be_a(Hash)
      expect(described_class::VIOLATION_MESSAGES).to be_frozen
    end

    it "has messages for all violation types" do
      described_class::VIOLATION_TYPES.each do |type|
        expect(described_class::VIOLATION_MESSAGES).to have_key(type)
      end
    end
  end

  describe Smolagents::Security::ValidationResult do
    describe ".success" do
      subject(:result) { described_class.success }

      it "creates a valid result" do
        expect(result.valid?).to be true
      end

      it "has empty violations" do
        expect(result.violations).to eq([])
      end

      it "has frozen violations" do
        expect(result.violations).to be_frozen
      end

      it "is not invalid" do
        expect(result.invalid?).to be false
      end

      it "returns nil for error message" do
        expect(result.to_error_message).to be_nil
      end
    end

    describe ".failure" do
      subject(:result) { described_class.failure(violations: [violation]) }

      let(:violation) { Smolagents::Security::ValidationViolation.dangerous_method("eval") }

      it "creates an invalid result" do
        expect(result.valid?).to be false
      end

      it "is invalid" do
        expect(result.invalid?).to be true
      end

      it "contains the violations" do
        expect(result.violations).to eq([violation])
      end

      it "has frozen violations" do
        expect(result.violations).to be_frozen
      end

      it "returns error message" do
        expect(result.to_error_message).to include("Code validation failed")
        expect(result.to_error_message).to include("Dangerous method call: eval")
      end

      it "accepts single violation" do
        single_result = described_class.failure(violations: violation)
        expect(single_result.violations).to eq([violation])
      end
    end

    describe "immutability" do
      it "is immutable (Data.define)" do
        result = described_class.success
        expect { result.valid = false }.to raise_error(NoMethodError)
      end
    end
  end

  describe Smolagents::Security::ValidationViolation do
    describe "factory methods" do
      describe ".dangerous_method" do
        subject(:violation) { described_class.dangerous_method("eval") }

        it "sets type to :dangerous_method" do
          expect(violation.type).to eq(:dangerous_method)
        end

        it "sets detail to the method name" do
          expect(violation.detail).to eq("eval")
        end

        it "has nil context by default" do
          expect(violation.context).to be_nil
        end

        it "accepts context parameter" do
          v = described_class.dangerous_method("eval", context: :interpolation)
          expect(v.context).to eq(:interpolation)
        end
      end

      describe ".dangerous_constant" do
        subject(:violation) { described_class.dangerous_constant("File") }

        it "sets type to :dangerous_constant" do
          expect(violation.type).to eq(:dangerous_constant)
        end

        it "sets detail to the constant name" do
          expect(violation.detail).to eq("File")
        end
      end

      describe ".backtick_execution" do
        subject(:violation) { described_class.backtick_execution }

        it "sets type to :backtick_execution" do
          expect(violation.type).to eq(:backtick_execution)
        end

        it "sets detail to command execution" do
          expect(violation.detail).to eq("command execution")
        end
      end

      describe ".dangerous_pattern" do
        subject(:violation) { described_class.dangerous_pattern("`ls`") }

        it "sets type to :dangerous_pattern" do
          expect(violation.type).to eq(:dangerous_pattern)
        end

        it "sets detail to the pattern" do
          expect(violation.detail).to eq("`ls`")
        end
      end

      describe ".dangerous_import" do
        subject(:violation) { described_class.dangerous_import("net/http") }

        it "sets type to :dangerous_import" do
          expect(violation.type).to eq(:dangerous_import)
        end

        it "sets detail to the import name" do
          expect(violation.detail).to eq("net/http")
        end
      end

      describe ".syntax_error" do
        subject(:violation) { described_class.syntax_error("unexpected end") }

        it "sets type to :syntax_error" do
          expect(violation.type).to eq(:syntax_error)
        end

        it "sets detail to the message" do
          expect(violation.detail).to eq("unexpected end")
        end

        it "has nil context" do
          expect(violation.context).to be_nil
        end
      end
    end

    describe "#in_interpolation?" do
      it "returns true when context is :interpolation" do
        v = described_class.dangerous_method("eval", context: :interpolation)
        expect(v.in_interpolation?).to be true
      end

      it "returns false when context is nil" do
        v = described_class.dangerous_method("eval")
        expect(v.in_interpolation?).to be false
      end

      it "returns false for other contexts" do
        v = described_class.dangerous_method("eval", context: :other)
        expect(v.in_interpolation?).to be false
      end
    end

    describe "#to_s" do
      it "formats dangerous_method correctly" do
        v = described_class.dangerous_method("eval")
        expect(v.to_s).to eq("Dangerous method call: eval")
      end

      it "formats dangerous_constant correctly" do
        v = described_class.dangerous_constant("File")
        expect(v.to_s).to eq("Dangerous constant access: File")
      end

      it "formats backtick_execution without detail" do
        v = described_class.backtick_execution
        expect(v.to_s).to eq("Backtick command execution")
      end

      it "formats dangerous_pattern correctly" do
        v = described_class.dangerous_pattern("`ls`")
        expect(v.to_s).to eq("Dangerous pattern: `ls`")
      end

      it "formats syntax_error correctly" do
        v = described_class.syntax_error("unexpected end")
        expect(v.to_s).to eq("Syntax error: unexpected end")
      end

      it "adds interpolation context suffix" do
        v = described_class.dangerous_method("eval", context: :interpolation)
        expect(v.to_s).to eq("Dangerous method call: eval (in string interpolation)")
      end
    end
  end

  describe Smolagents::Security::NodeContext do
    describe ".root" do
      subject(:context) { described_class.root }

      it "is not in interpolation" do
        expect(context.in_interpolation).to be false
      end

      it "has depth 0" do
        expect(context.depth).to eq(0)
      end

      it "returns nil context_type" do
        expect(context.context_type).to be_nil
      end
    end

    describe "#enter_interpolation" do
      subject(:interpolation_context) { root.enter_interpolation }

      let(:root) { described_class.root }

      it "sets in_interpolation to true" do
        expect(interpolation_context.in_interpolation).to be true
      end

      it "increments depth" do
        expect(interpolation_context.depth).to eq(1)
      end

      it "returns :interpolation for context_type" do
        expect(interpolation_context.context_type).to eq(:interpolation)
      end

      it "does not mutate original context" do
        interpolation_context
        expect(root.in_interpolation).to be false
        expect(root.depth).to eq(0)
      end
    end

    describe "#descend" do
      subject(:descended) { root.descend }

      let(:root) { described_class.root }

      it "preserves in_interpolation state" do
        expect(descended.in_interpolation).to eq(root.in_interpolation)
      end

      it "increments depth" do
        expect(descended.depth).to eq(1)
      end

      it "can descend multiple levels" do
        deep = root.descend.descend.descend
        expect(deep.depth).to eq(3)
      end
    end
  end

  describe Smolagents::Security::Allowlists do
    describe "DANGEROUS_METHODS" do
      let(:methods) { described_class::DANGEROUS_METHODS }

      it "is a frozen Set" do
        expect(methods).to be_a(Set)
        expect(methods).to be_frozen
      end

      it "includes code execution methods" do
        expect(methods).to include("eval", "instance_eval", "class_eval", "module_eval")
      end

      it "includes shell execution methods" do
        expect(methods).to include("system", "exec", "spawn")
      end

      it "includes process control methods" do
        expect(methods).to include("fork", "exit", "exit!", "abort")
      end

      it "includes file I/O methods" do
        expect(methods).to include("open", "File", "IO", "Dir")
      end

      it "includes require methods" do
        expect(methods).to include("require", "require_relative", "load", "autoload")
      end

      it "includes metaprogramming methods" do
        expect(methods).to include("send", "__send__", "public_send", "method", "define_method")
      end

      it "includes constant manipulation methods" do
        expect(methods).to include("const_get", "const_set", "remove_const")
      end

      it "includes variable manipulation methods" do
        expect(methods).to include("instance_variable_get", "instance_variable_set", "class_variable_get")
      end

      it "includes dangerous objects" do
        expect(methods).to include("ObjectSpace", "Marshal", "Kernel", "binding")
      end

      it "includes signal handling" do
        expect(methods).to include("trap", "at_exit")
      end
    end

    describe "DANGEROUS_CONSTANTS" do
      let(:constants) { described_class::DANGEROUS_CONSTANTS }

      it "is a frozen Set" do
        expect(constants).to be_a(Set)
        expect(constants).to be_frozen
      end

      it "includes file system constants" do
        expect(constants).to include("File", "IO", "Dir", "FileUtils", "Pathname")
      end

      it "includes process control constants" do
        expect(constants).to include("Process", "Thread", "Signal")
      end

      it "includes networking constants" do
        expect(constants).to include("Socket", "TCPSocket", "UDPSocket", "BasicSocket")
      end

      it "includes environment access constants" do
        expect(constants).to include("ENV", "ARGV", "ARGF")
      end

      it "includes introspection constants" do
        expect(constants).to include("ObjectSpace", "Marshal", "Kernel")
      end

      it "includes platform constants" do
        expect(constants).to include("RUBY_PLATFORM", "RUBY_VERSION", "DATA")
      end
    end

    describe "DANGEROUS_PATTERNS" do
      let(:patterns) { described_class::DANGEROUS_PATTERNS }

      it "is a frozen Array" do
        expect(patterns).to be_an(Array)
        expect(patterns).to be_frozen
      end

      it "matches backtick execution" do
        expect(patterns.any? { |p| "`ls`" =~ p }).to be true
      end

      it "matches %x[] execution" do
        expect(patterns.any? { |p| "%x[ls]" =~ p }).to be true
      end

      it "matches %x{} execution" do
        expect(patterns.any? { |p| "%x{ls}" =~ p }).to be true
      end

      it "matches %x() execution" do
        expect(patterns.any? { |p| "%x(ls)" =~ p }).to be true
      end
    end

    describe "DANGEROUS_IMPORTS" do
      let(:imports) { described_class::DANGEROUS_IMPORTS }

      it "is a frozen Array" do
        expect(imports).to be_an(Array)
        expect(imports).to be_frozen
      end

      it "includes networking imports" do
        expect(imports).to include("net/http", "open-uri", "socket")
      end

      it "includes file utilities" do
        expect(imports).to include("FileUtils")
      end
    end

    describe "MAX_AST_DEPTH" do
      it "is set to 100" do
        expect(described_class::MAX_AST_DEPTH).to eq(100)
      end
    end
  end

  describe Smolagents::Security::CodeValidator do
    describe ".validate" do
      context "with safe code" do
        it "validates simple expressions" do
          result = described_class.validate("1 + 2")
          expect(result.valid?).to be true
        end

        it "validates method calls on objects" do
          result = described_class.validate("[1, 2, 3].map { |x| x * 2 }")
          expect(result.valid?).to be true
        end

        it "validates string operations" do
          result = described_class.validate('"hello".upcase')
          expect(result.valid?).to be true
        end

        it "validates array operations" do
          result = described_class.validate("arr = [1, 2, 3]; arr.each { |i| puts i }")
          expect(result.valid?).to be true
        end

        it "validates hash operations" do
          result = described_class.validate("{ a: 1, b: 2 }.keys")
          expect(result.valid?).to be true
        end

        it "validates class definitions" do
          code = <<~RUBY
            class MyClass
              def hello
                "world"
              end
            end
          RUBY
          result = described_class.validate(code)
          expect(result.valid?).to be true
        end

        it "validates lambdas and procs" do
          result = described_class.validate("-> (x) { x * 2 }.call(5)")
          expect(result.valid?).to be true
        end

        it "validates multi-line code" do
          code = <<~RUBY
            x = 10
            y = 20
            x + y
          RUBY
          result = described_class.validate(code)
          expect(result.valid?).to be true
        end
      end

      context "with dangerous methods" do
        it "rejects eval" do
          result = described_class.validate('eval("puts 1")')
          expect(result.valid?).to be false
          expect(result.violations.first.type).to eq(:dangerous_method)
          expect(result.violations.first.detail).to eq("eval")
        end

        it "rejects instance_eval" do
          result = described_class.validate('obj.instance_eval("@secret")')
          expect(result.valid?).to be false
          expect(result.violations.first.detail).to eq("instance_eval")
        end

        it "rejects class_eval" do
          result = described_class.validate("String.class_eval { define_method(:x) {} }")
          expect(result.valid?).to be false
        end

        it "rejects system calls" do
          result = described_class.validate('system("ls")')
          expect(result.valid?).to be false
          expect(result.violations.first.detail).to eq("system")
        end

        it "rejects exec" do
          result = described_class.validate('exec("/bin/sh")')
          expect(result.valid?).to be false
          expect(result.violations.first.detail).to eq("exec")
        end

        it "rejects spawn" do
          result = described_class.validate('spawn("sleep 10")')
          expect(result.valid?).to be false
          expect(result.violations.first.detail).to eq("spawn")
        end

        it "rejects fork" do
          result = described_class.validate("fork { sleep }")
          expect(result.valid?).to be false
        end

        it "rejects require" do
          result = described_class.validate('require "tempfile"')
          expect(result.valid?).to be false
        end

        it "rejects load" do
          result = described_class.validate('load "./script.rb"')
          expect(result.valid?).to be false
        end

        it "rejects send" do
          result = described_class.validate("obj.send(:dangerous)")
          expect(result.valid?).to be false
        end

        it "rejects __send__" do
          result = described_class.validate("obj.__send__(:private)")
          expect(result.valid?).to be false
        end

        it "rejects public_send" do
          result = described_class.validate("obj.public_send(:method)")
          expect(result.valid?).to be false
        end

        it "rejects const_get" do
          result = described_class.validate('Object.const_get("File")')
          expect(result.valid?).to be false
        end

        it "rejects exit" do
          result = described_class.validate("exit(1)")
          expect(result.valid?).to be false
        end

        it "rejects abort" do
          result = described_class.validate('abort("fatal")')
          expect(result.valid?).to be false
        end
      end

      context "with dangerous constants" do
        it "rejects File constant" do
          result = described_class.validate('File.read("/etc/passwd")')
          expect(result.valid?).to be false
          expect(result.violations.any? { |v| v.type == :dangerous_constant && v.detail == "File" }).to be true
        end

        it "rejects IO constant" do
          result = described_class.validate("IO.read(path)")
          expect(result.valid?).to be false
        end

        it "rejects Dir constant" do
          result = described_class.validate('Dir.glob("*")')
          expect(result.valid?).to be false
        end

        it "rejects Process constant" do
          result = described_class.validate("Process.kill(:TERM, pid)")
          expect(result.valid?).to be false
        end

        it "rejects ENV constant" do
          result = described_class.validate('ENV["SECRET"]')
          expect(result.valid?).to be false
        end

        it "rejects ObjectSpace constant" do
          result = described_class.validate("ObjectSpace.each_object")
          expect(result.valid?).to be false
        end

        it "rejects Socket constant" do
          result = described_class.validate("Socket.new(:INET, :STREAM)")
          expect(result.valid?).to be false
        end

        it "rejects TCPSocket constant" do
          result = described_class.validate('TCPSocket.new("host", 80)')
          expect(result.valid?).to be false
        end

        it "rejects Marshal constant" do
          result = described_class.validate("Marshal.load(data)")
          expect(result.valid?).to be false
        end
      end

      context "with backtick execution" do
        it "rejects single backticks" do
          result = described_class.validate("`ls`")
          expect(result.valid?).to be false
          expect(result.violations.any? { |v| v.type == :backtick_execution }).to be true
        end

        it "rejects backticks in expressions" do
          result = described_class.validate("result = `cat /etc/passwd`")
          expect(result.valid?).to be false
        end

        it "rejects %x[] command execution" do
          result = described_class.validate("%x[whoami]")
          expect(result.valid?).to be false
          expect(result.violations.any? { |v| v.type == :dangerous_pattern }).to be true
        end

        it "rejects %x{} command execution" do
          result = described_class.validate("%x{id}")
          expect(result.valid?).to be false
        end

        it "rejects %x() command execution" do
          result = described_class.validate("%x(uname)")
          expect(result.valid?).to be false
        end
      end

      context "with dangerous imports" do
        it "rejects net/http require" do
          result = described_class.validate('require "net/http"')
          expect(result.valid?).to be false
          expect(result.violations.any? { |v| v.type == :dangerous_import }).to be true
        end

        it "rejects open-uri require" do
          result = described_class.validate('require "open-uri"')
          expect(result.valid?).to be false
        end

        it "rejects socket require" do
          result = described_class.validate('require "socket"')
          expect(result.valid?).to be false
        end

        it "rejects FileUtils require" do
          result = described_class.validate('require "FileUtils"')
          expect(result.valid?).to be false
        end
      end

      context "with syntax errors" do
        it "rejects malformed code" do
          result = described_class.validate("def foo(")
          expect(result.valid?).to be false
          expect(result.violations.any? { |v| v.type == :syntax_error }).to be true
        end

        it "rejects unclosed strings" do
          result = described_class.validate('"hello')
          expect(result.valid?).to be false
        end

        it "rejects unmatched brackets" do
          result = described_class.validate("[1, 2, 3")
          expect(result.valid?).to be false
        end
      end

      context "with dangerous code in string interpolation" do
        it "detects eval in interpolation" do
          result = described_class.validate('"result: #{eval("1+1")}"')
          expect(result.valid?).to be false
          expect(result.violations.any?(&:in_interpolation?)).to be true
        end

        it "detects system in interpolation" do
          result = described_class.validate('"output: #{system("ls")}"')
          expect(result.valid?).to be false
        end

        it "detects File access in interpolation" do
          result = described_class.validate('"data: #{File.read("/etc/passwd")}"')
          expect(result.valid?).to be false
        end
      end

      context "with nested dangerous code" do
        it "detects dangerous code inside blocks" do
          result = described_class.validate('[1].map { system("ls") }')
          expect(result.valid?).to be false
        end

        it "detects dangerous code inside lambdas" do
          result = described_class.validate('-> { eval("code") }')
          expect(result.valid?).to be false
        end

        it "detects dangerous code in conditionals" do
          result = described_class.validate('if true; system("ls"); end')
          expect(result.valid?).to be false
        end

        it "detects dangerous code in case statements" do
          result = described_class.validate("case x; when 1 then File.read(path); end")
          expect(result.valid?).to be false
        end
      end

      context "with multiple violations" do
        it "collects all violations" do
          code = 'system("ls"); File.read("/etc/passwd"); `whoami`'
          result = described_class.validate(code)
          expect(result.valid?).to be false
          expect(result.violations.size).to be >= 2
        end
      end

      context "with edge cases" do
        it "handles empty string" do
          result = described_class.validate("")
          expect(result.valid?).to be true
        end

        it "handles whitespace only" do
          result = described_class.validate("   \n\t  ")
          expect(result.valid?).to be true
        end

        it "handles comments only" do
          result = described_class.validate("# just a comment")
          expect(result.valid?).to be true
        end
      end
    end

    describe ".validate!" do
      it "returns result for valid code" do
        result = described_class.validate!("1 + 1")
        expect(result).to be_a(Smolagents::Security::ValidationResult)
        expect(result.valid?).to be true
      end

      it "raises InterpreterError for invalid code" do
        expect do
          described_class.validate!('system("ls")')
        end.to raise_error(Smolagents::InterpreterError)
      end

      it "includes violation details in error message" do
        expect do
          described_class.validate!('eval("code")')
        end.to raise_error(Smolagents::InterpreterError, /Dangerous method call: eval/)
      end
    end
  end

  describe Smolagents::Security::AstHelpers do
    describe ".extract_method_name" do
      it "extracts method name from command node" do
        sexp = [:command, [:@ident, "puts", [1, 0]], [:args_add_block, [], false]]
        expect(described_class.extract_method_name(sexp)).to eq("puts")
      end

      it "returns nil for nodes without identifiers" do
        sexp = [:program, []]
        expect(described_class.extract_method_name(sexp)).to be_nil
      end
    end

    describe ".extract_const_path" do
      it "extracts simple constant name" do
        sexp = [:@const, "File", [1, 0]]
        # Simple constant is extracted but nil is returned for non-const_path_ref
        expect(described_class.extract_const_path(sexp)).to eq("File")
      end
    end
  end
end
