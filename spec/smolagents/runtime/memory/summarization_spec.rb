require "smolagents"

RSpec.describe Smolagents::Runtime::Memory::Summarization do
  let(:memory_class) do
    Class.new do
      include Smolagents::Runtime::Memory::Summarization

      attr_reader :steps, :config

      def initialize(config:)
        @steps = []
        @config = config
      end

      def estimated_tokens
        @steps.sum { |s| s.respond_to?(:observations) ? (s.observations&.length || 10) : 10 }
      end

      def action_steps
        @steps.select { |s| s.respond_to?(:step_number) && s.respond_to?(:observations) }
      end
    end
  end

  let(:summarize_config) do
    Smolagents::Types::MemoryConfig.new(
      budget: 100, strategy: :summarize, preserve_recent: 2,
      mask_placeholder: "[truncated]", compression_threshold: 0.75
    )
  end

  let(:full_config) do
    Smolagents::Types::MemoryConfig.new(
      budget: 100, strategy: :full, preserve_recent: 2,
      mask_placeholder: "[truncated]", compression_threshold: 0.75
    )
  end

  let(:model_response) do
    Smolagents::ChatMessage.assistant("Summary of observations")
  end

  let(:model) do
    instance_double(Smolagents::Models::Model).tap do |m|
      allow(m).to receive(:generate).and_return(model_response)
    end
  end

  def build_action_step(number, observations:)
    Smolagents::Types::ActionStep.new(step_number: number, observations:)
  end

  describe "#compress_if_needed!" do
    context "when strategy is :full" do
      it "does not compress" do
        memory = memory_class.new(config: full_config)
        5.times { |i| memory.steps << build_action_step(i, observations: "x" * 30) }

        result = memory.compress_if_needed!(model:)

        expect(result).to be_nil
        expect(model).not_to have_received(:generate)
      end
    end

    context "when under threshold" do
      it "does not compress" do
        memory = memory_class.new(config: summarize_config)
        memory.steps << build_action_step(0, observations: "short")

        result = memory.compress_if_needed!(model:)

        expect(result).to be_nil
        expect(model).not_to have_received(:generate)
      end
    end

    context "when over threshold with summarize strategy" do
      it "compresses oldest steps" do
        memory = memory_class.new(config: summarize_config)
        5.times { |i| memory.steps << build_action_step(i, observations: "x" * 30) }

        memory.compress_if_needed!(model:)

        action_count = memory.steps.count { |s| s.is_a?(Smolagents::Types::ActionStep) }
        summary_count = memory.steps.count { |s| s.is_a?(Smolagents::Types::SummaryStep) }
        expect(action_count).to eq(2)
        expect(summary_count).to eq(1)
      end
    end

    context "when compressible steps are empty" do
      it "returns nil" do
        memory = memory_class.new(config: summarize_config)
        # Only 2 steps with preserve_recent=2 means nothing to compress
        2.times { |i| memory.steps << build_action_step(i, observations: "x" * 80) }

        result = memory.compress_if_needed!(model:)

        expect(result).to be_nil
      end
    end
  end

  describe "preserve_recent" do
    it "preserves the most recent N steps" do
      memory = memory_class.new(config: summarize_config)
      5.times { |i| memory.steps << build_action_step(i, observations: "x" * 30) }

      memory.compress_if_needed!(model:)

      remaining_action_steps = memory.steps.select { |s| s.is_a?(Smolagents::Types::ActionStep) }
      expect(remaining_action_steps.map(&:step_number)).to eq([3, 4])
    end
  end

  describe "model interaction" do
    it "calls model.generate with summarization prompt" do
      memory = memory_class.new(config: summarize_config)
      5.times { |i| memory.steps << build_action_step(i, observations: "obs_#{i}_#{"z" * 25}") }

      memory.compress_if_needed!(model:)

      expect(model).to have_received(:generate) do |messages, **kwargs|
        expect(messages.size).to eq(1)
        expect(messages.first.role).to eq(:user)
        expect(messages.first.content).to include("Summarize")
        expect(messages.first.content).to include("obs_0")
        expect(kwargs[:tools]).to eq([])
        expect(kwargs[:max_tokens]).to eq(200)
      end
    end
  end

  describe "SummaryStep creation" do
    it "creates SummaryStep with correct range and count" do
      memory = memory_class.new(config: summarize_config)
      5.times { |i| memory.steps << build_action_step(i, observations: "x" * 30) }

      memory.compress_if_needed!(model:)

      summary = memory.steps.find { |s| s.is_a?(Smolagents::Types::SummaryStep) }
      expect(summary).not_to be_nil
      expect(summary.summary).to eq("Summary of observations")
      expect(summary.original_step_range).to eq(0..2)
      expect(summary.original_step_count).to eq(3)
      expect(summary.tokens_saved).to be >= 0
    end

    it "inserts summary before remaining action steps" do
      memory = memory_class.new(config: summarize_config)
      5.times { |i| memory.steps << build_action_step(i, observations: "x" * 30) }

      memory.compress_if_needed!(model:)

      summary_idx = memory.steps.index { |s| s.is_a?(Smolagents::Types::SummaryStep) }
      first_action_idx = memory.steps.index { |s| s.is_a?(Smolagents::Types::ActionStep) }
      expect(summary_idx).to be < first_action_idx
    end
  end

  describe "#token_usage_percent" do
    it "returns 0.0 when no budget is set" do
      no_budget_config = Smolagents::Types::MemoryConfig.new(
        budget: nil, strategy: :summarize, preserve_recent: 2,
        mask_placeholder: "[truncated]", compression_threshold: 0.75
      )
      memory = memory_class.new(config: no_budget_config)

      expect(memory.send(:token_usage_percent)).to eq(0.0)
    end

    it "returns 0.0 when budget is zero" do
      zero_budget_config = Smolagents::Types::MemoryConfig.new(
        budget: 0, strategy: :summarize, preserve_recent: 2,
        mask_placeholder: "[truncated]", compression_threshold: 0.75
      )
      memory = memory_class.new(config: zero_budget_config)

      expect(memory.send(:token_usage_percent)).to eq(0.0)
    end

    it "calculates usage fraction correctly" do
      memory = memory_class.new(config: summarize_config)
      memory.steps << build_action_step(0, observations: "x" * 80)

      # estimated_tokens = 80, budget = 100 => 0.8
      expect(memory.send(:token_usage_percent)).to eq(0.8)
    end
  end

  describe "hybrid strategy" do
    it "compresses when strategy is :hybrid" do
      hybrid_config = Smolagents::Types::MemoryConfig.new(
        budget: 100, strategy: :hybrid, preserve_recent: 2,
        mask_placeholder: "[truncated]", compression_threshold: 0.75
      )
      memory = memory_class.new(config: hybrid_config)
      5.times { |i| memory.steps << build_action_step(i, observations: "x" * 30) }

      memory.compress_if_needed!(model:)

      expect(model).to have_received(:generate)
    end
  end
end
