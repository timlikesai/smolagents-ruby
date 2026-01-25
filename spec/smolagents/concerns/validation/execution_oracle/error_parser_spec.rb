require "spec_helper"

RSpec.describe Smolagents::Concerns::ExecutionOracle::ErrorParser do
  subject(:parser) { test_class.new }

  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ExecutionOracle::ErrorParser
    end
  end

  describe "#parse_error_details" do
    describe "syntax errors" do
      it "parses unexpected keyword" do
        msg = "syntax error, unexpected '}'"
        details = parser.parse_error_details(:syntax_error, msg)

        expect(details[:unexpected]).to eq("'}'")
      end

      it "parses expecting clause" do
        msg = "syntax error, expecting 'end'"
        details = parser.parse_error_details(:syntax_error, msg)

        expect(details[:expecting]).to eq("'end'")
      end

      it "handles both unexpected and expecting" do
        msg = "syntax error, unexpected '}' expecting 'end'"
        details = parser.parse_error_details(:syntax_error, msg)

        expect(details[:unexpected]).to eq("'}'")
        expect(details[:expecting]).to eq("'end'")
      end

      it "returns empty for unmatched syntax error" do
        msg = "some other syntax issue"
        details = parser.parse_error_details(:syntax_error, msg)

        expect(details).to eq({})
      end
    end

    describe "name errors" do
      it "parses undefined variable name" do
        msg = "undefined local variable or method `missing_var'"
        details = parser.parse_error_details(:name_error, msg)

        expect(details[:undefined_name]).to eq("missing_var")
      end

      it "parses undefined constant" do
        msg = "undefined constant `MyConstant'"
        details = parser.parse_error_details(:name_error, msg)

        expect(details[:undefined_name]).to eq("MyConstant")
      end

      it "returns empty for unmatched name error" do
        msg = "something wrong"
        details = parser.parse_error_details(:name_error, msg)

        expect(details).to eq({})
      end
    end

    describe "no method errors" do
      it "parses undefined method for instance" do
        msg = "undefined method `foo' for an instance of String"
        details = parser.parse_error_details(:no_method_error, msg)

        expect(details[:undefined_method]).to eq("foo")
        expect(details[:receiver_class]).to eq("String")
      end

      it "parses undefined method without receiver" do
        msg = "undefined method `bar'"
        details = parser.parse_error_details(:no_method_error, msg)

        expect(details[:undefined_method]).to eq("bar")
      end

      it "compacts nil receiver_class" do
        msg = "undefined method `baz'"
        details = parser.parse_error_details(:no_method_error, msg)

        expect(details).not_to have_key(:receiver_class)
      end
    end

    describe "type errors" do
      it "parses implicit conversion error" do
        msg = "no implicit conversion of String into Integer"
        details = parser.parse_error_details(:type_error, msg)

        expect(details[:from_type]).to eq("String")
        expect(details[:to_type]).to eq("Integer")
      end

      it "parses coercion error" do
        msg = "Float can't be coerced into String"
        details = parser.parse_error_details(:type_error, msg)

        expect(details[:from_type]).to eq("Float")
        expect(details[:to_type]).to eq("String")
      end

      it "returns empty for unmatched type error" do
        msg = "type issue"
        details = parser.parse_error_details(:type_error, msg)

        expect(details).to eq({})
      end
    end

    describe "argument errors" do
      it "parses wrong number of arguments" do
        msg = "wrong number of arguments (given 2, expected 3)"
        details = parser.parse_error_details(:argument_error, msg)

        expect(details[:given]).to eq(2)
        expect(details[:expected]).to eq("3")
      end

      it "parses argument range" do
        msg = "wrong number of arguments (given 1, expected 2..4)"
        details = parser.parse_error_details(:argument_error, msg)

        expect(details[:given]).to eq(1)
        expect(details[:expected]).to eq("2..4")
      end

      it "returns empty for unmatched argument error" do
        msg = "wrong arguments"
        details = parser.parse_error_details(:argument_error, msg)

        expect(details).to eq({})
      end
    end

    describe "tool errors" do
      it "parses tool not found" do
        msg = "Tool `search_tool' not found"
        details = parser.parse_error_details(:tool_error, msg)

        expect(details[:tool_name]).to eq("search_tool")
      end

      it "returns empty for unmatched tool error" do
        msg = "tool missing"
        details = parser.parse_error_details(:tool_error, msg)

        expect(details).to eq({})
      end
    end

    context "unknown categories" do
      it "returns empty hash for unknown categories" do
        details = parser.parse_error_details(:unknown_category, "some message")
        expect(details).to eq({})
      end
    end
  end

  describe "#extract_location" do
    it "extracts line number from error message" do
      msg = "file.rb:42: something went wrong"
      location = parser.extract_location(msg, nil)

      expect(location[:line]).to eq(42)
    end

    it "handles messages with multiple colons" do
      msg = "file.rb:123: error message: more detail"
      location = parser.extract_location(msg, nil)

      expect(location[:line]).to eq(123)
    end

    it "returns nil when no line number found" do
      msg = "error message without line number"
      location = parser.extract_location(msg, nil)

      expect(location).to be_nil
    end

    it "handles different line number formats" do
      [
        ["error at :5:", 5],
        ["file.rb:999:", 999],
        [":0: zero line", 0],
        [":9999:", 9999]
      ].each do |msg, expected_line|
        location = parser.extract_location(msg, nil)
        expect(location[:line]).to eq(expected_line) if location
      end
    end

    it "ignores code parameter" do
      # The code parameter is currently unused (_code)
      msg = "error at :42:"
      code = "some_code = 1\nmore_code = 2"
      location = parser.extract_location(msg, code)

      expect(location[:line]).to eq(42)
    end
  end

  describe "error patterns" do
    it "defines ERROR_PATTERNS" do
      patterns = Smolagents::Concerns::ExecutionOracle::ErrorParser::ERROR_PATTERNS
      expect(patterns).to be_a(Hash)
    end

    it "has patterns for major error types" do
      patterns = Smolagents::Concerns::ExecutionOracle::ErrorParser::ERROR_PATTERNS
      expect(patterns).to have_key(:syntax_error)
      expect(patterns).to have_key(:name_error)
      expect(patterns).to have_key(:no_method_error)
      expect(patterns).to have_key(:type_error)
      expect(patterns).to have_key(:argument_error)
      expect(patterns).to have_key(:tool_not_found)
    end

    it "all patterns are regular expressions" do
      patterns = Smolagents::Concerns::ExecutionOracle::ErrorParser::ERROR_PATTERNS
      patterns.each_value do |pattern|
        expect(pattern).to be_a(Regexp)
      end
    end
  end

  describe "integration" do
    it "handles real Ruby error messages" do
      # Simulating actual Ruby error formats
      messages = {
        syntax_error: "syntax error, unexpected '}' expecting 'end'",
        name_error: "undefined local variable or method `user_name'",
        no_method_error: "undefined method `upcase' for an instance of String",
        type_error: "no implicit conversion of String into Integer",
        argument_error: "wrong number of arguments (given 1, expected 2)"
      }

      messages.each do |type, msg|
        details = parser.parse_error_details(type, msg)
        expect(details).not_to be_empty
      end
    end

    it "combines location extraction with error parsing" do
      msg = "file.rb:42: undefined local variable or method `missing'"
      location = parser.extract_location(msg, nil)
      details = parser.parse_error_details(:name_error, msg)

      expect(location[:line]).to eq(42)
      expect(details[:undefined_name]).to eq("missing")
    end
  end

  describe "private parsing methods" do
    describe "#parse_name_error" do
      it "extracts undefined name" do
        msg = "undefined local variable or method `my_var'"
        result = parser.send(:parse_name_error, msg)

        expect(result[:undefined_name]).to eq("my_var")
      end
    end

    describe "#parse_no_method_error" do
      it "extracts method and receiver" do
        msg = "undefined method `foo' for an instance of Hash"
        result = parser.send(:parse_no_method_error, msg)

        expect(result[:undefined_method]).to eq("foo")
        expect(result[:receiver_class]).to eq("Hash")
      end
    end

    describe "#parse_type_error" do
      it "handles both patterns" do
        msg1 = "no implicit conversion of Integer into String"
        msg2 = "Float can't be coerced into Array"

        result1 = parser.send(:parse_type_error, msg1)
        result2 = parser.send(:parse_type_error, msg2)

        expect(result1[:from_type]).to eq("Integer")
        expect(result2[:from_type]).to eq("Float")
      end
    end

    describe "#parse_argument_error" do
      it "converts counts to integers" do
        msg = "wrong number of arguments (given 5, expected 3)"
        result = parser.send(:parse_argument_error, msg)

        expect(result[:given]).to be_a(Integer)
        expect(result[:expected]).to be_a(String)
      end
    end

    describe "#parse_syntax_error" do
      it "extracts both unexpected and expecting" do
        msg = "syntax error, unexpected '}' expecting 'end'"
        result = parser.send(:parse_syntax_error, msg)

        expect(result).to have_key(:unexpected)
        expect(result).to have_key(:expecting)
      end
    end
  end
end
