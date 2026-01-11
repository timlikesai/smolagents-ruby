RSpec.describe Smolagents::PythonValidator do
  let(:validator) { described_class.new }

  describe "#validate!" do
    it "validates safe Python code" do
      expect do
        validator.validate!("print('hello')")
      end.not_to raise_error
    end

    it "validates arithmetic" do
      expect do
        validator.validate!("x = 2 + 2")
      end.not_to raise_error
    end

    it "validates function definitions" do
      expect do
        validator.validate!("def foo():\n    return 'bar'")
      end.not_to raise_error
    end

    it "rejects eval" do
      expect do
        validator.validate!("eval('print(1)')")
      end.to raise_error(Smolagents::InterpreterError, /eval/)
    end

    it "rejects exec" do
      expect do
        validator.validate!("exec('import os')")
      end.to raise_error(Smolagents::InterpreterError, /exec/)
    end

    it "rejects compile" do
      expect do
        validator.validate!("compile('code', 'file', 'exec')")
      end.to raise_error(Smolagents::InterpreterError, /compile/)
    end

    it "rejects __import__" do
      expect do
        validator.validate!("__import__('os')")
      end.to raise_error(Smolagents::InterpreterError, /__import__/)
    end

    it "rejects os module access" do
      expect do
        validator.validate!("os.system('ls')")
      end.to raise_error(Smolagents::InterpreterError, /os\./)
    end

    it "rejects sys module access" do
      expect do
        validator.validate!("sys.exit()")
      end.to raise_error(Smolagents::InterpreterError, /sys\./)
    end

    it "rejects subprocess module access" do
      expect do
        validator.validate!("subprocess.run(['ls'])")
      end.to raise_error(Smolagents::InterpreterError, /subprocess\./)
    end

    it "rejects socket module access" do
      expect do
        validator.validate!("socket.socket()")
      end.to raise_error(Smolagents::InterpreterError, /socket\./)
    end

    it "rejects pickle module access" do
      expect do
        validator.validate!("pickle.loads(data)")
      end.to raise_error(Smolagents::InterpreterError, /pickle\./)
    end

    it "rejects __class__ access" do
      expect do
        validator.validate!("obj.__class__")
      end.to raise_error(Smolagents::InterpreterError, /__class__/)
    end

    it "rejects __globals__ access" do
      expect do
        validator.validate!("func.__globals__")
      end.to raise_error(Smolagents::InterpreterError, /__globals__/)
    end

    it "rejects os import" do
      expect do
        validator.validate!("import os")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous import: os/)
    end

    it "rejects subprocess import" do
      expect do
        validator.validate!("import subprocess")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous import: subprocess/)
    end

    it "rejects from os import" do
      expect do
        validator.validate!("from os import system")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous import: os/)
    end

    it "rejects ctypes import" do
      expect do
        validator.validate!("import ctypes")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous import: ctypes/)
    end
  end

  describe "#validate" do
    it "returns ValidationResult for safe code" do
      result = validator.validate("print('safe')")
      expect(result).to be_a(Smolagents::Validator::ValidationResult)
      expect(result.valid?).to be true
    end

    it "returns ValidationResult with errors for dangerous code" do
      result = validator.validate("os.system('bad')")
      expect(result.valid?).to be false
      expect(result.errors).not_to be_empty
    end
  end
end
