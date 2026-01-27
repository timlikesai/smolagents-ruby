require "spec_helper"

RSpec.describe Smolagents::Concerns::MixtureOfAgents::ResultSynthesis do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::MixtureOfAgents::ResultSynthesis
    end
  end

  let(:synthesizer) { test_class.new }

  let(:proposals) do
    [
      Smolagents::Types::Proposal.new(
        proposer_name: "proposer_0",
        task: "Test task",
        result: "Answer A",
        reasoning: "Reasoning A",
        confidence: 0.9,
        duration_ms: 100,
        metadata: {}
      ),
      Smolagents::Types::Proposal.new(
        proposer_name: "proposer_1",
        task: "Test task",
        result: "Answer B",
        reasoning: "Reasoning B",
        confidence: 0.7,
        duration_ms: 150,
        metadata: {}
      )
    ]
  end

  describe "#build_moa_result" do
    context "with AggregationResult (voting)" do
      let(:voting_result) do
        Smolagents::Types::AggregationResult.from_voting(proposals)
      end

      it "returns a RunResult" do
        result = synthesizer.build_moa_result(voting_result, proposals, 500)

        expect(result).to be_a(Smolagents::Types::RunResult)
      end

      it "extracts final_answer as output" do
        result = synthesizer.build_moa_result(voting_result, proposals, 500)

        expect(result.output).to eq("Answer A") # Highest confidence
      end

      it "sets state to :success for AggregationResult" do
        result = synthesizer.build_moa_result(voting_result, proposals, 500)

        expect(result.state).to eq(:success)
        expect(result.success?).to be true
      end

      it "creates action steps from proposals" do
        result = synthesizer.build_moa_result(voting_result, proposals, 500)

        expect(result.steps.size).to eq(2)
        result.steps.each_with_index do |step, idx|
          expect(step).to be_a(Smolagents::Types::ActionStep)
          expect(step.step_number).to eq(idx + 1)
        end
      end

      it "includes proposal info in step observations" do
        result = synthesizer.build_moa_result(voting_result, proposals, 500)

        expect(result.steps[0].observations).to include("proposer_0")
        expect(result.steps[0].observations).to include("Answer A")
        expect(result.steps[1].observations).to include("proposer_1")
        expect(result.steps[1].observations).to include("Answer B")
      end

      it "creates proper Timing from duration_ms" do
        result = synthesizer.build_moa_result(voting_result, proposals, 1500)

        expect(result.timing).to be_a(Smolagents::Types::Timing)
        expect(result.timing.duration).to be_within(0.1).of(1.5)
      end
    end

    context "with AggregationResult (synthesis)" do
      let(:synthesis_result) do
        Smolagents::Types::AggregationResult.from_synthesis(
          proposals,
          "Synthesized answer combining insights from both proposals",
          "Combined the strengths of A and B"
        )
      end

      it "extracts synthesized final_answer as output" do
        result = synthesizer.build_moa_result(synthesis_result, proposals, 800)

        expect(result.output).to eq("Synthesized answer combining insights from both proposals")
      end

      it "sets state to :success" do
        result = synthesizer.build_moa_result(synthesis_result, proposals, 800)

        expect(result.state).to eq(:success)
      end
    end

    context "with single Proposal" do
      let(:single_proposal) { proposals.first }

      it "extracts result from Proposal" do
        result = synthesizer.build_moa_result(single_proposal, proposals, 300)

        expect(result.output).to eq("Answer A")
      end

      it "sets state based on proposal confidence for high confidence" do
        high_conf_proposal = Smolagents::Types::Proposal.new(
          proposer_name: "proposer_0",
          task: "Test",
          result: "High confidence answer",
          reasoning: nil,
          confidence: 0.85,
          duration_ms: 100,
          metadata: {}
        )

        result = synthesizer.build_moa_result(high_conf_proposal, [high_conf_proposal], 300)

        expect(result.state).to eq(:success)
      end

      it "sets state to :partial for low confidence proposals" do
        low_conf_proposal = Smolagents::Types::Proposal.new(
          proposer_name: "proposer_0",
          task: "Test",
          result: "Low confidence answer",
          reasoning: nil,
          confidence: 0.5,
          duration_ms: 100,
          metadata: {}
        )

        result = synthesizer.build_moa_result(low_conf_proposal, [low_conf_proposal], 300)

        expect(result.state).to eq(:partial)
      end
    end

    context "with raw value" do
      it "uses raw value as output" do
        result = synthesizer.build_moa_result("Raw string result", proposals, 200)

        expect(result.output).to eq("Raw string result")
      end
    end

    context "with empty proposals" do
      it "sets state to :error" do
        result = synthesizer.build_moa_result("Result", [], 100)

        expect(result.state).to eq(:error)
      end

      it "returns empty steps array" do
        result = synthesizer.build_moa_result("Result", [], 100)

        expect(result.steps).to be_empty
      end
    end

    describe "step truncation" do
      let(:long_result_proposal) do
        Smolagents::Types::Proposal.new(
          proposer_name: "proposer_0",
          task: "Test",
          result: "A" * 1000, # Very long result
          reasoning: nil,
          confidence: 0.8,
          duration_ms: 100,
          metadata: {}
        )
      end

      it "truncates long results in step observations" do
        result = synthesizer.build_moa_result(
          Smolagents::Types::AggregationResult.from_voting([long_result_proposal]),
          [long_result_proposal],
          300
        )

        # Should be truncated to 500 chars max
        expect(result.steps.first.observations.length).to be <= 550 # With prefix
      end
    end

    describe "timing calculation" do
      it "calculates start_time from end_time minus duration" do
        before_call = Time.now
        result = synthesizer.build_moa_result(
          Smolagents::Types::AggregationResult.from_voting(proposals),
          proposals,
          2000
        )
        after_call = Time.now

        expect(result.timing.end_time).to be_between(before_call, after_call)
        expect(result.timing.start_time).to be < result.timing.end_time
        expect(result.timing.duration).to be_within(0.1).of(2.0)
      end

      it "handles zero duration" do
        result = synthesizer.build_moa_result(
          Smolagents::Types::AggregationResult.from_voting(proposals),
          proposals,
          0
        )

        expect(result.timing.duration).to be_within(0.01).of(0)
      end
    end

    describe "token usage" do
      it "returns nil token_usage (not aggregated)" do
        result = synthesizer.build_moa_result(
          Smolagents::Types::AggregationResult.from_voting(proposals),
          proposals,
          500
        )

        expect(result.token_usage).to be_nil
      end
    end
  end

  describe "pattern matching on aggregation_result" do
    it "matches AggregationResult type" do
      voting_result = Smolagents::Types::AggregationResult.from_voting(proposals)

      matched = case voting_result
                in Smolagents::Types::AggregationResult
                  true
                else
                  false
                end

      expect(matched).to be true
    end

    it "matches Proposal type" do
      matched = case proposals.first
                in Smolagents::Types::Proposal
                  true
                else
                  false
                end

      expect(matched).to be true
    end
  end

  describe "step numbering" do
    let(:many_proposals) do
      (0..4).map do |idx|
        Smolagents::Types::Proposal.new(
          proposer_name: "proposer_#{idx}",
          task: "Test",
          result: "Answer #{idx}",
          reasoning: nil,
          confidence: 0.5 + (idx * 0.1),
          duration_ms: 100,
          metadata: {}
        )
      end
    end

    it "numbers steps sequentially starting from 1" do
      result = synthesizer.build_moa_result(
        Smolagents::Types::AggregationResult.from_voting(many_proposals),
        many_proposals,
        500
      )

      expect(result.steps.map(&:step_number)).to eq([1, 2, 3, 4, 5])
    end
  end
end
