require "smolagents"

RSpec.describe Smolagents::Types::SummaryStep do
  let(:step) do
    described_class.create(
      summary: "Searched for Ruby docs and found v3.3 release notes",
      original_step_range: 0..4,
      original_step_count: 5,
      tokens_saved: 1200
    )
  end

  it_behaves_like "a step type", message_count: 1 do
    let(:step) { described_class.create(summary: "Summary text") }
  end

  describe ".create" do
    it "creates a summary step with all attributes" do
      expect(step.summary).to eq("Searched for Ruby docs and found v3.3 release notes")
      expect(step.original_step_range).to eq(0..4)
      expect(step.original_step_count).to eq(5)
      expect(step.tokens_saved).to eq(1200)
    end

    it "defaults original_step_range to nil" do
      minimal = described_class.create(summary: "Brief summary")
      expect(minimal.original_step_range).to be_nil
    end

    it "defaults original_step_count to 0" do
      minimal = described_class.create(summary: "Brief summary")
      expect(minimal.original_step_count).to eq(0)
    end

    it "defaults tokens_saved to 0" do
      minimal = described_class.create(summary: "Brief summary")
      expect(minimal.tokens_saved).to eq(0)
    end
  end

  describe "#to_messages" do
    it "returns a single assistant message" do
      messages = step.to_messages
      expect(messages.size).to eq(1)
      expect(messages.first).to be_a(Smolagents::ChatMessage)
    end

    it "formats content with step count and summary" do
      message = step.to_messages.first
      expect(message.role).to eq(:assistant)
      expect(message.content).to eq("[Summary of 5 steps] Searched for Ruby docs and found v3.3 release notes")
    end

    it "uses 0 in prefix when no step count provided" do
      minimal = described_class.create(summary: "Short summary")
      message = minimal.to_messages.first
      expect(message.content).to eq("[Summary of 0 steps] Short summary")
    end
  end

  describe "#to_h" do
    it "returns hash with type and all fields" do
      result = step.to_h
      expect(result[:type]).to eq(:summary)
      expect(result[:summary]).to eq("Searched for Ruby docs and found v3.3 release notes")
      expect(result[:original_step_range]).to eq("0..4")
      expect(result[:original_step_count]).to eq(5)
      expect(result[:tokens_saved]).to eq(1200)
    end

    it "converts step range to string" do
      expect(step.to_h[:original_step_range]).to eq("0..4")
    end

    it "returns nil for original_step_range when not set" do
      minimal = described_class.create(summary: "No range")
      expect(minimal.to_h[:original_step_range]).to be_nil
    end
  end

  describe "#deconstruct_keys" do
    it "returns hash with all fields" do
      result = step.deconstruct_keys(nil)
      expect(result[:summary]).to eq("Searched for Ruby docs and found v3.3 release notes")
      expect(result[:original_step_range]).to eq(0..4)
      expect(result[:original_step_count]).to eq(5)
      expect(result[:tokens_saved]).to eq(1200)
    end
  end

  describe "pattern matching" do
    it "matches on summary" do
      matched = case step
                in { summary: s }
                  s
                else
                  "no match"
                end

      expect(matched).to eq("Searched for Ruby docs and found v3.3 release notes")
    end

    it "supports conditional matching on tokens_saved" do
      matched = case step
                in { tokens_saved: (1000..) } then "significant savings"
                in { tokens_saved: (1..999) } then "minor savings"
                else "no savings"
                end

      expect(matched).to eq("significant savings")
    end
  end
end
