require "spec_helper"

RSpec.describe Smolagents::Concerns::ExecutionOracle::SuggestionGenerator do
  subject(:generator) { test_class.new }

  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ExecutionOracle::SuggestionGenerator
    end
  end

  describe "#generate_suggestion" do
    context "with static error types" do
      it "returns static suggestion for timeout" do
        suggestion = generator.generate_suggestion(:timeout, {}, "code")
        expect(suggestion).to include("Simplify the code")
      end

      it "returns static suggestion for memory_limit" do
        suggestion = generator.generate_suggestion(:memory_limit, {}, "code")
        expect(suggestion).to include("Reduce data size")
      end

      it "returns static suggestion for operation_limit" do
        suggestion = generator.generate_suggestion(:operation_limit, {}, "code")
        expect(suggestion).to include("Reduce loop iterations")
      end
    end

    context "with dynamic error types" do
      describe "syntax errors" do
        it "suggests removing unexpected token" do
          details = { unexpected: ")" }
          suggestion = generator.generate_suggestion(:syntax_error, details, "code")
          expect(suggestion).to include("Remove")
          expect(suggestion).to include(")")
        end

        it "suggests adding expected token" do
          details = { expecting: "end" }
          suggestion = generator.generate_suggestion(:syntax_error, details, "code")
          expect(suggestion).to include("Add")
          expect(suggestion).to include("end")
        end

        it "suggests checking brackets for empty details" do
          details = {}
          suggestion = generator.generate_suggestion(:syntax_error, details, "code")
          expect(suggestion).to include("brackets")
        end
      end

      describe "name errors" do
        it "suggests defining variable" do
          details = { undefined_name: "user_id" }
          suggestion = generator.generate_suggestion(:name_error, details, "code")
          expect(suggestion).to include("user_id")
        end

        it "finds similar names in code" do
          details = { undefined_name: "usr" }
          code = "user = 1\nusers = 2\nusr_id = 3"
          suggestion = generator.generate_suggestion(:name_error, details, code)
          expect(suggestion).to include("usr_id")
        end

        it "suggests checking spelling without code" do
          details = { undefined_name: "var" }
          suggestion = generator.generate_suggestion(:name_error, details, nil)
          expect(suggestion).to include("spelling")
        end
      end

      describe "no method errors" do
        it "includes method and class when available" do
          details = { undefined_method: "upcase", receiver_class: "Integer" }
          suggestion = generator.generate_suggestion(:no_method_error, details, "code")
          expect(suggestion).to include("upcase")
          expect(suggestion).to include("Integer")
        end

        it "suggests generic fix without class" do
          details = { undefined_method: "foo" }
          suggestion = generator.generate_suggestion(:no_method_error, details, "code")
          expect(suggestion).to include("foo")
        end
      end

      describe "type errors" do
        it "suggests explicit conversion" do
          details = { from_type: "String", to_type: "Integer" }
          suggestion = generator.generate_suggestion(:type_error, details, "code")
          expect(suggestion).to include("Convert")
          expect(suggestion).to include("String")
          expect(suggestion).to include("Integer")
          expect(suggestion).to include("to_i")
        end

        it "suggests generic fix without types" do
          details = {}
          suggestion = generator.generate_suggestion(:type_error, details, "code")
          expect(suggestion).to include("Check types")
        end
      end

      describe "argument errors" do
        it "suggests correct argument count" do
          details = { given: 1, expected: "3" }
          suggestion = generator.generate_suggestion(:argument_error, details, "code")
          expect(suggestion).to include("3")
          expect(suggestion).to include("1")
        end

        it "suggests generic fix without details" do
          details = {}
          suggestion = generator.generate_suggestion(:argument_error, details, "code")
          expect(suggestion).to include("argument")
        end
      end

      describe "tool errors" do
        it "mentions tool name when available" do
          details = { tool_name: "search_tool" }
          suggestion = generator.generate_suggestion(:tool_error, details, "code")
          expect(suggestion).to include("search_tool")
        end

        it "suggests generic fix without tool name" do
          details = {}
          suggestion = generator.generate_suggestion(:tool_error, details, "code")
          expect(suggestion).to include("tool")
        end
      end
    end

    context "with unknown error type" do
      it "returns generic suggestion" do
        suggestion = generator.generate_suggestion(:unknown_error, {}, "code")
        expect(suggestion).to include("Check the error message")
      end
    end
  end

  describe "#dynamic_suggestion" do
    it "dispatches to correct handler" do
      suggestion = generator.send(:dynamic_suggestion, :syntax_error, {}, "code")
      expect(suggestion).to include("brackets")
    end
  end

  describe "private suggestion methods" do
    describe "#syntax_suggestion" do
      it "combines unexpected and expecting" do
        details = { unexpected: "}", expecting: "end" }
        suggestion = generator.send(:syntax_suggestion, details)
        expect(suggestion).to include("}")
        expect(suggestion).to include("end")
      end

      it "returns generic when no details" do
        suggestion = generator.send(:syntax_suggestion, {})
        expect(suggestion).to include("brackets")
      end
    end

    describe "#name_error_suggestion" do
      it "finds similar names" do
        code = "first_name = 'John'\nlast_name = 'Doe'\nfirst_nam = nil"
        suggestion = generator.send(:name_error_suggestion, { undefined_name: "firs_name" }, code)
        expect(suggestion).to include("Did you mean")
      end

      it "suggests defining when no similar names" do
        suggestion = generator.send(:name_error_suggestion, { undefined_name: "xyz" }, "")
        expect(suggestion).to include("Define")
      end
    end

    describe "#no_method_suggestion" do
      it "includes receiver class when available" do
        details = { undefined_method: "foo", receiver_class: "Array" }
        suggestion = generator.send(:no_method_suggestion, details)
        expect(suggestion).to include("Array")
        expect(suggestion).to include("foo")
      end

      it "generic suggestion without receiver" do
        details = { undefined_method: "bar" }
        suggestion = generator.send(:no_method_suggestion, details)
        expect(suggestion).to include("bar")
      end
    end

    describe "#type_error_suggestion" do
      it "suggests conversion functions" do
        details = { from_type: "Float", to_type: "String" }
        suggestion = generator.send(:type_error_suggestion, details)
        expect(suggestion).to include("Float")
        expect(suggestion).to include("String")
        expect(suggestion).to include(".to_")
      end

      it "generic suggestion without type details" do
        suggestion = generator.send(:type_error_suggestion, {})
        expect(suggestion).to include("Check types")
      end
    end

    describe "#argument_error_suggestion" do
      it "includes argument counts" do
        details = { given: 2, expected: "3" }
        suggestion = generator.send(:argument_error_suggestion, details)
        expect(suggestion).to include("3")
        expect(suggestion).to include("2")
      end

      it "generic suggestion without counts" do
        suggestion = generator.send(:argument_error_suggestion, {})
        expect(suggestion).to include("argument")
      end
    end

    describe "#tool_error_suggestion" do
      it "includes tool name" do
        details = { tool_name: "missing_tool" }
        suggestion = generator.send(:tool_error_suggestion, details)
        expect(suggestion).to include("missing_tool")
      end

      it "generic suggestion without name" do
        suggestion = generator.send(:tool_error_suggestion, {})
        expect(suggestion).to include("tool")
      end
    end

    describe "#find_similar_names" do
      it "finds similar identifiers in code" do
        code = "user_name = 'John'\nuser_id = 5\nusers = []"
        similar = generator.send(:find_similar_names, "user", code)
        expect(similar).to include("user_name")
      end

      it "returns empty without code" do
        similar = generator.send(:find_similar_names, "test", nil)
        expect(similar).to be_empty
      end

      it "limits to first 3 matches" do
        code = "abc abcd abcde abcdef abcdefg"
        similar = generator.send(:find_similar_names, "abc", code)
        expect(similar.size).to be <= 3
      end

      it "ignores exact matches" do
        code = "user user_name users"
        similar = generator.send(:find_similar_names, "user", code)
        expect(similar).not_to include("user")
      end
    end

    describe "#similar?" do
      it "returns true for case-insensitive match" do
        result = generator.send(:similar?, "User", "user")
        expect(result).to be true
      end

      it "returns true if start with same prefix" do
        result = generator.send(:similar?, "first_name", "firs_name")
        expect(result).to be true
      end

      it "returns true if end with same suffix" do
        result = generator.send(:similar?, "my_var", "your_var")
        expect(result).to be true
      end

      it "returns false for completely different names" do
        result = generator.send(:similar?, "foo", "xyz")
        expect(result).to be false
      end

      it "returns false for exact match" do
        result = generator.send(:similar?, "test", "test")
        expect(result).to be false
      end
    end
  end

  describe "static suggestions" do
    it "defines STATIC_SUGGESTIONS" do
      suggestions = Smolagents::Concerns::ExecutionOracle::SuggestionGenerator::STATIC_SUGGESTIONS
      expect(suggestions).to be_a(Hash)
    end

    it "has suggestions for timeout, memory, and operations" do
      suggestions = Smolagents::Concerns::ExecutionOracle::SuggestionGenerator::STATIC_SUGGESTIONS
      expect(suggestions).to have_key(:timeout)
      expect(suggestions).to have_key(:memory_limit)
      expect(suggestions).to have_key(:operation_limit)
    end

    it "all suggestions are strings" do
      suggestions = Smolagents::Concerns::ExecutionOracle::SuggestionGenerator::STATIC_SUGGESTIONS
      suggestions.each_value do |suggestion|
        expect(suggestion).to be_a(String)
      end
    end
  end

  describe "integration" do
    it "generates complete suggestions for various errors" do
      test_cases = [
        { error: :syntax_error, details: { unexpected: ")" }, expected: "Remove or fix" },
        { error: :name_error, details: { undefined_name: "var" }, expected: "var" },
        { error: :no_method_error, details: { undefined_method: "foo" }, expected: "foo" },
        { error: :type_error, details: { from_type: "String", to_type: "Int" }, expected: "Convert" },
        { error: :timeout, details: {}, expected: "Simplify" }
      ]

      test_cases.each do |test|
        suggestion = generator.generate_suggestion(test[:error], test[:details], "code")
        expect(suggestion).to include(test[:expected])
      end
    end

    it "provides actionable suggestions" do
      suggestions = [
        generator.generate_suggestion(:syntax_error, { unexpected: "}" }, "x = [1,2"),
        generator.generate_suggestion(:name_error, { undefined_name: "usr" }, "user = 1"),
        generator.generate_suggestion(:timeout, {}, "code")
      ]

      suggestions.each do |suggestion|
        expect(suggestion).to be_a(String)
        expect(suggestion.length).to be > 10 # Non-trivial suggestion
      end
    end
  end
end
