require "smolagents/concerns/agents/evaluation/protocol"

RSpec.describe Smolagents::Concerns::Evaluation::Protocol do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Evaluation::Protocol

      attr_accessor :max_steps

      def initialize(max_steps = nil)
        @max_steps = max_steps
      end
    end
  end

  let(:instance) { test_class.new }

  describe "EVALUATION_SYSTEM prompt" do
    it "is frozen" do
      expect(described_class::EVALUATION_SYSTEM).to be_frozen
    end

    it "is a non-empty string" do
      expect(described_class::EVALUATION_SYSTEM).to be_a(String)
      expect(described_class::EVALUATION_SYSTEM).not_to be_empty
    end

    it "includes task evaluation guidance" do
      expect(described_class::EVALUATION_SYSTEM).to include("evaluate")
    end
  end

  describe "EVALUATION_PROMPT template" do
    it "is frozen" do
      expect(described_class::EVALUATION_PROMPT).to be_frozen
    end

    it "includes task placeholder" do
      expect(described_class::EVALUATION_PROMPT).to include("%<task>s")
    end

    it "includes step_count placeholder" do
      expect(described_class::EVALUATION_PROMPT).to include("%<step_count>d")
    end

    it "includes budget placeholder" do
      expect(described_class::EVALUATION_PROMPT).to include("%<budget>s")
    end

    it "includes observation placeholder" do
      expect(described_class::EVALUATION_PROMPT).to include("%<observation>s")
    end

    it "mentions DONE status" do
      expect(described_class::EVALUATION_PROMPT).to include("DONE:")
    end

    it "mentions CONTINUE status" do
      expect(described_class::EVALUATION_PROMPT).to include("CONTINUE:")
    end

    it "mentions STUCK status" do
      expect(described_class::EVALUATION_PROMPT).to include("STUCK:")
    end

    it "includes exact formatting requirement" do
      expect(described_class::EVALUATION_PROMPT).to include("exact")
    end

    it "includes confidence instruction" do
      expect(described_class::EVALUATION_PROMPT).to include("CONFIDENCE")
    end
  end

  describe "#build_evaluation_messages" do
    it "returns array of ChatMessages" do
      messages = instance.build_evaluation_messages("Find Ruby docs", 5, "Result page")

      expect(messages).to be_an(Array)
      expect(messages.all?(Smolagents::ChatMessage)).to be true
    end

    it "includes system message first" do
      messages = instance.build_evaluation_messages("Find Ruby docs", 5, "Result page")

      expect(messages.first.role).to eq(:system)
    end

    it "includes user message second" do
      messages = instance.build_evaluation_messages("Find Ruby docs", 5, "Result page")

      expect(messages.last.role).to eq(:user)
    end

    it "formats user message with task" do
      messages = instance.build_evaluation_messages("Find Python docs", 3, "Result")

      expect(messages.last.content).to include("Find Python docs")
    end

    it "includes step count in user message" do
      messages = instance.build_evaluation_messages("Task", 5, "Result")

      expect(messages.last.content).to include("5")
    end

    it "includes observation in user message" do
      obs = "Found the documentation"
      messages = instance.build_evaluation_messages("Task", 1, obs)

      expect(messages.last.content).to include(obs)
    end

    it "includes budget context in user message" do
      messages = instance.build_evaluation_messages("Task", 5, "Result")

      # Budget context should be present
      expect(messages.last.content).to include("BUDGET:")
    end
  end

  describe "#evaluation_budget_context" do
    context "without max_steps" do
      before do
        instance.max_steps = nil
      end

      it "returns 'unlimited'" do
        budget = instance.send(:evaluation_budget_context, 5)
        expect(budget).to eq("unlimited")
      end
    end

    context "with max_steps" do
      before do
        instance.max_steps = 10
      end

      it "calculates remaining steps" do
        budget = instance.send(:evaluation_budget_context, 3)
        expect(budget).to include("7")
      end

      it "uses singular 'step' when 1 remaining" do
        budget = instance.send(:evaluation_budget_context, 9)
        expect(budget).to eq("1 step remaining")
      end

      it "uses plural 'steps' for multiple remaining" do
        budget = instance.send(:evaluation_budget_context, 7)
        expect(budget).to include("steps remaining")
      end

      it "returns LAST STEP when no steps remaining" do
        budget = instance.send(:evaluation_budget_context, 10)
        expect(budget).to eq("LAST STEP")
      end

      it "returns LAST STEP when over budget" do
        budget = instance.send(:evaluation_budget_context, 15)
        expect(budget).to eq("LAST STEP")
      end

      it "uses full budget text for 3+ steps remaining" do
        budget = instance.send(:evaluation_budget_context, 0)
        expect(budget).to match(/\d+ steps remaining/)
      end
    end
  end

  describe "#extract_observation" do
    context "with step implementing evaluation_observation" do
      let(:step) do
        step = double("step")
        allow(step).to receive(:respond_to?).with(:evaluation_observation).and_return(true)
        allow(step).to receive(:evaluation_observation).and_return("Custom observation")
        step
      end

      it "uses evaluation_observation when available" do
        obs = instance.extract_observation(step)
        expect(obs).to eq("Custom observation")
      end
    end

    context "with step implementing observations" do
      let(:step) do
        step = double("step")
        allow(step).to receive(:respond_to?).with(:evaluation_observation).and_return(false)
        allow(step).to receive(:respond_to?).with(:observations).and_return(true)
        allow(step).to receive_messages(observations: "Step observations", action_output: "output")
        step
      end

      it "uses observations when evaluation_observation not available" do
        obs = instance.extract_observation(step)
        expect(obs).to eq("Step observations")
      end
    end

    context "with step implementing action_output" do
      let(:step) do
        step = double("step")
        allow(step).to receive(:respond_to?).with(:evaluation_observation).and_return(false)
        allow(step).to receive(:respond_to?).with(:observations).and_return(true)
        allow(step).to receive_messages(observations: nil, action_output: "Action output")
        step
      end

      it "falls back to action_output" do
        obs = instance.extract_observation(step)
        expect(obs).to eq("Action output")
      end
    end

    context "with step as simple object" do
      let(:step) do
        step = double("step")
        allow(step).to receive(:respond_to?).with(:evaluation_observation).and_return(false)
        allow(step).to receive(:respond_to?).with(:observations).and_return(false)
        allow(step).to receive(:to_s).and_return("Step representation")
        step
      end

      it "converts to string as fallback" do
        obs = instance.extract_observation(step)
        expect(obs).to eq("Step representation")
      end
    end

    context "with long observation text" do
      let(:long_text) { "x" * 2000 }
      let(:step) do
        step = double("step")
        allow(step).to receive(:respond_to?).with(:evaluation_observation).and_return(true)
        allow(step).to receive(:evaluation_observation).and_return(long_text)
        step
      end

      it "truncates to 1500 characters" do
        obs = instance.extract_observation(step)
        expect(obs.length).to eq(1500)
        expect(obs).to start_with("x" * 100)
      end
    end

    context "with short observation text" do
      let(:step) do
        step = double("step")
        allow(step).to receive(:respond_to?).with(:evaluation_observation).and_return(true)
        allow(step).to receive(:evaluation_observation).and_return("short text")
        step
      end

      it "preserves short text unchanged" do
        obs = instance.extract_observation(step)
        expect(obs).to eq("short text")
      end
    end
  end

  describe "#step_is_final_answer?" do
    context "with step implementing final_answer?" do
      let(:step) do
        step = double("step")
        allow(step).to receive(:respond_to?).with(:final_answer?).and_return(true)
        allow(step).to receive(:final_answer?).and_return(true)
        step
      end

      it "returns true when final_answer? is true" do
        result = instance.step_is_final_answer?(step)
        expect(result).to be true
      end

      it "returns false when final_answer? is false" do
        step = double("step")
        allow(step).to receive(:respond_to?).with(:final_answer?).and_return(true)
        allow(step).to receive(:final_answer?).and_return(false)
        result = instance.step_is_final_answer?(step)
        expect(result).to be false
      end
    end

    context "without final_answer? method" do
      let(:step) do
        step = double("step")
        allow(step).to receive(:respond_to?).with(:final_answer?).and_return(false)
        step
      end

      it "returns false" do
        result = instance.step_is_final_answer?(step)
        expect(result).to be false
      end
    end
  end

  describe "#extract_raw_observation" do
    context "with evaluation_observation method" do
      it "uses evaluation_observation" do
        step = double("step")
        allow(step).to receive(:respond_to?).with(:evaluation_observation).and_return(true)
        allow(step).to receive(:evaluation_observation).and_return("Evaluation obs")
        obs = instance.send(:extract_raw_observation, step)
        expect(obs).to eq("Evaluation obs")
      end
    end

    context "with observations method" do
      it "uses observations" do
        step = double("step")
        allow(step).to receive(:respond_to?).with(:evaluation_observation).and_return(false)
        allow(step).to receive(:respond_to?).with(:observations).and_return(true)
        allow(step).to receive_messages(observations: "Observations", action_output: "output")
        obs = instance.send(:extract_raw_observation, step)
        expect(obs).to eq("Observations")
      end
    end

    context "with observations nil and action_output present" do
      it "uses action_output when observations is nil" do
        output = double("output", to_s: "Output string")
        step = double("step")
        allow(step).to receive(:respond_to?).with(:evaluation_observation).and_return(false)
        allow(step).to receive(:respond_to?).with(:observations).and_return(true)
        allow(step).to receive_messages(observations: nil, action_output: output)
        obs = instance.send(:extract_raw_observation, step)
        expect(obs).to eq("Output string")
      end
    end

    context "without observations methods" do
      it "converts step to string" do
        step = double("step")
        allow(step).to receive(:respond_to?).with(:evaluation_observation).and_return(false)
        allow(step).to receive(:respond_to?).with(:observations).and_return(false)
        allow(step).to receive(:to_s).and_return("Step as string")
        obs = instance.send(:extract_raw_observation, step)
        expect(obs).to eq("Step as string")
      end
    end
  end

  describe "protocol integration" do
    it "builds complete evaluation message set" do
      instance.max_steps = 20
      task = "Find the capital of France"
      observation = "Result: Paris is the capital"

      messages = instance.build_evaluation_messages(task, 3, observation)

      expect(messages.size).to eq(2)
      expect(messages[0].role).to eq(:system)
      expect(messages[1].role).to eq(:user)
      expect(messages[1].content).to include(task)
      expect(messages[1].content).to include(observation)
      expect(messages[1].content).to include("17") # remaining steps
    end

    it "handles evaluation of final answer step" do
      step = double("step")
      allow(step).to receive(:respond_to?).with(:final_answer?).and_return(true)
      allow(step).to receive(:respond_to?).with(:evaluation_observation).and_return(true)
      allow(step).to receive_messages(final_answer?: true, evaluation_observation: "Final result")

      is_final = instance.step_is_final_answer?(step)
      obs = instance.extract_observation(step)

      expect(is_final).to be true
      expect(obs).to eq("Final result")
    end
  end
end
