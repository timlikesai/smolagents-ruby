require "spec_helper"

RSpec.describe Smolagents::Concerns::ObservationRouter::RoutingResult do
  let(:summary_result) do
    described_class.new(
      decision: :summary_only,
      summary: "Found relevant information",
      relevance: 0.9,
      next_action: "Call final_answer",
      full_output: nil
    )
  end

  let(:full_output_result) do
    described_class.new(
      decision: :full_output,
      summary: "Complex data returned",
      relevance: 0.7,
      next_action: "Examine the details",
      full_output: "Full raw output here"
    )
  end

  let(:retry_result) do
    described_class.new(
      decision: :needs_retry,
      summary: "Wrong results returned",
      relevance: 0.2,
      next_action: "Try a more specific query",
      full_output: nil
    )
  end

  let(:irrelevant_result) do
    described_class.new(
      decision: :irrelevant,
      summary: "Nothing useful found",
      relevance: 0.0,
      next_action: "Try web_search instead",
      full_output: nil
    )
  end

  describe "predicate methods" do
    it "#summary_only? returns true for summary_only decision" do
      expect(summary_result.summary_only?).to be true
      expect(full_output_result.summary_only?).to be false
    end

    it "#needs_full_output? returns true for full_output decision" do
      expect(full_output_result.needs_full_output?).to be true
      expect(summary_result.needs_full_output?).to be false
    end

    it "#needs_retry? returns true for needs_retry decision" do
      expect(retry_result.needs_retry?).to be true
      expect(summary_result.needs_retry?).to be false
    end

    it "#irrelevant? returns true for irrelevant decision" do
      expect(irrelevant_result.irrelevant?).to be true
      expect(summary_result.irrelevant?).to be false
    end
  end

  describe "#to_observation" do
    it "includes decision and summary" do
      obs = summary_result.to_observation
      expect(obs).to include("[SUMMARY_ONLY]")
      expect(obs).to include("Found relevant information")
    end

    it "includes suggested next action when present" do
      obs = summary_result.to_observation
      expect(obs).to include("Suggested: Call final_answer")
    end

    it "includes full output for full_output decisions" do
      obs = full_output_result.to_observation
      expect(obs).to include("Full output:")
      expect(obs).to include("Full raw output here")
    end

    it "excludes full output for summary_only decisions" do
      obs = summary_result.to_observation
      expect(obs).not_to include("Full output:")
    end
  end

  describe ".passthrough" do
    it "creates a full_output result with output length in summary" do
      result = described_class.passthrough("some output data")

      expect(result.decision).to eq(:full_output)
      expect(result.summary).to include("16 characters")
      expect(result.full_output).to eq("some output data")
    end
  end
end

RSpec.describe Smolagents::Concerns::ObservationRouter::VALID_DECISIONS do
  it "contains all valid decision types" do
    expect(described_class).to contain_exactly(
      :summary_only, :full_output, :needs_retry, :irrelevant
    )
  end
end
