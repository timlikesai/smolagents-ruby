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
        expect { validator.validate_ruby_code!("require 'net/http'") }.to raise_error(Smolagents::InterpreterError, /Dangerous import: net\/http/)
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
  end
end
