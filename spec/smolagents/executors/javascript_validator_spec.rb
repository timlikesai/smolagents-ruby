RSpec.describe Smolagents::JavaScriptValidator do
  let(:validator) { described_class.new }

  describe "#validate!" do
    it "validates safe JavaScript code" do
      expect do
        validator.validate!("console.log('hello')")
      end.not_to raise_error
    end

    it "validates arithmetic" do
      expect do
        validator.validate!("const x = 2 + 2")
      end.not_to raise_error
    end

    it "validates function definitions" do
      expect do
        validator.validate!("function foo() { return 'bar'; }")
      end.not_to raise_error
    end

    it "rejects eval" do
      expect do
        validator.validate!("eval('alert(1)')")
      end.to raise_error(Smolagents::InterpreterError, /eval/)
    end

    it "rejects Function constructor" do
      expect do
        validator.validate!("new Function('return 1')()")
      end.to raise_error(Smolagents::InterpreterError, /Function/)
    end

    it "rejects process access" do
      expect do
        validator.validate!("process.exit()")
      end.to raise_error(Smolagents::InterpreterError, /process\./)
    end

    it "rejects global access" do
      expect do
        validator.validate!("global.something")
      end.to raise_error(Smolagents::InterpreterError, /global\./)
    end

    it "rejects child_process require" do
      expect do
        validator.validate!("const cp = require('child_process')")
      end.to raise_error(Smolagents::InterpreterError, /child_process/)
    end

    it "rejects fs require" do
      expect do
        validator.validate!("require('fs')")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous import: fs/)
    end

    it "rejects net require" do
      expect do
        validator.validate!("const net = require('net')")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous import: net/)
    end

    it "rejects http require" do
      expect do
        validator.validate!("require('http')")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous import: http/)
    end

    it "rejects vm require" do
      expect do
        validator.validate!("require('vm')")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous import: vm/)
    end

    it "rejects child_process ES6 import" do
      expect do
        validator.validate!("import { exec } from 'child_process'")
      end.to raise_error(Smolagents::InterpreterError, /child_process/)
    end

    it "rejects fs ES6 import" do
      expect do
        validator.validate!("import fs from 'fs'")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous import: fs/)
    end

    it "rejects __proto__ access" do
      expect do
        validator.validate!("obj.__proto__")
      end.to raise_error(Smolagents::InterpreterError, /__proto__/)
    end

    it "rejects constructor prototype manipulation" do
      expect do
        validator.validate!("obj.constructor.prototype")
      end.to raise_error(Smolagents::InterpreterError, /constructor\.prototype/)
    end

    it "rejects __dirname access" do
      expect do
        validator.validate!("console.log(__dirname)")
      end.to raise_error(Smolagents::InterpreterError, /__dirname/)
    end

    it "rejects __filename access" do
      expect do
        validator.validate!("console.log(__filename)")
      end.to raise_error(Smolagents::InterpreterError, /__filename/)
    end

    it "rejects fetch" do
      expect do
        validator.validate!("fetch('http://evil.com')")
      end.to raise_error(Smolagents::InterpreterError, /fetch/)
    end

    it "rejects XMLHttpRequest" do
      expect do
        validator.validate!("new XMLHttpRequest()")
      end.to raise_error(Smolagents::InterpreterError, /XMLHttpRequest/)
    end
  end

  describe "#validate" do
    it "returns ValidationResult for safe code" do
      result = validator.validate("console.log('safe')")
      expect(result).to be_a(Smolagents::Validator::ValidationResult)
      expect(result.valid?).to be true
    end

    it "returns ValidationResult with errors for dangerous code" do
      result = validator.validate("require('child_process')")
      expect(result.valid?).to be false
      expect(result.errors).not_to be_empty
    end
  end
end
