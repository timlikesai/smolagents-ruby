require "spec_helper"

RSpec.describe Smolagents::Models::FunctionGemma::Parser do
  describe ".parse" do
    context "happy path - valid function calls" do
      it "parses single function call with one parameter" do
        output = "<start_function_call>call:get_weather{location:<escape>London<escape>}<end_function_call>"
        calls = described_class.parse(output)

        expect(calls.size).to eq(1)
        expect(calls.first.name).to eq("get_weather")
        expect(calls.first.arguments).to eq({ "location" => "London" })
        expect(calls.first.id).to start_with("fg_call_")
      end

      it "parses function call with multiple parameters" do
        output = "<start_function_call>call:search{query:<escape>Ruby gems<escape>,limit:<escape>10<escape>}<end_function_call>"
        calls = described_class.parse(output)

        expect(calls.size).to eq(1)
        expect(calls.first.arguments).to eq({
          "query" => "Ruby gems",
          "limit" => "10"
        })
      end

      it "parses function call with no parameters" do
        output = "<start_function_call>call:list_tools{}<end_function_call>"
        calls = described_class.parse(output)

        expect(calls.size).to eq(1)
        expect(calls.first.name).to eq("list_tools")
        expect(calls.first.arguments).to eq({})
      end

      it "parses multiple function calls from one output" do
        output = <<~OUTPUT
          <start_function_call>call:search{q:<escape>weather<escape>}<end_function_call>
          <start_function_call>call:format{style:<escape>json<escape>}<end_function_call>
        OUTPUT
        calls = described_class.parse(output)

        expect(calls.size).to eq(2)
        expect(calls.map(&:name)).to eq(%w[search format])
      end

      it "handles values containing colons" do
        output = "<start_function_call>call:fetch{url:<escape>https://example.com<escape>}<end_function_call>"
        calls = described_class.parse(output)

        expect(calls.first.arguments["url"]).to eq("https://example.com")
      end

      it "handles values containing commas inside escape tags" do
        output = "<start_function_call>call:log{msg:<escape>a, b, c<escape>}<end_function_call>"
        calls = described_class.parse(output)

        expect(calls.first.arguments["msg"]).to eq("a, b, c")
      end

      it "handles whitespace variations" do
        output = "<start_function_call>call:search{ query : <escape>test<escape> }<end_function_call>"
        calls = described_class.parse(output)

        expect(calls.first.arguments["query"]).to eq("test")
      end

      it "ignores plain text mixed with function calls" do
        output = "I think we should call <start_function_call>call:search{q:<escape>test<escape>}<end_function_call> to find it"
        calls = described_class.parse(output)

        expect(calls.size).to eq(1)
        expect(calls.first.name).to eq("search")
      end

      it "generates unique IDs for each call" do
        output = <<~OUTPUT
          <start_function_call>call:a{}<end_function_call>
          <start_function_call>call:b{}<end_function_call>
        OUTPUT
        calls = described_class.parse(output)

        expect(calls[0].id).not_to eq(calls[1].id)
        expect(calls.all? { |c| c.id.start_with?("fg_call_") }).to be true
      end
    end

    context "sad path - malformed input" do
      it "returns empty array for nil input" do
        expect(described_class.parse(nil)).to eq([])
      end

      it "returns empty array for empty string" do
        expect(described_class.parse("")).to eq([])
      end

      it "returns empty array for output with no function calls" do
        expect(described_class.parse("Just regular text")).to eq([])
      end

      it "returns empty array for missing end tag" do
        output = "<start_function_call>call:search{q:<escape>test<escape>}"
        expect(described_class.parse(output)).to eq([])
      end

      it "skips calls without call: prefix" do
        output = "<start_function_call>search{q:<escape>test<escape>}<end_function_call>"
        expect(described_class.parse(output)).to eq([])
      end

      it "skips calls with empty function name" do
        output = "<start_function_call>call:{}<end_function_call>"
        expect(described_class.parse(output)).to eq([])
      end

      it "handles partial output gracefully" do
        output = "<start_function_call>call:first{}<end_function_call><start_function_call>call:incomplete"
        calls = described_class.parse(output)

        expect(calls.size).to eq(1)
        expect(calls.first.name).to eq("first")
      end
    end
  end

  describe ".parse_single" do
    it "parses a valid call block" do
      call = described_class.parse_single("call:test{x:<escape>1<escape>}")

      expect(call.name).to eq("test")
      expect(call.arguments).to eq({ "x" => "1" })
    end

    it "returns nil for malformed block" do
      expect(described_class.parse_single("invalid")).to be_nil
    end

    it "handles function name without parameters" do
      call = described_class.parse_single("call:simple")

      expect(call.name).to eq("simple")
      expect(call.arguments).to eq({})
    end
  end

  describe ".parse_speculative" do
    it "wraps calls in SpeculativeToolCall with confidence" do
      output = "<start_function_call>call:search{q:<escape>test<escape>}<end_function_call>"
      results = described_class.parse_speculative(output)

      expect(results.size).to eq(1)
      expect(results.first).to be_a(Smolagents::Types::SpeculativeToolCall)
      expect(results.first.confidence).to be_between(0.0, 1.0)
      expect(results.first.source).to eq(:function_gemma)
      expect(results.first.speculative).to be true
    end

    it "uses provided base confidence" do
      output = "<start_function_call>call:search{q:<escape>x<escape>}<end_function_call>"
      results = described_class.parse_speculative(output, base_confidence: 0.9)

      expect(results.first.confidence).to eq(0.9)
    end

    it "reduces confidence for empty arguments (non list_tools)" do
      output = "<start_function_call>call:random_func{}<end_function_call>"
      results = described_class.parse_speculative(output, base_confidence: 0.8)

      expect(results.first.confidence).to be < 0.8
    end

    it "maintains confidence for list_tools with empty args" do
      output = "<start_function_call>call:list_tools{}<end_function_call>"
      results = described_class.parse_speculative(output, base_confidence: 0.8)

      expect(results.first.confidence).to eq(0.8)
    end

    it "slightly reduces confidence for subsequent calls in parallel" do
      output = <<~OUTPUT
        <start_function_call>call:first{}<end_function_call>
        <start_function_call>call:second{}<end_function_call>
      OUTPUT
      results = described_class.parse_speculative(output, base_confidence: 0.8)

      expect(results[0].confidence).to be > results[1].confidence
    end
  end
end
