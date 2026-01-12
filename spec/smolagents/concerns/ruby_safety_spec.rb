RSpec.describe Smolagents::Concerns::RubySafety do
  let(:validator) do
    Class.new do
      include Smolagents::Concerns::RubySafety

      public :validate_ruby_code!
    end.new
  end

  describe "#validate_ruby_code!" do
    context "with safe code" do
      it "allows puts" do
        expect { validator.validate_ruby_code!("puts 'hello'") }.not_to raise_error
      end

      it "allows arithmetic" do
        expect { validator.validate_ruby_code!("x = 2 + 2") }.not_to raise_error
      end

      it "allows method definitions" do
        expect { validator.validate_ruby_code!("def foo\n  'bar'\nend") }.not_to raise_error
      end

      it "allows class definitions" do
        expect { validator.validate_ruby_code!("class Foo\n  def bar\n    42\n  end\nend") }.not_to raise_error
      end

      it "allows symbols with dangerous names" do
        expect { validator.validate_ruby_code!(":File") }.not_to raise_error
        expect { validator.validate_ruby_code!("Object.const_get(:File)") }.to raise_error(Smolagents::InterpreterError, /const_get/)
      end
    end

    context "with dangerous method calls" do
      it "rejects eval" do
        expect { validator.validate_ruby_code!("eval('puts 1')") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: eval/)
      end

      it "rejects instance_eval" do
        expect { validator.validate_ruby_code!("self.instance_eval { puts 'bad' }") }.to raise_error(Smolagents::InterpreterError, /instance_eval/)
      end

      it "rejects system" do
        expect { validator.validate_ruby_code!("system('ls')") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: system/)
      end

      it "rejects exec" do
        expect { validator.validate_ruby_code!("exec('rm -rf /')") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: exec/)
      end

      it "rejects spawn" do
        expect { validator.validate_ruby_code!("spawn('cat /etc/passwd')") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: spawn/)
      end

      it "rejects fork" do
        expect { validator.validate_ruby_code!("fork { puts 'child' }") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: fork/)
      end

      it "rejects require" do
        expect { validator.validate_ruby_code!("require 'evil'") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: require/)
      end

      it "rejects require_relative" do
        expect { validator.validate_ruby_code!("require_relative '../config'") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: require_relative/)
      end

      it "rejects load" do
        expect { validator.validate_ruby_code!("load 'file.rb'") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: load/)
      end

      it "rejects open" do
        expect { validator.validate_ruby_code!("open('file.txt')") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: open/)
      end

      it "rejects send" do
        expect { validator.validate_ruby_code!("obj.send(:private_method)") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: send/)
      end

      it "rejects __send__" do
        expect { validator.validate_ruby_code!("obj.__send__(:method)") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: __send__/)
      end

      it "rejects const_get" do
        expect { validator.validate_ruby_code!("Object.const_get(:File)") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: const_get/)
      end

      it "rejects binding" do
        expect { validator.validate_ruby_code!("b = binding") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: binding/)
      end

      it "rejects exit" do
        expect { validator.validate_ruby_code!("exit(1)") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: exit/)
      end

      it "rejects exit!" do
        expect { validator.validate_ruby_code!("exit!(1)") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: exit!/)
      end

      it "rejects abort" do
        expect { validator.validate_ruby_code!("abort('error')") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: abort/)
      end

      it "rejects trap" do
        expect { validator.validate_ruby_code!("trap('INT') { }") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: trap/)
      end

      it "rejects at_exit" do
        expect { validator.validate_ruby_code!("at_exit { puts 'bye' }") }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: at_exit/)
      end
    end

    context "with dangerous constants" do
      it "rejects File" do
        expect { validator.validate_ruby_code!("File.read('/etc/passwd')") }.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: File/)
      end

      it "rejects IO" do
        expect { validator.validate_ruby_code!("IO.read('file')") }.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: IO/)
      end

      it "rejects Dir" do
        expect { validator.validate_ruby_code!("Dir.glob('*')") }.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: Dir/)
      end

      it "rejects ObjectSpace" do
        expect { validator.validate_ruby_code!("ObjectSpace.each_object {}") }.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: ObjectSpace/)
      end

      it "rejects Marshal" do
        expect { validator.validate_ruby_code!("Marshal.dump(obj)") }.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: Marshal/)
      end

      it "rejects Kernel" do
        expect { validator.validate_ruby_code!("Kernel.exit") }.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: Kernel/)
      end

      it "rejects ENV" do
        expect { validator.validate_ruby_code!("ENV['SECRET']") }.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: ENV/)
      end

      it "rejects Process" do
        expect { validator.validate_ruby_code!("Process.kill(9, pid)") }.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: Process/)
      end

      it "rejects Thread" do
        expect { validator.validate_ruby_code!("Thread.new { }") }.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: Thread/)
      end

      it "rejects Signal" do
        expect { validator.validate_ruby_code!("Signal.trap('INT') { }") }.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: Signal/)
      end
    end

    context "with dangerous patterns" do
      it "rejects backtick execution" do
        expect { validator.validate_ruby_code!("`ls -la`") }.to raise_error(Smolagents::InterpreterError, /Dangerous pattern/)
      end

      it "rejects %x[] execution" do
        expect { validator.validate_ruby_code!("%x[ls]") }.to raise_error(Smolagents::InterpreterError, /Dangerous pattern/)
      end

      it "rejects %x{} execution" do
        expect { validator.validate_ruby_code!("%x{ls}") }.to raise_error(Smolagents::InterpreterError, /Dangerous pattern/)
      end

      it "rejects %x() execution" do
        expect { validator.validate_ruby_code!("%x(ls)") }.to raise_error(Smolagents::InterpreterError, /Dangerous pattern/)
      end
    end

    context "with dangerous imports" do
      it "rejects net/http" do
        expect { validator.validate_ruby_code!("require 'net/http'") }.to raise_error(Smolagents::InterpreterError, %r{Dangerous import: net/http})
      end

      it "rejects open-uri" do
        expect { validator.validate_ruby_code!("require 'open-uri'") }.to raise_error(Smolagents::InterpreterError, /Dangerous import: open-uri/)
      end

      it "rejects socket" do
        expect { validator.validate_ruby_code!("require 'socket'") }.to raise_error(Smolagents::InterpreterError, /Dangerous import: socket/)
      end
    end

    context "with syntax errors" do
      it "rejects invalid syntax" do
        expect { validator.validate_ruby_code!("def broken") }.to raise_error(Smolagents::InterpreterError, /syntax errors/)
      end
    end

    context "with interpolation attacks" do
      # rubocop:disable Lint/InterpolationCheck
      it "rejects backtick execution in string interpolation" do
        code = '"#{`whoami`}"'
        expect { validator.validate_ruby_code!(code) }.to raise_error(Smolagents::InterpreterError, /Backtick.*interpolation/)
      end

      it "rejects system call in string interpolation" do
        code = '"result: #{system(\'ls\')}"'
        expect { validator.validate_ruby_code!(code) }.to raise_error(Smolagents::InterpreterError, /system.*interpolation/)
      end

      it "rejects eval in string interpolation" do
        code = '"#{eval(\'1+1\')}"'
        expect { validator.validate_ruby_code!(code) }.to raise_error(Smolagents::InterpreterError, /eval.*interpolation/)
      end

      it "rejects dangerous constant in string interpolation" do
        code = '"#{File.read(\'/etc/passwd\')}"'
        expect { validator.validate_ruby_code!(code) }.to raise_error(Smolagents::InterpreterError, /File.*interpolation/)
      end

      it "rejects exec in deeply nested interpolation" do
        code = '"outer #{exec(\'id\')}"'
        expect { validator.validate_ruby_code!(code) }.to raise_error(Smolagents::InterpreterError, /exec.*interpolation/)
      end

      it "allows safe string interpolation" do
        expect { validator.validate_ruby_code!('"Hello, #{name}!"') }.not_to raise_error
        expect { validator.validate_ruby_code!('"Result: #{1 + 2}"') }.not_to raise_error
        expect { validator.validate_ruby_code!('"Items: #{[1,2,3].join(\', \')}"') }.not_to raise_error
      end
      # rubocop:enable Lint/InterpolationCheck
    end
  end

  describe "ValidationResult" do
    let(:result_class) { Smolagents::Concerns::RubySafety::ValidationResult }

    it "creates success result" do
      result = result_class.success
      expect(result).to be_valid
      expect(result).not_to be_invalid
      expect(result.violations).to be_empty
    end

    it "creates failure result with violations" do
      violation = Smolagents::Concerns::RubySafety::ValidationViolation.dangerous_method("eval")
      result = result_class.failure(violations: [violation])

      expect(result).not_to be_valid
      expect(result).not_to be_valid
      expect(result.violations.size).to eq(1)
    end

    it "generates error message from violations" do
      violations = [
        Smolagents::Concerns::RubySafety::ValidationViolation.dangerous_method("eval"),
        Smolagents::Concerns::RubySafety::ValidationViolation.dangerous_constant("File")
      ]
      result = result_class.failure(violations:)

      message = result.to_error_message
      expect(message).to include("Code validation failed")
      expect(message).to include("Dangerous method call: eval")
      expect(message).to include("Dangerous constant access: File")
    end

    it "supports pattern matching" do
      result = result_class.success

      matched = case result
                in Smolagents::Concerns::RubySafety::ValidationResult[valid: true]
                  :success
                in Smolagents::Concerns::RubySafety::ValidationResult[valid: false, violations:]
                  :failure
                end

      expect(matched).to eq(:success)
    end
  end

  describe "ValidationViolation" do
    let(:violation_class) { Smolagents::Concerns::RubySafety::ValidationViolation }

    it "creates dangerous_method violation" do
      v = violation_class.dangerous_method("system")
      expect(v.type).to eq(:dangerous_method)
      expect(v.detail).to eq("system")
      expect(v.to_s).to eq("Dangerous method call: system")
    end

    it "creates dangerous_constant violation" do
      v = violation_class.dangerous_constant("File")
      expect(v.type).to eq(:dangerous_constant)
      expect(v.detail).to eq("File")
      expect(v.to_s).to eq("Dangerous constant access: File")
    end

    it "creates backtick_execution violation" do
      v = violation_class.backtick_execution
      expect(v.type).to eq(:backtick_execution)
      expect(v.to_s).to eq("Backtick command execution")
    end

    it "tracks interpolation context" do
      v = violation_class.dangerous_method("eval", context: :interpolation)
      expect(v).to be_in_interpolation
      expect(v.to_s).to eq("Dangerous method call: eval (in string interpolation)")
    end

    it "supports pattern matching" do
      v = violation_class.dangerous_method("system", context: :interpolation)

      matched = case v
                in Smolagents::Concerns::RubySafety::ValidationViolation[type: :dangerous_method, context: :interpolation]
                  :interp_method
                else
                  :other
                end

      expect(matched).to eq(:interp_method)
    end
  end

  describe "NodeContext" do
    let(:context_class) { Smolagents::Concerns::RubySafety::NodeContext }

    it "creates root context" do
      ctx = context_class.root
      expect(ctx.in_interpolation).to be false
      expect(ctx.depth).to eq(0)
      expect(ctx.context_type).to be_nil
    end

    it "tracks interpolation entry" do
      ctx = context_class.root.enter_interpolation
      expect(ctx.in_interpolation).to be true
      expect(ctx.depth).to eq(1)
      expect(ctx.context_type).to eq(:interpolation)
    end

    it "is immutable via with" do
      ctx1 = context_class.root
      ctx2 = ctx1.enter_interpolation

      expect(ctx1.in_interpolation).to be false
      expect(ctx2.in_interpolation).to be true
    end
  end

  describe "#validate_ruby_code (non-raising)" do
    it "returns ValidationResult.success for safe code" do
      result = validator.send(:validate_ruby_code, "x = 1 + 2")
      expect(result).to be_valid
      expect(result.violations).to be_empty
    end

    it "returns ValidationResult.failure for dangerous code" do
      result = validator.send(:validate_ruby_code, "system('ls')")
      expect(result).not_to be_valid
      expect(result.violations.first.type).to eq(:dangerous_method)
    end

    it "collects multiple violations" do
      result = validator.send(:validate_ruby_code, "system('ls'); eval('code'); File.read('x')")
      expect(result).not_to be_valid
      expect(result.violations.size).to be >= 3
    end
  end
end
