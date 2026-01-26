require "spec_helper"

RSpec.describe Smolagents::Tools::Tool::ErrorHints do
  describe ".enhance_error" do
    it "returns original error when no hint applies" do
      error = StandardError.new("generic error")
      result = described_class.enhance_error(error, tool_name: "test")

      expect(result).to equal(error)
    end

    it "returns enhanced error with TIP when hint applies" do
      error = ZeroDivisionError.new("divided by 0")
      result = described_class.enhance_error(error, tool_name: "calculate")

      expect(result.message).to include("divided by 0")
      expect(result.message).to include("TIP:")
      expect(result.message).to include("division by zero")
    end

    it "preserves error class when enhancing" do
      error = ZeroDivisionError.new("divided by 0")
      result = described_class.enhance_error(error, tool_name: "calc")

      expect(result).to be_a(ZeroDivisionError)
    end
  end

  describe ".find_best_hint" do
    it "returns nil for unknown error types" do
      error = IOError.new("file not found")
      hint = described_class.find_best_hint(error, tool_name: "read", inputs: {})

      expect(hint).to be_nil
    end

    it "returns hint for ZeroDivisionError" do
      error = ZeroDivisionError.new("divided by 0")
      hint = described_class.find_best_hint(error, tool_name: "calc", inputs: {})

      expect(hint).to include("division by zero")
    end
  end

  describe ".hint_for_name_error" do
    it "returns nil when variable name cannot be extracted" do
      error = NameError.new("some other error")
      hint = described_class.hint_for_name_error(error, {})

      expect(hint).to be_nil
    end

    it "returns nil when variable not found in inputs" do
      error = NameError.new("undefined local variable or method `foo'")
      hint = described_class.hint_for_name_error(error, { query: "search term" })

      expect(hint).to be_nil
    end

    it "returns interpolation hint when variable appears in string input" do
      error = NameError.new("undefined local variable or method `price'")
      hint = described_class.hint_for_name_error(error, { expression: "price * 2" })

      expect(hint).to include("\#{price}")
      expect(hint).to include("interpolation")
    end

    it "handles backtick-quoted variable names" do
      error = NameError.new("undefined local variable or method `result'")
      hint = described_class.hint_for_name_error(error, { formula: "result + 10" })

      expect(hint).to include("\#{result}")
    end

    it "handles single-quote variable names" do
      error = NameError.new("undefined local variable or method 'total'")
      hint = described_class.hint_for_name_error(error, { calc: "total * 2" })

      expect(hint).to include("\#{total}")
    end

    it "handles non-string input values" do
      error = NameError.new("undefined local variable or method `x'")
      hint = described_class.hint_for_name_error(error, { count: 42, items: %w[a b] })

      expect(hint).to be_nil
    end
  end

  describe ".hint_for_type_error" do
    it "returns nil for unrelated type errors" do
      error = TypeError.new("wrong argument type")
      hint = described_class.hint_for_type_error(error)

      expect(hint).to be_nil
    end

    it "returns hint for string conversion errors" do
      error = TypeError.new("no implicit conversion of Integer into String")
      hint = described_class.hint_for_type_error(error)

      expect(hint).to include("Expression must be a string")
      expect(hint).to include('expression: "25 * 4"')
    end

    it "handles Float conversion errors" do
      error = TypeError.new("no implicit conversion of Float into String")
      hint = described_class.hint_for_type_error(error)

      expect(hint).to include("Expression must be a string")
    end
  end

  describe ".hint_for_argument_error" do
    context "wrong number of arguments" do
      it "returns hint with default example when no expected inputs" do
        error = ArgumentError.new("wrong number of arguments (given 1, expected 0)")
        hint = described_class.hint_for_argument_error(error, "calculate", nil)

        expect(hint).to include("calculate is a function")
        expect(hint).to include("calculate(arg: value)")
      end

      it "returns hint with valid keywords when expected inputs provided" do
        error = ArgumentError.new("wrong number of arguments (given 2, expected 1)")
        expected = { expression: { type: "string" }, precision: { type: "integer" } }
        hint = described_class.hint_for_argument_error(error, "calculate", expected)

        expect(hint).to include("calculate(expression: ..., precision: ...)")
      end
    end

    context "missing keyword" do
      it "returns hint for missing required argument" do
        error = ArgumentError.new("missing keyword: :query")
        hint = described_class.hint_for_argument_error(error, "search", nil)

        expect(hint).to include("Missing required argument")
        expect(hint).to include('search(query: "...")')
      end

      it "handles missing keyword without colon prefix" do
        error = ArgumentError.new("missing keyword: query")
        hint = described_class.hint_for_argument_error(error, "search", nil)

        expect(hint).to include('search(query: "...")')
      end

      it "returns nil for non-matching missing keyword format" do
        error = ArgumentError.new("some other argument error")
        hint = described_class.hint_for_argument_error(error, "tool", nil)

        expect(hint).to be_nil
      end
    end

    context "unknown keyword" do
      it "returns hint with valid keywords when available" do
        error = ArgumentError.new("unknown keyword: :typo")
        expected = { query: { type: "string" }, limit: { type: "integer" } }
        hint = described_class.hint_for_argument_error(error, "search", expected)

        expect(hint).to include("Unknown 'typo:'")
        expect(hint).to include("query: ..., limit: ...")
      end

      it "returns help suggestion when no expected inputs" do
        error = ArgumentError.new("unknown keyword: :wrong")
        hint = described_class.hint_for_argument_error(error, "mytool", nil)

        expect(hint).to include("Unknown 'wrong:'")
        expect(hint).to include("help(:mytool)")
      end

      it "handles unknown keyword without colon prefix" do
        error = ArgumentError.new("unknown keyword: badarg")
        hint = described_class.hint_for_argument_error(error, "tool", nil)

        expect(hint).to include("Unknown 'badarg:'")
      end
    end
  end

  describe ".wrong_number_hint" do
    it "uses default example when no valid keywords" do
      hint = described_class.wrong_number_hint("calc", nil)

      expect(hint).to eq("calc is a function. Call it: calc(arg: value)")
    end

    it "uses provided valid keywords" do
      hint = described_class.wrong_number_hint("calc", "x: ..., y: ...")

      expect(hint).to eq("calc is a function. Call it: calc(x: ..., y: ...)")
    end
  end

  describe ".missing_keyword_hint" do
    it "extracts keyword name from message" do
      hint = described_class.missing_keyword_hint("missing keyword: :name", "tool")

      expect(hint).to eq('Missing required argument. Use: tool(name: "...")')
    end

    it "returns nil when pattern does not match" do
      hint = described_class.missing_keyword_hint("some other error", "tool")

      expect(hint).to be_nil
    end
  end

  describe ".unknown_keyword_hint" do
    it "includes wrong keyword name when extractable" do
      hint = described_class.unknown_keyword_hint("unknown keyword: :bad", "tool", "good: ...")

      expect(hint).to include("Unknown 'bad:'")
      expect(hint).to include("good: ...")
    end

    it "uses generic message when keyword not extractable" do
      hint = described_class.unknown_keyword_hint("unknown keyword: ???", "tool", "arg: ...")

      expect(hint).to include("Wrong argument name")
    end

    it "suggests help when no valid keywords" do
      hint = described_class.unknown_keyword_hint("unknown keyword: :x", "search", nil)

      expect(hint).to include("help(:search)")
    end
  end

  describe ".format_valid_keywords" do
    it "returns nil for nil input" do
      result = described_class.format_valid_keywords(nil)

      expect(result).to be_nil
    end

    it "returns nil for empty hash" do
      result = described_class.format_valid_keywords({})

      expect(result).to be_nil
    end

    it "formats single keyword" do
      result = described_class.format_valid_keywords({ query: { type: "string" } })

      expect(result).to eq("query: ...")
    end

    it "formats multiple keywords" do
      result = described_class.format_valid_keywords(
        query: { type: "string" },
        limit: { type: "integer" }
      )

      expect(result).to eq("query: ..., limit: ...")
    end
  end

  describe ".hint_for_no_method_error" do
    it "returns hint for nil:NilClass errors" do
      error = NoMethodError.new("undefined method `+' for nil:NilClass")
      hint = described_class.hint_for_no_method_error(error)

      expect(hint).to include("Variable is nil")
      expect(hint).to include("result = calculate")
    end

    it "returns hint for String method errors" do
      error = NoMethodError.new("undefined method `*' for \"100\":String")
      hint = described_class.hint_for_no_method_error(error)

      expect(hint).to include("Can't call that method on a String")
      expect(hint).to include("result.to_i")
    end

    it "returns hint for Integer method errors" do
      error = NoMethodError.new("undefined method `split' for 42:Integer")
      hint = described_class.hint_for_no_method_error(error)

      expect(hint).to include("Can't call that method on a number")
      expect(hint).to include("result.to_s")
    end

    it "returns hint for Float method errors" do
      error = NoMethodError.new("undefined method `upcase' for 3.14:Float")
      hint = described_class.hint_for_no_method_error(error)

      expect(hint).to include("Can't call that method on a number")
    end

    it "returns nil for other NoMethodErrors" do
      error = NoMethodError.new("undefined method `foo' for SomeClass")
      hint = described_class.hint_for_no_method_error(error)

      expect(hint).to be_nil
    end
  end

  describe ".extract_var_name" do
    it "extracts variable name with backticks" do
      error = NameError.new("undefined local variable or method `myvar'")
      result = described_class.extract_var_name(error)

      expect(result).to eq("myvar")
    end

    it "extracts variable name with single quotes" do
      error = NameError.new("undefined local variable or method 'another'")
      result = described_class.extract_var_name(error)

      expect(result).to eq("another")
    end

    it "returns nil for non-matching messages" do
      error = NameError.new("some other name error")
      result = described_class.extract_var_name(error)

      expect(result).to be_nil
    end
  end

  describe ".create_enhanced_error" do
    it "creates new error of same class with new message" do
      original = ArgumentError.new("original")
      result = described_class.create_enhanced_error(original, "enhanced message")

      expect(result).to be_a(ArgumentError)
      expect(result.message).to eq("enhanced message")
      expect(result).not_to equal(original)
    end

    it "works with custom error classes" do
      custom_class = Class.new(StandardError)
      original = custom_class.new("original")
      result = described_class.create_enhanced_error(original, "new message")

      expect(result).to be_a(custom_class)
      expect(result.message).to eq("new message")
    end
  end

  describe "HINT_HANDLERS constant" do
    it "contains handlers for expected error types" do
      expect(described_class::HINT_HANDLERS.keys).to contain_exactly(
        NameError, TypeError, ArgumentError, NoMethodError, ZeroDivisionError
      )
    end

    it "handlers are callable" do
      described_class::HINT_HANDLERS.each_value do |handler|
        expect(handler).to respond_to(:call)
      end
    end
  end

  describe "integration" do
    it "enhances NameError with interpolation hint" do
      error = NameError.new("undefined local variable or method `total'")
      result = described_class.enhance_error(
        error,
        tool_name: "calculate",
        inputs: { expression: "total * 0.1" }
      )

      expect(result.message).to include("TIP:")
      expect(result.message).to include("\#{total}")
    end

    it "enhances ArgumentError with valid keywords" do
      error = ArgumentError.new("unknown keyword: :qery")
      result = described_class.enhance_error(
        error,
        tool_name: "search",
        inputs: { qery: "test" },
        expected_inputs: { query: { type: "string" }, limit: { type: "integer" } }
      )

      expect(result.message).to include("TIP:")
      expect(result.message).to include("Unknown 'qery:'")
      expect(result.message).to include("query: ..., limit: ...")
    end
  end
end
