RSpec.describe Smolagents::Executors::Executor::Validation do
  let(:test_executor) do
    Class.new(Smolagents::Executor) do
      include Smolagents::Executors::Executor::Validation

      def supports?(language)
        %i[ruby python].include?(language)
      end
    end
  end

  let(:executor) { test_executor.new }

  describe "#validate_execution_params!" do
    it "returns nil for valid params" do
      result = executor.validate_execution_params!("code", :ruby)
      expect(result).to be_nil
    end

    it "accepts valid code and supported language" do
      expect { executor.validate_execution_params!("puts 42", :ruby) }.not_to raise_error
    end

    it "raises for empty code string" do
      expect do
        executor.validate_execution_params!("", :ruby)
      end.to raise_error(ArgumentError, /Code cannot be empty/)
    end

    it "raises for nil code" do
      expect do
        executor.validate_execution_params!(nil, :ruby)
      end.to raise_error(ArgumentError, /Code cannot be empty/)
    end

    it "raises for unsupported language" do
      expect do
        executor.validate_execution_params!("code", :go)
      end.to raise_error(ArgumentError, /Language not supported/)
    end

    it "includes unsupported language in error" do
      expect do
        executor.validate_execution_params!("code", :java)
      end.to raise_error(ArgumentError) { |e| e.message.include?("java") }
    end

    it "validates code as not empty for whitespace-only" do
      # Whitespace-only strings are not empty, so they pass
      code = "   \n\t  "
      # Since the code is not empty string, it doesn't raise for code validation
      # It only raises if the language is invalid
      expect do
        executor.validate_execution_params!(code, :ruby)
      end.not_to raise_error
    end

    it "does not strip whitespace for code validation" do
      # to_s is not stripped, so "   " is not empty
      code = "   "
      # This should pass since "   ".to_s.empty? is false
      expect do
        executor.validate_execution_params!(code, :ruby)
      end.not_to raise_error
    end

    it "works with multiple supported languages" do
      expect { executor.validate_execution_params!("code", :ruby) }.not_to raise_error
      expect { executor.validate_execution_params!("code", :python) }.not_to raise_error
      expect { executor.validate_execution_params!("code", :java) }.to raise_error(ArgumentError)
    end

    it "validates language even if code is valid" do
      valid_code = "x = 42"
      expect do
        executor.validate_execution_params!(valid_code, :unknown)
      end.to raise_error(ArgumentError, /Language not supported/)
    end

    it "validates code even if language is valid" do
      expect do
        executor.validate_execution_params!("", :ruby)
      end.to raise_error(ArgumentError, /Code cannot be empty/)
    end

    it "produces clear error messages" do
      expect do
        executor.validate_execution_params!("", :ruby)
      end.to raise_error(ArgumentError) { |e| e.message.include?("Code") }
    end
  end

  describe "#validate_execution_params" do
    it "returns true for valid params" do
      result = executor.validate_execution_params("code", :ruby)
      expect(result).to be true
    end

    it "returns false for empty code" do
      result = executor.validate_execution_params("", :ruby)
      expect(result).to be false
    end

    it "returns falsy for nil code" do
      result = executor.validate_execution_params(nil, :ruby)
      expect(result).to be_falsy
    end

    it "returns false for unsupported language" do
      result = executor.validate_execution_params("code", :go)
      expect(result).to be false
    end

    it "allows whitespace-only code (not stripped)" do
      # Whitespace-only strings are not empty, so they return true
      result = executor.validate_execution_params("   ", :ruby)
      expect(result).to be true
    end

    it "does not raise exceptions" do
      expect do
        executor.validate_execution_params("", :ruby)
        executor.validate_execution_params("code", :invalid)
        executor.validate_execution_params(nil, :python)
      end.not_to raise_error
    end

    it "returns boolean values only" do
      result1 = executor.validate_execution_params("code", :ruby)
      result2 = executor.validate_execution_params("", :ruby)

      expect(result1).to be true
      expect(result2).to be false
    end

    it "handles various input types for code" do
      expect(executor.validate_execution_params("", :ruby)).to be false
      expect(executor.validate_execution_params(nil, :ruby)).to be_falsy
      expect(executor.validate_execution_params(42, :ruby)).to be true # to_s => "42", not empty
    end
  end

  describe "#valid_execution_params?" do
    it "is an alias for validate_execution_params" do
      code = "x = 1"
      lang = :ruby

      result1 = executor.validate_execution_params(code, lang)
      result2 = executor.valid_execution_params?(code, lang)

      expect(result1).to eq(result2)
    end

    it "works the same way" do
      expect(executor.valid_execution_params?("code", :ruby)).to be true
      expect(executor.valid_execution_params?("", :ruby)).to be false
      expect(executor.valid_execution_params?("code", :invalid)).to be false
    end

    it "is a predicate method" do
      # Should end with ?
      expect(executor.respond_to?(:valid_execution_params?)).to be true
    end
  end

  describe "comparison: raising vs non-raising" do
    it "raising variant raises, non-raising returns false" do
      empty_code = ""

      expect do
        executor.validate_execution_params!(empty_code, :ruby)
      end.to raise_error(ArgumentError)

      expect(executor.validate_execution_params(empty_code, :ruby)).to be false
    end

    it "both return successfully for valid input" do
      valid_code = "x = 1"
      valid_lang = :ruby

      expect(executor.validate_execution_params!(valid_code, valid_lang)).to be_nil
      expect(executor.validate_execution_params(valid_code, valid_lang)).to be true
    end

    it "raises variant has clear error messages" do
      expect do
        executor.validate_execution_params!("", :ruby)
      end.to raise_error(ArgumentError) { |e| e.message.include?("Code") }
    end
  end

  describe "edge cases" do
    it "handles code object that responds to to_s" do
      code = Object.new
      def code.to_s
        "actual code"
      end

      result = executor.validate_execution_params(code, :ruby)
      expect(result).to be true
    end

    it "handles empty to_s result" do
      code = Object.new
      def code.to_s
        ""
      end

      result = executor.validate_execution_params(code, :ruby)
      expect(result).to be false
    end
  end

  describe "typical workflows" do
    it "validates before execution" do
      code = "puts 42"
      lang = :ruby

      # Check if valid first
      if executor.valid_execution_params?(code, lang)
        expect do
          executor.validate_execution_params!(code, lang)
        end.not_to raise_error
      end
    end

    it "can be used as a guard" do
      code = "valid_code"
      lang = :ruby

      # Method returns boolean usable in guard clauses
      valid = executor.validate_execution_params(code, lang)
      expect([true, false].include?(valid)).to be true
    end

    it "validates various languages" do
      code = "valid code"

      supported = %i[ruby python]
      unsupported = %i[java go cpp javascript]

      supported.each do |lang|
        expect(executor.validate_execution_params(code, lang)).to be true
      end

      unsupported.each do |lang|
        expect(executor.validate_execution_params(code, lang)).to be false
      end
    end
  end

  describe "language support" do
    it "respects executor's supports? method" do
      executor_class = Class.new(Smolagents::Executor) do
        include Smolagents::Executors::Executor::Validation

        def supports?(language) = language == :ruby_only
      end

      strict_executor = executor_class.new

      expect(strict_executor.validate_execution_params("code", :ruby_only)).to be true
      expect(strict_executor.validate_execution_params("code", :ruby)).to be false
      expect(strict_executor.validate_execution_params("code", :python)).to be false
    end

    it "works with no supported languages" do
      executor_none = Class.new(Smolagents::Executor) do
        include Smolagents::Executors::Executor::Validation

        def supports?(language) = false
      end.new

      expect(executor_none.validate_execution_params("code", :ruby)).to be false
      expect(executor_none.validate_execution_params("code", :python)).to be false
    end

    it "works with many supported languages" do
      executor_many = Class.new(Smolagents::Executor) do
        include Smolagents::Executors::Executor::Validation

        def supports?(language) = true
      end.new

      expect(executor_many.validate_execution_params("code", :ruby)).to be true
      expect(executor_many.validate_execution_params("code", :python)).to be true
      expect(executor_many.validate_execution_params("code", :anything)).to be true
    end
  end

  describe "parameter types" do
    it "accepts symbol language" do
      expect(executor.validate_execution_params("code", :ruby)).to be true
    end

    it "handles non-symbol languages" do
      # String language won't match symbol, so returns false
      result = executor.validate_execution_params("code", "ruby")
      expect(result).to be false
    end

    it "treats 0 as valid code" do
      # 0.to_s = "0" which is not empty
      result = executor.validate_execution_params(0, :ruby)
      expect(result).to be true
    end

    it "treats false as invalid code due to short-circuit" do
      # false.to_s = "false" which is not empty, BUT
      # the implementation uses `code && ...` which short-circuits on falsy values
      result = executor.validate_execution_params(false, :ruby)
      expect(result).to be false
    end
  end

  describe "included functionality" do
    it "provides all three methods" do
      expect(executor.respond_to?(:validate_execution_params!)).to be true
      expect(executor.respond_to?(:validate_execution_params)).to be true
      expect(executor.respond_to?(:valid_execution_params?)).to be true
    end

    it "methods are available after inclusion" do
      test_class = Class.new do
        include Smolagents::Executors::Executor::Validation

        def supports?(language) = true
      end

      test_obj = test_class.new

      expect(test_obj.respond_to?(:validate_execution_params!)).to be true
      expect(test_obj.respond_to?(:valid_execution_params?)).to be true
    end
  end
end
