RSpec.describe Smolagents::Validator do
  describe "ValidationResult" do
    it "creates valid result by default" do
      result = described_class::ValidationResult.new
      expect(result.valid?).to be true
      expect(result.invalid?).to be false
      expect(result.errors).to be_empty
      expect(result.warnings).to be_empty
      expect(result.has_warnings?).to be false
    end

    it "creates invalid result with errors" do
      result = described_class::ValidationResult.new(valid: false, errors: ["error"])
      expect(result.valid?).to be false
      expect(result.invalid?).to be true
      expect(result.errors).to eq(["error"])
    end

    it "tracks warnings" do
      result = described_class::ValidationResult.new(warnings: ["warning"])
      expect(result.has_warnings?).to be true
      expect(result.warnings).to eq(["warning"])
    end
  end

  # Concrete validator for testing
  class TestValidator < Smolagents::Validator
    def dangerous_patterns
      [/dangerous/, "bad"]
    end

    def dangerous_imports
      ["evil"]
    end

    def check_import(code, import)
      code.include?("import #{import}")
    end
  end

  describe "#validate" do
    let(:validator) { TestValidator.new }

    it "validates safe code" do
      result = validator.validate("safe code")
      expect(result.valid?).to be true
      expect(result.errors).to be_empty
    end

    it "detects dangerous regex patterns" do
      result = validator.validate("this is dangerous code")
      expect(result.invalid?).to be true
      expect(result.errors).to include(match(/Dangerous pattern/))
    end

    it "detects dangerous keywords" do
      result = validator.validate("bad things happen")
      expect(result.invalid?).to be true
      expect(result.errors).to include(match(/Dangerous keyword: bad/))
    end

    it "detects dangerous imports" do
      result = validator.validate("import evil stuff")
      expect(result.invalid?).to be true
      expect(result.errors).to include(match(/Dangerous import: evil/))
    end

    it "accumulates multiple errors" do
      result = validator.validate("dangerous bad import evil")
      expect(result.invalid?).to be true
      expect(result.errors.size).to be >= 2
    end
  end

  describe "#validate!" do
    let(:validator) { TestValidator.new }

    it "raises InterpreterError for dangerous code" do
      expect do
        validator.validate!("dangerous code")
      end.to raise_error(Smolagents::InterpreterError, /Dangerous pattern/)
    end

    it "does not raise for safe code" do
      expect do
        validator.validate!("safe code")
      end.not_to raise_error
    end
  end
end
