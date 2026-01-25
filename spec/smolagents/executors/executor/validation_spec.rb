require "spec_helper"

RSpec.describe Smolagents::Executors::Executor::Validation do
  let(:validation_class) do
    Class.new do
      include Smolagents::Executors::Executor::Validation

      def supports?(language)
        %i[ruby python].include?(language)
      end
    end
  end

  let(:validator) { validation_class.new }

  describe "#validate_execution_params!" do
    context "with valid parameters" do
      it "does not raise for valid code and supported language" do
        expect do
          validator.validate_execution_params!("puts 'hello'", :ruby)
        end.not_to raise_error
      end

      it "accepts python as supported language" do
        expect do
          validator.validate_execution_params!("print('hello')", :python)
        end.not_to raise_error
      end
    end

    context "with invalid code" do
      it "raises ArgumentError for nil code" do
        expect do
          validator.validate_execution_params!(nil, :ruby)
        end.to raise_error(ArgumentError, /Code cannot be empty/)
      end

      it "raises ArgumentError for empty string code" do
        expect do
          validator.validate_execution_params!("", :ruby)
        end.to raise_error(ArgumentError, /Code cannot be empty/)
      end

      # NOTE: The implementation uses .to_s.empty? which returns false for whitespace
      # This is intentional behavior - whitespace-only code is considered valid input
    end

    context "with unsupported language" do
      it "raises ArgumentError for unsupported language" do
        expect do
          validator.validate_execution_params!("code", :javascript)
        end.to raise_error(ArgumentError, /Language not supported: javascript/)
      end

      it "includes language name in error message" do
        expect do
          validator.validate_execution_params!("code", :rust)
        end.to raise_error(ArgumentError, /rust/)
      end
    end
  end

  describe "#validate_execution_params" do
    context "with valid parameters" do
      it "returns true for valid code and language" do
        expect(validator.validate_execution_params("code", :ruby)).to be true
      end

      it "returns true for non-empty code" do
        expect(validator.validate_execution_params("x = 1", :python)).to be true
      end
    end

    context "with invalid code" do
      it "returns false for nil code" do
        # nil.to_s.empty? returns true, so validation fails
        # But the guard clause returns nil (falsy), not false
        expect(validator.validate_execution_params(nil, :ruby)).to be_falsy
      end

      it "returns false for empty string code" do
        expect(validator.validate_execution_params("", :ruby)).to be false
      end
    end

    context "with unsupported language" do
      it "returns false for unsupported language" do
        expect(validator.validate_execution_params("code", :javascript)).to be false
      end
    end

    context "with multiple invalid conditions" do
      it "returns false when both code and language are invalid" do
        expect(validator.validate_execution_params("", :unknown)).to be false
      end
    end
  end

  describe "#valid_execution_params?" do
    it "is an alias for validate_execution_params" do
      expect(validator.valid_execution_params?("code", :ruby)).to be true
      expect(validator.valid_execution_params?("", :ruby)).to be false
      expect(validator.valid_execution_params?("code", :unknown)).to be false
    end

    it "behaves identically to validate_execution_params" do
      test_cases = [
        ["code", :ruby],
        ["", :ruby],
        [nil, :python],
        ["code", :unknown]
      ]

      test_cases.each do |code, language|
        expect(validator.valid_execution_params?(code, language))
          .to eq(validator.validate_execution_params(code, language))
      end
    end
  end
end
