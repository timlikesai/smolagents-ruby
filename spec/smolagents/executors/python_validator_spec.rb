# frozen_string_literal: true

RSpec.describe Smolagents::PythonValidator do
  let(:validator) { described_class.new }

  describe "#validate!" do
    it "validates safe Python code" do
      expect {
        validator.validate!("print('hello')")
      }.not_to raise_error
    end

    it "validates arithmetic" do
      expect {
        validator.validate!("x = 2 + 2")
      }.not_to raise_error
    end

    it "validates function definitions" do
      expect {
        validator.validate!("def foo():\n    return 'bar'")
      }.not_to raise_error
    end

    it "rejects eval" do
      expect {
        validator.validate!("eval('print(1)')")
      }.to raise_error(Smolagents::InterpreterError, /eval/)
    end

    it "rejects exec" do
      expect {
        validator.validate!("exec('import os')")
      }.to raise_error(Smolagents::InterpreterError, /exec/)
    end

    it "rejects compile" do
      expect {
        validator.validate!("compile('code', 'file', 'exec')")
      }.to raise_error(Smolagents::InterpreterError, /compile/)
    end

    it "rejects __import__" do
      expect {
        validator.validate!("__import__('os')")
      }.to raise_error(Smolagents::InterpreterError, /__import__/)
    end

    it "rejects os module access" do
      expect {
        validator.validate!("os.system('ls')")
      }.to raise_error(Smolagents::InterpreterError, /os\./)
    end

    it "rejects sys module access" do
      expect {
        validator.validate!("sys.exit()")
      }.to raise_error(Smolagents::InterpreterError, /sys\./)
    end

    it "rejects subprocess module access" do
      expect {
        validator.validate!("subprocess.run(['ls'])")
      }.to raise_error(Smolagents::InterpreterError, /subprocess\./)
    end

    it "rejects socket module access" do
      expect {
        validator.validate!("socket.socket()")
      }.to raise_error(Smolagents::InterpreterError, /socket\./)
    end

    it "rejects pickle module access" do
      expect {
        validator.validate!("pickle.loads(data)")
      }.to raise_error(Smolagents::InterpreterError, /pickle\./)
    end

    it "rejects __class__ access" do
      expect {
        validator.validate!("obj.__class__")
      }.to raise_error(Smolagents::InterpreterError, /__class__/)
    end

    it "rejects __globals__ access" do
      expect {
        validator.validate!("func.__globals__")
      }.to raise_error(Smolagents::InterpreterError, /__globals__/)
    end

    it "rejects os import" do
      expect {
        validator.validate!("import os")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous import: os/)
    end

    it "rejects subprocess import" do
      expect {
        validator.validate!("import subprocess")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous import: subprocess/)
    end

    it "rejects from os import" do
      expect {
        validator.validate!("from os import system")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous import: os/)
    end

    it "rejects ctypes import" do
      expect {
        validator.validate!("import ctypes")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous import: ctypes/)
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
