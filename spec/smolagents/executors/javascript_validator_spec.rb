# frozen_string_literal: true

RSpec.describe Smolagents::JavaScriptValidator do
  let(:validator) { described_class.new }

  describe "#validate!" do
    it "validates safe JavaScript code" do
      expect {
        validator.validate!("console.log('hello')")
      }.not_to raise_error
    end

    it "validates arithmetic" do
      expect {
        validator.validate!("const x = 2 + 2")
      }.not_to raise_error
    end

    it "validates function definitions" do
      expect {
        validator.validate!("function foo() { return 'bar'; }")
      }.not_to raise_error
    end

    it "rejects eval" do
      expect {
        validator.validate!("eval('alert(1)')")
      }.to raise_error(Smolagents::InterpreterError, /eval/)
    end

    it "rejects Function constructor" do
      expect {
        validator.validate!("new Function('return 1')()")
      }.to raise_error(Smolagents::InterpreterError, /Function/)
    end

    it "rejects process access" do
      expect {
        validator.validate!("process.exit()")
      }.to raise_error(Smolagents::InterpreterError, /process\./)
    end

    it "rejects global access" do
      expect {
        validator.validate!("global.something")
      }.to raise_error(Smolagents::InterpreterError, /global\./)
    end

    it "rejects child_process require" do
      expect {
        validator.validate!("const cp = require('child_process')")
      }.to raise_error(Smolagents::InterpreterError, /child_process/)
    end

    it "rejects fs require" do
      expect {
        validator.validate!("require('fs')")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous import: fs/)
    end

    it "rejects net require" do
      expect {
        validator.validate!("const net = require('net')")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous import: net/)
    end

    it "rejects http require" do
      expect {
        validator.validate!("require('http')")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous import: http/)
    end

    it "rejects vm require" do
      expect {
        validator.validate!("require('vm')")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous import: vm/)
    end

    it "rejects child_process ES6 import" do
      expect {
        validator.validate!("import { exec } from 'child_process'")
      }.to raise_error(Smolagents::InterpreterError, /child_process/)
    end

    it "rejects fs ES6 import" do
      expect {
        validator.validate!("import fs from 'fs'")
      }.to raise_error(Smolagents::InterpreterError, /Dangerous import: fs/)
    end

    it "rejects __proto__ access" do
      expect {
        validator.validate!("obj.__proto__")
      }.to raise_error(Smolagents::InterpreterError, /__proto__/)
    end

    it "rejects constructor prototype manipulation" do
      expect {
        validator.validate!("obj.constructor.prototype")
      }.to raise_error(Smolagents::InterpreterError, /constructor\.prototype/)
    end

    it "rejects __dirname access" do
      expect {
        validator.validate!("console.log(__dirname)")
      }.to raise_error(Smolagents::InterpreterError, /__dirname/)
    end

    it "rejects __filename access" do
      expect {
        validator.validate!("console.log(__filename)")
      }.to raise_error(Smolagents::InterpreterError, /__filename/)
    end

    it "rejects fetch" do
      expect {
        validator.validate!("fetch('http://evil.com')")
      }.to raise_error(Smolagents::InterpreterError, /fetch/)
    end

    it "rejects XMLHttpRequest" do
      expect {
        validator.validate!("new XMLHttpRequest()")
      }.to raise_error(Smolagents::InterpreterError, /XMLHttpRequest/)
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
