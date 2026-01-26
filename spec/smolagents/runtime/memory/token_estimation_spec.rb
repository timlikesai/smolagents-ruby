require "spec_helper"

RSpec.describe Smolagents::Runtime::Memory::TokenEstimation do
  subject(:memory) { memory_class.new("System prompt text", config:) }

  let(:memory_class) do
    Class.new do
      include Smolagents::Runtime::Memory::TokenEstimation

      attr_reader :system_prompt, :steps, :config

      def initialize(prompt, config:)
        @system_prompt = Smolagents::Types::SystemPromptStep.new(system_prompt: prompt)
        @steps = []
        @config = config
      end

      def <<(step) = @steps << step
    end
  end

  let(:config) { Smolagents::Types::MemoryConfig.default }

  describe "CHARS_PER_TOKEN" do
    it "is set to 4" do
      expect(described_class::CHARS_PER_TOKEN).to eq(4)
    end
  end

  describe "#estimated_tokens" do
    it "estimates tokens from system prompt" do
      # "System prompt text" = 18 chars / 4 = 4 tokens
      expect(memory.estimated_tokens).to eq(4)
    end

    it "includes TaskStep characters" do
      memory << Smolagents::Types::TaskStep.new(task: "12345678") # 8 chars

      # System (18) + Task (8) = 26 chars / 4 = 6 tokens
      expect(memory.estimated_tokens).to eq(6)
    end

    it "includes ActionStep characters" do
      memory << Smolagents::Types::ActionStep.new(
        step_number: 0,
        model_output_message: Smolagents::Types::ChatMessage.assistant("1234"), # 4 chars
        observations: "12345678", # 8 chars
        code_action: "1234", # 4 chars
        error: nil
      )

      # System (18) + Action (4+8+4) = 34 chars / 4 = 8 tokens
      expect(memory.estimated_tokens).to eq(8)
    end

    it "includes ActionStep error characters" do
      memory << Smolagents::Types::ActionStep.new(
        step_number: 0,
        error: "12345678" # 8 chars
      )

      # System (18) + Error (8) = 26 chars / 4 = 6 tokens
      expect(memory.estimated_tokens).to eq(6)
    end

    it "includes PlanningStep characters" do
      memory << Smolagents::Types::PlanningStep.new(
        model_input_messages: [Smolagents::Types::ChatMessage.user("1234")], # 4 chars
        model_output_message: nil,
        plan: "12345678", # 8 chars
        timing: nil,
        token_usage: nil
      )

      # System (18) + Plan (8) + Messages (4) = 30 chars / 4 = 7 tokens
      expect(memory.estimated_tokens).to eq(7)
    end

    it "includes FinalAnswerStep characters" do
      memory << Smolagents::Types::FinalAnswerStep.new(output: "12345678") # 8 chars

      # System (18) + Output (8) = 26 chars / 4 = 6 tokens
      expect(memory.estimated_tokens).to eq(6)
    end

    it "handles nil values gracefully" do
      memory << Smolagents::Types::ActionStep.new(
        step_number: 0,
        model_output_message: nil,
        observations: nil,
        code_action: nil,
        error: nil
      )

      # Only system prompt counts
      expect(memory.estimated_tokens).to eq(4)
    end

    it "handles empty strings" do
      memory << Smolagents::Types::ActionStep.new(
        step_number: 0,
        observations: ""
      )

      # Only system prompt counts
      expect(memory.estimated_tokens).to eq(4)
    end

    it "accumulates across multiple steps" do
      memory << Smolagents::Types::TaskStep.new(task: "1234") # 4 chars
      memory << Smolagents::Types::ActionStep.new(step_number: 0, observations: "1234") # 4 chars
      memory << Smolagents::Types::ActionStep.new(step_number: 1, observations: "1234") # 4 chars

      # System (18) + Task (4) + Action (4) + Action (4) = 30 chars / 4 = 7 tokens
      expect(memory.estimated_tokens).to eq(7)
    end
  end

  describe "#over_budget?" do
    context "when no budget is set" do
      let(:config) { Smolagents::Types::MemoryConfig.default }

      it "returns false" do
        expect(memory.over_budget?).to be false
      end
    end

    context "when under budget" do
      let(:config) { Smolagents::Types::MemoryConfig.masked(budget: 100, preserve_recent: 3) }

      it "returns false" do
        # System prompt = 18 chars / 4 = 4 tokens, well under 100
        expect(memory.over_budget?).to be false
      end
    end

    context "when over budget" do
      let(:config) { Smolagents::Types::MemoryConfig.masked(budget: 1, preserve_recent: 3) }

      it "returns true" do
        # System prompt = 18 chars / 4 = 4 tokens, over 1
        expect(memory.over_budget?).to be true
      end
    end

    context "when exactly at budget" do
      let(:config) { Smolagents::Types::MemoryConfig.masked(budget: 4, preserve_recent: 3) }

      it "returns false" do
        # System prompt = 18 chars / 4 = 4 tokens, exactly at 4
        expect(memory.over_budget?).to be false
      end
    end
  end

  describe "#headroom" do
    context "when no budget is set" do
      let(:config) { Smolagents::Types::MemoryConfig.default }

      it "returns nil" do
        expect(memory.headroom).to be_nil
      end
    end

    context "when budget is set" do
      let(:config) { Smolagents::Types::MemoryConfig.masked(budget: 100, preserve_recent: 3) }

      it "returns remaining tokens" do
        # System prompt = 4 tokens, budget = 100, headroom = 96
        expect(memory.headroom).to eq(96)
      end
    end

    context "when over budget" do
      let(:config) { Smolagents::Types::MemoryConfig.masked(budget: 2, preserve_recent: 3) }

      it "returns negative headroom" do
        # System prompt = 4 tokens, budget = 2, headroom = -2
        expect(memory.headroom).to eq(-2)
      end
    end

    context "with additional content" do
      let(:config) { Smolagents::Types::MemoryConfig.masked(budget: 50, preserve_recent: 3) }

      it "accounts for all steps" do
        memory << Smolagents::Types::TaskStep.new(task: "A" * 40) # 40 chars = 10 tokens

        # System (4) + Task (10) = 14 tokens, budget = 50, headroom = 36
        expect(memory.headroom).to eq(36)
      end
    end
  end
end
