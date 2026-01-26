RSpec.describe Smolagents::Runtime::Memory::Masking do
  let(:memory_class) do
    Class.new do
      include Smolagents::Runtime::Memory::Masking

      def initialize(system_prompt, config: Smolagents::Types::MemoryConfig.default)
        @system_prompt = Smolagents::Types::SystemPromptStep.new(system_prompt:)
        @steps = []
        @config = config
      end

      attr_reader :steps, :config

      def over_budget? = @over_budget

      attr_writer :over_budget
    end
  end

  let(:memory) { memory_class.new("Test prompt") }

  describe "#steps_to_messages" do
    context "when under budget" do
      before { memory.over_budget = false }

      it "returns unmasked messages" do
        allow(memory).to receive(:unmasked_messages).and_return(["msg1"])
        memory.send(:steps_to_messages, summary_mode: false)

        expect(memory).to have_received(:unmasked_messages)
      end
    end

    context "when over budget" do
      let(:memory) { memory_class.new("Test prompt", config: Smolagents::Types::MemoryConfig.masked(budget: 1000)) }

      before { memory.over_budget = true }

      it "returns masked messages" do
        allow(memory).to receive(:masked_messages).and_return(["msg2"])
        memory.send(:steps_to_messages, summary_mode: false)

        expect(memory).to have_received(:masked_messages)
      end
    end

    context "when config is full" do
      # default config has strategy :full
      let(:memory) { memory_class.new("Test prompt", config: Smolagents::Types::MemoryConfig.default) }

      it "returns unmasked messages" do
        allow(memory).to receive(:unmasked_messages).and_return(["msg"])

        memory.over_budget = true
        memory.send(:steps_to_messages, summary_mode: false)

        expect(memory).to have_received(:unmasked_messages)
      end
    end
  end

  describe "ERROR_RECOVERY_GUIDANCE constant" do
    it "is a frozen string" do
      guidance = described_class::ERROR_RECOVERY_GUIDANCE

      expect(guidance).to be_a(String)
      expect(guidance).to be_frozen
    end

    it "contains helpful error recovery message" do
      guidance = described_class::ERROR_RECOVERY_GUIDANCE

      expect(guidance).to include("retry")
      expect(guidance).to include("errors")
    end
  end
end
