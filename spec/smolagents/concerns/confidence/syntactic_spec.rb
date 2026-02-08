require "smolagents"

RSpec.describe Smolagents::Concerns::Confidence::Syntactic do
  # Create a simple test tool for validation
  let(:test_tool) do
    Class.new(Smolagents::Tool) do
      self.tool_name = "search"
      self.description = "Search for information"
      self.inputs = {
        query: { type: "string", description: "Search query", required: true }
      }
      self.output_type = "string"

      def execute(query:)
        "Result for: #{query}"
      end
    end.new
  end

  let(:tools) { { "search" => test_tool } }

  describe ".score" do
    context "with valid tool call" do
      let(:tool_call) do
        Smolagents::Types::SpeculativeToolCall.from_function_gemma(
          Smolagents::Types::ToolCall.new(
            name: "search",
            arguments: { query: "Ruby" },
            id: "call_1"
          ),
          confidence: 0.8
        )
      end

      it "returns ConfidenceEstimate" do
        result = described_class.score(tool_call, tools)

        expect(result).to be_a(Smolagents::Types::ConfidenceEstimate)
      end

      it "returns higher confidence for valid tool" do
        result = described_class.score(tool_call, tools)

        expect(result.blended).to be > 0.5
      end

      it "includes tool_exists in factors" do
        result = described_class.score(tool_call, tools)

        expect(result.factors[:tool_exists]).to be true
      end

      it "includes args_valid in factors" do
        result = described_class.score(tool_call, tools)

        expect(result.factors[:args_valid]).to be true
      end
    end

    context "with missing tool" do
      let(:tool_call) do
        Smolagents::Types::SpeculativeToolCall.from_function_gemma(
          Smolagents::Types::ToolCall.new(
            name: "nonexistent_tool",
            arguments: {},
            id: "call_2"
          ),
          confidence: 0.6
        )
      end

      it "returns lower confidence for missing tool" do
        result = described_class.score(tool_call, tools)

        expect(result.blended).to be < 0.5
      end

      it "includes tool_exists: false in factors" do
        result = described_class.score(tool_call, tools)

        expect(result.factors[:tool_exists]).to be false
      end
    end

    context "with missing required arguments" do
      let(:tool_call) do
        Smolagents::Types::SpeculativeToolCall.from_function_gemma(
          Smolagents::Types::ToolCall.new(
            name: "search",
            arguments: {}, # Missing required 'query' arg
            id: "call_3"
          ),
          confidence: 0.7
        )
      end

      it "returns lower confidence for missing args" do
        valid_call = Smolagents::Types::SpeculativeToolCall.from_function_gemma(
          Smolagents::Types::ToolCall.new(
            name: "search",
            arguments: { query: "test" },
            id: "call_valid"
          ),
          confidence: 0.7
        )

        valid_result = described_class.score(valid_call, tools)
        invalid_result = described_class.score(tool_call, tools)

        expect(invalid_result.blended).to be < valid_result.blended
      end

      it "includes missing_args in factors" do
        result = described_class.score(tool_call, tools)

        expect(result.factors[:missing_args]).to include("query")
      end
    end

    context "with plain tool call (not speculative)" do
      let(:plain_call) do
        Smolagents::Types::ToolCall.new(
          name: "search",
          arguments: { query: "test" },
          id: "call_plain"
        )
      end

      it "wraps call and scores it" do
        result = described_class.score(plain_call, tools)

        expect(result).to be_a(Smolagents::Types::ConfidenceEstimate)
        expect(result.blended).to be > 0
      end
    end

    context "with type mismatches" do
      let(:tool_with_int) do
        Class.new(Smolagents::Tool) do
          self.tool_name = "calculate"
          self.description = "Calculate expression"
          self.inputs = {
            value: { type: "integer", description: "Value", required: true }
          }
          self.output_type = "string"

          def execute(value:) = value.to_s
        end.new
      end

      let(:tools_with_int) { { "calculate" => tool_with_int } }

      let(:mistyped_call) do
        Smolagents::Types::SpeculativeToolCall.from_function_gemma(
          Smolagents::Types::ToolCall.new(
            name: "calculate",
            arguments: { value: "not_an_integer" },
            id: "call_mistype"
          ),
          confidence: 0.8
        )
      end

      it "includes type_mismatches in factors" do
        result = described_class.score(mistyped_call, tools_with_int)

        # type_mismatches contains symbols, not strings
        expect(result.factors[:type_mismatches]).to include(:value)
      end
    end
  end

  describe "syntactic-only scoring" do
    it "produces estimates without semantic component" do
      call = Smolagents::Types::SpeculativeToolCall.from_function_gemma(
        Smolagents::Types::ToolCall.new(name: "search", arguments: { query: "x" }, id: "1"),
        confidence: 0.8
      )

      result = described_class.score(call, tools)

      expect(result.semantic?).to be false
    end
  end
end
