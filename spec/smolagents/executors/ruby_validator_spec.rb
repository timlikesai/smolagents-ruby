# frozen_string_literal: true

RSpec.describe Smolagents::RubyValidator do
  let(:validator) { described_class.new }

  describe "#validate!" do
    it "validates safe Ruby code" do
      expect {
        validator.validate!("puts 'hello'")
      }.not_to raise_error
    end

    it "validates arithmetic" do
      expect {
        validator.validate!("x = 2 + 2")
      }.not_to raise_error
    end

    it "validates method definitions" do
      expect {
        validator.validate!("def foo\n  'bar'\nend")
      }.not_to raise_error
    end

    it "validates class definitions" do
      expect {
        validator.validate!("class Foo\n  def bar\n    42\n  end\nend")
      }.not_to raise_error
    end

    it "rejects eval" do
      expect {
        validator.validate!("eval('puts 1')")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: eval/)
    end

    it "rejects instance_eval" do
      expect {
        validator.validate!("self.instance_eval { puts 'bad' }")
      }.to raise_error(Smolagents::InterpreterError, /instance_eval/)
    end

    it "rejects system calls" do
      expect {
        validator.validate!("system('ls')")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: system/)
    end

    it "rejects exec" do
      expect {
        validator.validate!("exec('rm -rf /')")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: exec/)
    end

    it "rejects spawn" do
      expect {
        validator.validate!("spawn('cat /etc/passwd')")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: spawn/)
    end

    it "rejects fork" do
      expect {
        validator.validate!("fork { puts 'child' }")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: fork/)
    end

    it "rejects require" do
      expect {
        validator.validate!("require 'evil'")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: require/)
    end

    it "rejects require_relative" do
      expect {
        validator.validate!("require_relative '../config'")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: require_relative/)
    end

    it "rejects load" do
      expect {
        validator.validate!("load 'file.rb'")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: load/)
    end

    it "rejects open" do
      expect {
        validator.validate!("open('file.txt')")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: open/)
    end

    it "rejects File constant" do
      expect {
        validator.validate!("File.read('/etc/passwd')")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: File/)
    end

    it "rejects IO constant" do
      expect {
        validator.validate!("IO.read('file')")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: IO/)
    end

    it "rejects Dir constant" do
      expect {
        validator.validate!("Dir.glob('*')")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: Dir/)
    end

    it "rejects send" do
      expect {
        validator.validate!("obj.send(:private_method)")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: send/)
    end

    it "rejects __send__" do
      expect {
        validator.validate!("obj.__send__(:method)")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: __send__/)
    end

    it "rejects const_get" do
      expect {
        validator.validate!("Object.const_get(:File)")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: const_get/)
    end

    it "rejects binding" do
      expect {
        validator.validate!("b = binding")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous method call: binding/)
    end

    it "rejects ObjectSpace constant" do
      expect {
        validator.validate!("ObjectSpace.each_object {}")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: ObjectSpace/)
    end

    it "rejects Marshal constant" do
      expect {
        validator.validate!("Marshal.dump(obj)")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous constant access: Marshal/)
    end

    it "rejects backtick execution" do
      expect {
        validator.validate!("`ls -la`")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous pattern/)
    end

    it "rejects %x[] execution" do
      expect {
        validator.validate!("%x[ls]")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous pattern/)
    end

    it "rejects syntax errors" do
      expect {
        validator.validate!("def broken")
      }.to raise_error(Smolagents::InterpreterError, /syntax errors/)
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
