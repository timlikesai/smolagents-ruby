# frozen_string_literal: true

RSpec.describe Smolagents::RubyValidator do
  let(:validator) { described_class.new }

  describe "#validate!" do
    it "validates safe Ruby code" do
      expect do
        validator.validate!("puts 'hello'")
      end.not_to raise_error
    end

    it "validates arithmetic" do
      expect do
        validator.validate!("x = 2 + 2")
      end.not_to raise_error
    end

    it "validates method definitions" do
      expect do
        validator.validate!("def foo\n  'bar'\nend")
      end.not_to raise_error
    end

    it "validates class definitions" do
      expect do
        validator.validate!("class Foo\n  def bar\n    42\n  end\nend")
      end.not_to raise_error
    end

    it "rejects eval" do
      expect do
        validator.validate!("eval('puts 1')")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous method call: eval/)
    end

    it "rejects instance_eval" do
      expect do
        validator.validate!("self.instance_eval { puts 'bad' }")
      end.to raise_error(Smolagents::InterpreterError, /instance_eval/)
    end

    it "rejects system calls" do
      expect do
        validator.validate!("system('ls')")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous method call: system/)
    end

    it "rejects exec" do
      expect do
        validator.validate!("exec('rm -rf /')")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous method call: exec/)
    end

    it "rejects spawn" do
      expect do
        validator.validate!("spawn('cat /etc/passwd')")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous method call: spawn/)
    end

    it "rejects fork" do
      expect do
        validator.validate!("fork { puts 'child' }")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous method call: fork/)
    end

    it "rejects require" do
      expect do
        validator.validate!("require 'evil'")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous method call: require/)
    end

    it "rejects require_relative" do
      expect do
        validator.validate!("require_relative '../config'")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous method call: require_relative/)
    end

    it "rejects load" do
      expect do
        validator.validate!("load 'file.rb'")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous method call: load/)
    end

    it "rejects open" do
      expect do
        validator.validate!("open('file.txt')")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous method call: open/)
    end

    it "rejects File constant" do
      expect do
        validator.validate!("File.read('/etc/passwd')")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: File/)
    end

    it "rejects IO constant" do
      expect do
        validator.validate!("IO.read('file')")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: IO/)
    end

    it "rejects Dir constant" do
      expect do
        validator.validate!("Dir.glob('*')")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: Dir/)
    end

    it "rejects send" do
      expect do
        validator.validate!("obj.send(:private_method)")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous method call: send/)
    end

    it "rejects __send__" do
      expect do
        validator.validate!("obj.__send__(:method)")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous method call: __send__/)
    end

    it "rejects const_get" do
      expect do
        validator.validate!("Object.const_get(:File)")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous method call: const_get/)
    end

    it "rejects binding" do
      expect do
        validator.validate!("b = binding")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous method call: binding/)
    end

    it "rejects ObjectSpace constant" do
      expect do
        validator.validate!("ObjectSpace.each_object {}")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: ObjectSpace/)
    end

    it "rejects Marshal constant" do
      expect do
        validator.validate!("Marshal.dump(obj)")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: Marshal/)
    end

    it "rejects backtick execution" do
      expect do
        validator.validate!("`ls -la`")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous pattern/)
    end

    it "rejects %x[] execution" do
      expect do
        validator.validate!("%x[ls]")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous pattern/)
    end

    it "rejects syntax errors" do
      expect do
        validator.validate!("def broken")
      end.to raise_error(Smolagents::InterpreterError, /syntax errors/)
    end
  end

  describe "#validate" do
    it "returns ValidationResult for safe code" do
      result = validator.validate("puts 'safe'")
      expect(result).to be_a(Smolagents::Validator::ValidationResult)
      expect(result.valid?).to be true
    end

    it "returns ValidationResult with errors for dangerous code" do
      result = validator.validate("system('bad')")
      expect(result.valid?).to be false
      expect(result.errors).not_to be_empty
    end
  end
end
