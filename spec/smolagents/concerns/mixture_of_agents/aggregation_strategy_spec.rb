# rubocop:disable RSpec/MessageSpies, Smolagents/NoTimingAssertion
require "spec_helper"

RSpec.describe Smolagents::Concerns::MixtureOfAgents::AggregationStrategy do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Events::Consumer
      include Smolagents::Concerns::MixtureOfAgents::AggregationStrategy
    end
  end

  let(:aggregator_class) { test_class.new }

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
      ),
      Smolagents::Types::Proposal.new(
        proposer_name: "proposer_2",
        task: "Test task",
        result: "Answer C",
        reasoning: "Reasoning C",
        confidence: 0.5,
        duration_ms: 200,
        metadata: {}
      )
    ]
  end

  describe "#aggregate_by_voting" do
    it "selects the highest confidence proposal" do
      result = aggregator_class.aggregate_by_voting(proposals)

      expect(result.final_answer).to eq("Answer A")
      expect(result.selected_proposal).to eq("proposer_0")
    end

    it "returns an AggregationResult" do
      result = aggregator_class.aggregate_by_voting(proposals)

      expect(result).to be_a(Smolagents::Types::AggregationResult)
    end

    it "sets strategy to :voting" do
      result = aggregator_class.aggregate_by_voting(proposals)

      expect(result.strategy).to eq(:voting)
      expect(result.voting?).to be true
    end

    it "includes all proposals in the result" do
      result = aggregator_class.aggregate_by_voting(proposals)

      expect(result.all_proposals).to eq(proposals)
      expect(result.proposal_count).to eq(3)
    end

    it "emits aggregation_completed event" do
      expect(aggregator_class).to receive(:emit).with(
        :aggregation_completed,
        hash_including(
          strategy: :voting,
          proposal_count: 3,
          selected_proposer: "proposer_0",
          duration_ms: kind_of(Integer)
        )
      )

      aggregator_class.aggregate_by_voting(proposals)
    end

    it "includes duration_ms in result" do
      result = aggregator_class.aggregate_by_voting(proposals)

      expect(result.duration_ms).to be_a(Integer)
      expect(result.duration_ms).to be >= 0
    end

    context "with proposals having nil confidence" do
      let(:proposals_with_nil) do
        [
          Smolagents::Types::Proposal.new(
            proposer_name: "proposer_0",
            task: "Test",
            result: "A",
            reasoning: nil,
            confidence: nil,
            duration_ms: 100,
            metadata: {}
          ),
          Smolagents::Types::Proposal.new(
            proposer_name: "proposer_1",
            task: "Test",
            result: "B",
            reasoning: nil,
            confidence: 0.5,
            duration_ms: 100,
            metadata: {}
          )
        ]
      end

      it "treats nil confidence as 0.0" do
        result = aggregator_class.aggregate_by_voting(proposals_with_nil)

        expect(result.selected_proposal).to eq("proposer_1")
        expect(result.final_answer).to eq("B")
      end
    end

    context "with empty proposals" do
      it "handles gracefully" do
        result = aggregator_class.aggregate_by_voting([])

        expect(result.final_answer).to be_nil
        expect(result.selected_proposal).to be_nil
      end
    end
  end

  describe "#aggregate_by_synthesis" do
    let(:mock_aggregator_agent) do
      agent = instance_double(Smolagents::Agents::Agent)
      allow(agent).to receive(:run).and_return(
        Smolagents::Types::RunResult.success(
          output: "Synthesized answer combining A, B, and C",
          steps: [
            Smolagents::Types::ActionStep.new(
              step_number: 1,
              observations: "Combined best elements from all proposals"
            )
          ]
        )
      )
      agent
    end

    it "uses aggregator agent to synthesize proposals" do
      result = aggregator_class.aggregate_by_synthesis(proposals, mock_aggregator_agent, "Test task")

      expect(result.final_answer).to eq("Synthesized answer combining A, B, and C")
    end

    it "returns an AggregationResult with synthesis strategy" do
      result = aggregator_class.aggregate_by_synthesis(proposals, mock_aggregator_agent, "Test task")

      expect(result).to be_a(Smolagents::Types::AggregationResult)
      expect(result.strategy).to eq(:synthesis)
      expect(result.synthesis?).to be true
    end

    it "does not select a specific proposal (synthesizes all)" do
      result = aggregator_class.aggregate_by_synthesis(proposals, mock_aggregator_agent, "Test task")

      expect(result.selected_proposal).to be_nil
    end

    it "includes synthesis reasoning from aggregator steps" do
      result = aggregator_class.aggregate_by_synthesis(proposals, mock_aggregator_agent, "Test task")

      expect(result.synthesis_reasoning).to include("Combined best elements")
    end

    it "passes formatted proposals to aggregator" do
      expect(mock_aggregator_agent).to receive(:run) do |prompt|
        expect(prompt).to include("**Original Task:** Test task")
        expect(prompt).to include("Proposal 1: proposer_0")
        expect(prompt).to include("Answer A")
        expect(prompt).to include("confidence: 90%")
        expect(prompt).to include("Proposal 2: proposer_1")
        expect(prompt).to include("Proposal 3: proposer_2")

        Smolagents::Types::RunResult.success(output: "Synthesized", steps: [])
      end

      aggregator_class.aggregate_by_synthesis(proposals, mock_aggregator_agent, "Test task")
    end

    it "emits aggregation_completed event" do
      expect(aggregator_class).to receive(:emit).with(
        :aggregation_completed,
        hash_including(strategy: :synthesis)
      )

      aggregator_class.aggregate_by_synthesis(proposals, mock_aggregator_agent, "Test task")
    end

    it "includes duration_ms in result" do
      result = aggregator_class.aggregate_by_synthesis(proposals, mock_aggregator_agent, "Test task")

      expect(result.duration_ms).to be_a(Integer)
    end
  end

  describe "#aggregate_by_rank_fusion" do
    let(:mock_ranking_agent) do
      agent = instance_double(Smolagents::Agents::Agent)
      allow(agent).to receive(:run).and_return(
        Smolagents::Types::RunResult.success(
          output: "Ranked synthesis: A is best, followed by B, then C",
          steps: [
            Smolagents::Types::ActionStep.new(
              step_number: 1,
              observations: "Ranking: 1. proposer_0 (excellent), 2. proposer_1 (good), 3. proposer_2 (fair)"
            )
          ]
        )
      )
      agent
    end

    it "uses aggregator to rank and synthesize proposals" do
      result = aggregator_class.aggregate_by_rank_fusion(proposals, mock_ranking_agent, "Test task")

      expect(result.final_answer).to include("Ranked synthesis")
    end

    it "returns an AggregationResult with rank_fusion strategy" do
      result = aggregator_class.aggregate_by_rank_fusion(proposals, mock_ranking_agent, "Test task")

      expect(result).to be_a(Smolagents::Types::AggregationResult)
      expect(result.strategy).to eq(:rank_fusion)
      expect(result.rank_fusion?).to be true
    end

    it "does not select a specific proposal" do
      result = aggregator_class.aggregate_by_rank_fusion(proposals, mock_ranking_agent, "Test task")

      expect(result.selected_proposal).to be_nil
    end

    it "includes ranking reasoning" do
      result = aggregator_class.aggregate_by_rank_fusion(proposals, mock_ranking_agent, "Test task")

      expect(result.synthesis_reasoning).to include("Ranking")
    end

    it "passes ranking prompt to aggregator" do
      expect(mock_ranking_agent).to receive(:run) do |prompt|
        expect(prompt).to include("Rank and evaluate")
        expect(prompt).to include("**Original Task:** Test task")
        expect(prompt).to include("Assign weights based on your rankings")

        Smolagents::Types::RunResult.success(output: "Ranked", steps: [])
      end

      aggregator_class.aggregate_by_rank_fusion(proposals, mock_ranking_agent, "Test task")
    end

    it "emits aggregation_completed event" do
      expect(aggregator_class).to receive(:emit).with(
        :aggregation_completed,
        hash_including(strategy: :rank_fusion)
      )

      aggregator_class.aggregate_by_rank_fusion(proposals, mock_ranking_agent, "Test task")
    end
  end

  describe "confidence estimate" do
    it "calculates average confidence across proposals for voting" do
      result = aggregator_class.aggregate_by_voting(proposals)

      # (0.9 + 0.7 + 0.5) / 3 = 0.7
      expect(result.confidence_estimate).to be_within(0.01).of(0.7)
    end
  end

  describe "proposal formatting" do
    it "formats proposals with confidence percentages" do
      mock_agent = instance_double(Smolagents::Agents::Agent)
      allow(mock_agent).to receive(:run) do |prompt|
        expect(prompt).to include("confidence: 90%")
        expect(prompt).to include("confidence: 70%")
        expect(prompt).to include("confidence: 50%")

        Smolagents::Types::RunResult.success(output: "Test", steps: [])
      end

      aggregator_class.aggregate_by_synthesis(proposals, mock_agent, "Task")
    end

    it "handles proposals without confidence" do
      proposals_no_confidence = [
        Smolagents::Types::Proposal.new(
          proposer_name: "proposer_0",
          task: "Test",
          result: "Answer",
          reasoning: nil,
          confidence: nil,
          duration_ms: 100,
          metadata: {}
        )
      ]

      mock_agent = instance_double(Smolagents::Agents::Agent)
      allow(mock_agent).to receive(:run) do |prompt|
        # Should not include confidence percentage for nil confidence
        expect(prompt).not_to include("confidence:")

        Smolagents::Types::RunResult.success(output: "Test", steps: [])
      end

      aggregator_class.aggregate_by_synthesis(proposals_no_confidence, mock_agent, "Task")
    end
  end

  describe "Events::Emitter integration" do
    it "includes Events::Emitter automatically" do
      expect(test_class.ancestors).to include(Smolagents::Events::Emitter)
    end
  end
end

# rubocop:enable RSpec/MessageSpies, Smolagents/NoTimingAssertion
