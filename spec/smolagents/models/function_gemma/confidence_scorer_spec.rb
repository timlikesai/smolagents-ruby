require "spec_helper"

RSpec.describe Smolagents::Models::FunctionGemma::ConfidenceScorer do
  let(:tool_call) { Smolagents::Types::ToolCall.new(name: "search", arguments: { "query" => "test" }, id: "tc_1") }
  let(:speculative_call) { Smolagents::Types::SpeculativeToolCall.from_function_gemma(tool_call, confidence: 0.8) }

  # Mock tool with schema
  let(:search_tool) do
    Class.new(Smolagents::Tool) do
      self.tool_name = "search"
      self.description = "Search for things"
      self.inputs = { query: { type: "string", description: "Search query" } }
      self.output_type = "string"
      def execute(query:) = "results for #{query}"
    end.new
  end

  let(:calc_tool) do
    Class.new(Smolagents::Tool) do
      self.tool_name = "calc"
      self.description = "Calculate expression"
      self.inputs = {
        expression: { type: "string", description: "Expression", required: true },
        precision: { type: "integer", description: "Decimal places", required: false }
      }
      self.output_type = "string"
      def execute(expression:, precision: nil) = "42" # Mock result for testing
    end.new
  end

  let(:tools) { { "search" => search_tool, "calc" => calc_tool } }

  describe ".score" do
    context "valid tool with valid args" do
      it "returns high confidence" do
        result = described_class.score(speculative_call, tools)

        expect(result.valid_tool?).to be true
        expect(result.args_valid?).to be true
        expect(result.confidence).to be >= 0.8
        expect(result.high_confidence?).to be true
        expect(result.executable?).to be true
      end
    end

    context "unknown tool" do
      let(:tool_call) { Smolagents::Types::ToolCall.new(name: "unknown", arguments: {}, id: "tc_1") }

      it "returns low confidence and not executable" do
        result = described_class.score(speculative_call, tools)

        expect(result.valid_tool?).to be false
        expect(result.confidence).to be < 0.5
        expect(result.executable?).to be false
      end
    end

    context "missing required args" do
      let(:tool_call) { Smolagents::Types::ToolCall.new(name: "calc", arguments: {}, id: "tc_1") }

      it "penalizes confidence for each missing arg" do
        result = described_class.score(speculative_call, tools)

        expect(result.missing_args).to include("expression")
        expect(result.confidence).to be < speculative_call.confidence
      end
    end

    context "extra unknown args" do
      let(:tool_call) do
        Smolagents::Types::ToolCall.new(
          name: "search",
          arguments: { "query" => "test", "unknown_param" => "value" },
          id: "tc_1"
        )
      end

      it "identifies unknown args but still boosts for valid tool" do
        result = described_class.score(speculative_call, tools)

        expect(result.unknown_args).to eq(["unknown_param"])
        # Gets +0.15 boost for valid tool, -0.05 for unknown arg = net +0.10
        expect(result.confidence).to be > speculative_call.confidence
      end
    end

    context "type mismatches" do
      let(:tool_call) do
        Smolagents::Types::ToolCall.new(
          name: "calc",
          arguments: { "expression" => "2+2", "precision" => "not_a_number" },
          id: "tc_1"
        )
      end

      it "penalizes confidence for type mismatches" do
        result = described_class.score(speculative_call, tools)

        expect(result.type_mismatches).to include("precision")
        expect(result.confidence).to be < speculative_call.confidence
      end
    end

    context "valid integer type" do
      let(:tool_call) do
        Smolagents::Types::ToolCall.new(
          name: "calc",
          arguments: { "expression" => "2+2", "precision" => "3" },
          id: "tc_1"
        )
      end

      it "accepts string representation of integer" do
        result = described_class.score(speculative_call, tools)

        expect(result.type_mismatches).to be_empty
      end
    end
  end

  describe ".rescore" do
    it "returns new SpeculativeToolCall with boosted confidence for valid call" do
      rescored = described_class.rescore(speculative_call, tools)

      expect(rescored).to be_a(Smolagents::Types::SpeculativeToolCall)
      expect(rescored.tool_call).to eq(speculative_call.tool_call)
      # Valid tool + valid args gets +0.15 boost
      expect(rescored.confidence).to be > speculative_call.confidence
      expect(rescored.high_confidence?).to be true
    end

    context "with unknown tool" do
      let(:tool_call) { Smolagents::Types::ToolCall.new(name: "nonexistent", arguments: {}, id: "tc_1") }

      it "returns call with reduced confidence" do
        rescored = described_class.rescore(speculative_call, tools)

        expect(rescored.confidence).to be < speculative_call.confidence
        expect(rescored.executable?).to be false
      end
    end
  end

  describe "ScoreResult" do
    describe "#confidence" do
      it "clamps to 0.0-1.0 range" do
        result = Smolagents::Models::FunctionGemma::ConfidenceScorer::ScoreResult.new(
          base_confidence: 0.5,
          tool_exists: false, # -0.4
          required_args_present: false,
          unknown_args: %w[a b c d e], # -0.25
          missing_args: %w[x y], # -0.30
          type_mismatches: []
        )

        expect(result.confidence).to eq(0.0) # Clamped
      end
    end
  end
end
