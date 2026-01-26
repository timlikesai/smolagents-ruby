RSpec.describe Smolagents::Utilities::PatternMatching::FinalAnswer do
  describe ".extract_standalone" do
    it "extracts final_answer with answer parameter" do
      text = "The result is final_answer(answer: 42)"
      result = described_class.extract_standalone(text)

      expect(result).to eq("final_answer(answer: 42)")
    end

    it "handles whitespace after final_answer" do
      text = "final_answer   (answer: test)"
      result = described_class.extract_standalone(text)

      expect(result).to include("final_answer(answer:")
    end

    it "extracts answer from parentheses" do
      text = "final_answer(answer: 'hello world')"
      result = described_class.extract_standalone(text)

      expect(result).to include("hello world")
    end

    it "stops at period or newline" do
      text = "final_answer(answer: 42). More text"
      result = described_class.extract_standalone(text)

      expect(result).to include("42")
    end

    it "extracts with trailing newline" do
      text = "final_answer(answer: test)\nNext line"
      result = described_class.extract_standalone(text)

      expect(result).to include("test")
    end

    it "extracts with trailing comment" do
      text = "final_answer(answer: result) # comment"
      result = described_class.extract_standalone(text)

      expect(result).to include("result")
    end

    it "handles case-insensitive matching" do
      text = "FINAL_ANSWER(ANSWER: value)"
      result = described_class.extract_standalone(text)

      expect(result).not_to be_nil
    end

    it "extracts with balanced parentheses" do
      text = "final_answer(answer: func(a, b))"
      result = described_class.extract_standalone(text)

      expect(result).to include("func(a, b)")
    end

    it "returns nil when no final_answer present" do
      text = "Just some random code"
      result = described_class.extract_standalone(text)

      expect(result).to be_nil
    end

    it "cleans up trailing explanations from answer" do
      text = "final_answer(answer: 42 # the number)"
      result = described_class.extract_standalone(text)

      expect(result).not_to include("the number")
    end

    it "handles multiline answer text" do
      text = %(final_answer(answer: "multi\nline"))
      result = described_class.extract_standalone(text)

      expect(result).not_to be_nil
    end
  end

  describe ".maybe_append" do
    it "returns code unchanged if final_answer already present" do
      code = "result = search()\nfinal_answer(answer: result)"
      text = "Some text"
      result = described_class.maybe_append(code, text)

      expect(result).to eq(code)
    end

    it "appends extracted final_answer to code" do
      code = "result = search()"
      text = "final_answer(answer: 42)"
      result = described_class.maybe_append(code, text)

      expect(result).to include("result = search()")
      expect(result).to include("final_answer")
    end

    it "appends on new line" do
      code = "result = search()"
      text = "final_answer(answer: 42)"
      result = described_class.maybe_append(code, text)

      expect(result).to include("\n")
    end

    it "returns code unchanged if no final_answer to extract" do
      code = "result = search()"
      text = "Just some text"
      result = described_class.maybe_append(code, text)

      expect(result).to eq(code)
    end

    it "extracts final_answer from middle of text" do
      code = "x = 1"
      text = "Thinking... final_answer(answer: x + 1) More text"
      result = described_class.maybe_append(code, text)

      expect(result).to include("final_answer")
    end
  end

  describe ".extract_balanced_value" do
    it "extracts simple string value" do
      str = '"hello")'
      result = described_class.extract_balanced_value(str)

      expect(result).to eq('"hello"')
    end

    it "extracts numeric value" do
      str = "42)"
      result = described_class.extract_balanced_value(str)

      expect(result).to eq("42")
    end

    it "extracts value with balanced parentheses" do
      str = "func(a, b))"
      result = described_class.extract_balanced_value(str)

      expect(result).to eq("func(a, b)")
    end

    it "extracts string with escaped quotes" do
      str = '"He said \\"hello\\"")'
      result = described_class.extract_balanced_value(str)

      expect(result).to include("hello")
    end

    it "returns nil for empty input" do
      result = described_class.extract_balanced_value("")

      expect(result).to be_nil
    end

    it "returns nil for nil input" do
      result = described_class.extract_balanced_value(nil)

      expect(result).to be_nil
    end

    it "handles nested parentheses correctly" do
      str = "[1, 2, (3, 4)])"
      result = described_class.extract_balanced_value(str)

      expect(result).to eq("[1, 2, (3, 4)]")
    end

    it "stops at closing parenthesis" do
      str = "answer) extra text"
      result = described_class.extract_balanced_value(str)

      expect(result).to eq("answer")
    end
  end

  describe ".clean_answer_value" do
    it "removes trailing comments" do
      result = described_class.clean_answer_value("42 # the answer")

      expect(result).to eq("42")
    end

    it "removes trailing explanation with 'and'" do
      result = described_class.clean_answer_value("Paris and it's beautiful")

      expect(result).to eq("Paris")
    end

    it "removes trailing explanation with 'because'" do
      result = described_class.clean_answer_value("yes because reasons")

      expect(result).to eq("yes")
    end

    it "removes trailing explanation with 'since'" do
      result = described_class.clean_answer_value("correct since proven")

      expect(result).to eq("correct")
    end

    it "removes trailing explanation with 'so'" do
      result = described_class.clean_answer_value("true so important")

      expect(result).to eq("true")
    end

    it "removes trailing explanation with 'this'" do
      result = described_class.clean_answer_value("value this works")

      expect(result).to eq("value")
    end

    it "removes trailing explanation with 'the'" do
      result = described_class.clean_answer_value("answer the final one")

      expect(result).to eq("answer")
    end

    it "removes trailing explanation with 'I'" do
      result = described_class.clean_answer_value("result I calculated")

      expect(result).to eq("result")
    end

    it "strips whitespace" do
      result = described_class.clean_answer_value("  answer  ")

      expect(result).to eq("answer")
    end

    it "handles case-insensitive keywords" do
      result = described_class.clean_answer_value("answer BECAUSE reasons")

      expect(result).to eq("answer")
    end

    it "preserves answer with no trailing text" do
      result = described_class.clean_answer_value("simple answer")

      expect(result).to eq("simple answer")
    end
  end

  describe ".balance_parens" do
    it "returns string with balanced parentheses" do
      result = described_class.balance_parens("(a (b c))")

      expect(result).to eq("(a (b c))")
    end

    it "truncates at first unbalanced closing paren" do
      result = described_class.balance_parens("(a b) extra)")

      expect(result).to eq("(a b) extra")
    end

    it "ignores closing paren when depth is zero" do
      result = described_class.balance_parens("a b) c d")

      expect(result).to eq("a b")
    end

    it "handles deeply nested parentheses" do
      result = described_class.balance_parens("(((a)))")

      expect(result).to eq("(((a)))")
    end

    it "returns entire string when no extra closing paren" do
      result = described_class.balance_parens("(a b c)")

      expect(result).to eq("(a b c)")
    end

    it "handles mixed nesting" do
      result = described_class.balance_parens("func(arg(1, 2), arg2)")

      expect(result).to eq("func(arg(1, 2), arg2)")
    end

    it "stops at first unbalanced close" do
      result = described_class.balance_parens("(a) (b) c)")

      expect(result).to eq("(a) (b) c")
    end
  end

  describe "ParseState struct" do
    it "tracks parsing state" do
      state = described_class::ParseState.new(0, false, nil, false, "")

      expect(state.depth).to eq(0)
      expect(state.in_string).to be false
      expect(state.string_char).to be_nil
      expect(state.escape_next).to be false
      expect(state.result).to eq("")
    end

    it "allows mutation for parsing" do
      state = described_class::ParseState.new(0, false, nil, false, "")
      state.depth = 1
      state.result = "test"

      expect(state.depth).to eq(1)
      expect(state.result).to eq("test")
    end
  end
end
