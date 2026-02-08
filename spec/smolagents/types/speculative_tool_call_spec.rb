require "spec_helper"

RSpec.describe Smolagents::Types::SpeculativeToolCall do
  let(:tool_call) { Smolagents::Types::ToolCall.new(name: "search", arguments: { "q" => "test" }, id: "tc_1") }

  describe "type behavior" do
    let(:instance) { described_class.new(tool_call:, confidence: 0.8, source: :function_gemma, speculative: true) }

    it_behaves_like "a frozen type"
    it_behaves_like "a pattern matchable type"
  end

  describe ".from_function_gemma" do
    it "creates speculative call with default confidence" do
      result = described_class.from_function_gemma(tool_call)

      expect(result.tool_call).to eq(tool_call)
      expect(result.confidence).to eq(0.7)
      expect(result.source).to eq(:function_gemma)
      expect(result.speculative).to be true
    end

    it "accepts custom confidence" do
      result = described_class.from_function_gemma(tool_call, confidence: 0.9)

      expect(result.confidence).to eq(0.9)
    end
  end

  describe ".from_primary" do
    it "creates validated non-speculative call" do
      result = described_class.from_primary(tool_call)

      expect(result.confidence).to eq(1.0)
      expect(result.source).to eq(:primary)
      expect(result.speculative).to be false
    end
  end

  describe "confidence predicates" do
    it "identifies high confidence" do
      high = described_class.new(tool_call:, confidence: 0.85, source: :test, speculative: true)
      low = described_class.new(tool_call:, confidence: 0.6, source: :test, speculative: true)

      expect(high.high_confidence?).to be true
      expect(low.high_confidence?).to be false
    end

    it "identifies low confidence" do
      low = described_class.new(tool_call:, confidence: 0.4, source: :test, speculative: true)
      medium = described_class.new(tool_call:, confidence: 0.6, source: :test, speculative: true)

      expect(low.low_confidence?).to be true
      expect(medium.low_confidence?).to be false
    end
  end

  describe "#needs_validation?" do
    it "returns true for speculative low-confidence calls" do
      call = described_class.new(tool_call:, confidence: 0.6, source: :test, speculative: true)

      expect(call.needs_validation?).to be true
    end

    it "returns false for high-confidence calls" do
      call = described_class.new(tool_call:, confidence: 0.9, source: :test, speculative: true)

      expect(call.needs_validation?).to be false
    end

    it "returns false for non-speculative calls" do
      call = described_class.new(tool_call:, confidence: 0.5, source: :primary, speculative: false)

      expect(call.needs_validation?).to be false
    end
  end

  describe "#executable?" do
    it "returns true for non-speculative calls" do
      call = described_class.new(tool_call:, confidence: 0.5, source: :primary, speculative: false)

      expect(call.executable?).to be true
    end

    it "returns true for high-confidence speculative calls" do
      call = described_class.new(tool_call:, confidence: 0.9, source: :test, speculative: true)

      expect(call.executable?).to be true
    end

    it "returns false for low-confidence speculative calls" do
      call = described_class.new(tool_call:, confidence: 0.6, source: :test, speculative: true)

      expect(call.executable?).to be false
    end
  end

  describe "delegation" do
    subject { described_class.new(tool_call:, confidence: 0.8, source: :test, speculative: true) }

    it "delegates name to tool_call" do
      expect(subject.name).to eq("search")
    end

    it "delegates arguments to tool_call" do
      expect(subject.arguments).to eq({ "q" => "test" })
    end

    it "delegates id to tool_call" do
      expect(subject.id).to eq("tc_1")
    end
  end

  describe "#validate" do
    it "returns non-speculative copy with boosted confidence" do
      call = described_class.new(tool_call:, confidence: 0.6, source: :test, speculative: true)
      validated = call.validate

      expect(validated.speculative).to be false
      expect(validated.confidence).to be >= 0.9
      expect(validated.source).to eq(:test)
      expect(validated.tool_call).to eq(tool_call)
    end

    it "preserves high confidence when already above threshold" do
      call = described_class.new(tool_call:, confidence: 0.95, source: :test, speculative: true)
      validated = call.validate

      expect(validated.confidence).to eq(0.95)
    end
  end

  describe "#to_h" do
    it "includes all metadata" do
      call = described_class.new(tool_call:, confidence: 0.85, source: :function_gemma, speculative: true)
      hash = call.to_h

      expect(hash[:tool_call]).to eq(tool_call.to_h)
      expect(hash[:confidence]).to eq(0.85)
      expect(hash[:source]).to eq(:function_gemma)
      expect(hash[:speculative]).to be true
    end
  end
end
