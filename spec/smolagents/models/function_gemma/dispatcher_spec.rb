require "spec_helper"

RSpec.describe Smolagents::Models::FunctionGemma::Dispatcher do
  let(:search_tool) do
    Class.new(Smolagents::Tool) do
      self.tool_name = "search"
      self.description = "Search for things"
      self.inputs = { query: { type: "string", description: "Search query" } }
      self.output_type = "string"
      def execute(query:) = "results for #{query}"
    end.new
  end

  let(:tools) { { "search" => search_tool } }

  describe ".dispatch" do
    context "high confidence call" do
      let(:output) { "<start_function_call>call:search{query:<escape>test<escape>}<end_function_call>" }

      it "returns execute action" do
        result = described_class.dispatch(output, tools:)

        expect(result.execute?).to be true
        expect(result.has_calls?).to be true
        expect(result.tool_calls.first.name).to eq("search")
      end
    end

    context "unknown tool" do
      let(:output) { "<start_function_call>call:nonexistent{}<end_function_call>" }

      it "returns delegate action" do
        result = described_class.dispatch(output, tools:)

        expect(result.delegate?).to be true
        expect(result.reason).to include("Low confidence")
      end
    end

    context "no tool calls parsed" do
      let(:output) { "Just regular text with no function calls" }

      it "returns delegate action with reason" do
        result = described_class.dispatch(output, tools:)

        expect(result.delegate?).to be true
        expect(result.reason).to include("No tool calls parsed")
        expect(result.has_calls?).to be false
      end
    end

    context "multiple calls with mixed confidence" do
      let(:output) do
        <<~OUTPUT
          <start_function_call>call:search{query:<escape>test<escape>}<end_function_call>
          <start_function_call>call:unknown{}<end_function_call>
        OUTPUT
      end

      it "routes based on lowest confidence (conservative)" do
        result = described_class.dispatch(output, tools:)

        # Unknown tool tanks confidence, so should delegate
        expect(result.delegate?).to be true
      end
    end

    context "custom config thresholds" do
      let(:output) { "<start_function_call>call:search{query:<escape>x<escape>}<end_function_call>" }

      it "respects custom high confidence threshold" do
        config = described_class::Config.new(
          high_confidence_threshold: 0.95, # Very high
          low_confidence_threshold: 0.5,
          max_parallel_calls: 3
        )
        result = described_class.dispatch(output, tools:, config:)

        # Default FunctionGemma base confidence is 0.7, won't meet 0.95
        expect(result.validate?).to be true
      end
    end

    context "limits parallel calls" do
      let(:output) do
        (1..5).map { |i| "<start_function_call>call:search{query:<escape>q#{i}<escape>}<end_function_call>" }.join
      end

      it "limits to max_parallel_calls" do
        config = described_class::Config.new(
          high_confidence_threshold: 0.8,
          low_confidence_threshold: 0.5,
          max_parallel_calls: 2
        )
        result = described_class.dispatch(output, tools:, config:)

        expect(result.tool_calls.size).to eq(2)
      end
    end
  end

  describe ".executable_calls" do
    context "high confidence" do
      let(:output) { "<start_function_call>call:search{query:<escape>test<escape>}<end_function_call>" }

      it "returns executable calls" do
        calls = described_class.executable_calls(output, tools:)

        expect(calls.size).to eq(1)
        expect(calls.first.name).to eq("search")
        expect(calls.first.executable?).to be true
      end
    end

    context "low confidence" do
      let(:output) { "<start_function_call>call:unknown{}<end_function_call>" }

      it "returns empty array" do
        calls = described_class.executable_calls(output, tools:)

        expect(calls).to be_empty
      end
    end
  end

  describe ".high_confidence?" do
    context "valid known tool" do
      let(:output) { "<start_function_call>call:search{query:<escape>test<escape>}<end_function_call>" }

      it "returns true" do
        expect(described_class.high_confidence?(output, tools:)).to be true
      end
    end

    context "unknown tool" do
      let(:output) { "<start_function_call>call:unknown{}<end_function_call>" }

      it "returns false" do
        expect(described_class.high_confidence?(output, tools:)).to be false
      end
    end

    context "no calls" do
      let(:output) { "no function calls here" }

      it "returns false" do
        expect(described_class.high_confidence?(output, tools:)).to be false
      end
    end
  end

  describe "Config" do
    describe ".default" do
      it "provides sensible defaults" do
        config = described_class::Config.default

        expect(config.high_confidence_threshold).to eq(0.8)
        expect(config.low_confidence_threshold).to eq(0.5)
        expect(config.max_parallel_calls).to eq(3)
      end
    end
  end

  describe "DispatchResult" do
    let(:call) do
      tc = Smolagents::Types::ToolCall.new(name: "search", arguments: {}, id: "1")
      Smolagents::Types::SpeculativeToolCall.from_function_gemma(tc)
    end

    it "provides action predicates" do
      result = described_class::DispatchResult.new(
        action: :execute,
        tool_calls: [call],
        reason: "test"
      )

      expect(result.execute?).to be true
      expect(result.validate?).to be false
      expect(result.delegate?).to be false
      expect(result.has_calls?).to be true
    end
  end
end
