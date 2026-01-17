require "smolagents"

RSpec.describe Smolagents::Concerns::Evaluation do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Concerns::Evaluation

      attr_accessor :model, :logger

      def initialize(model:, evaluation_enabled: false)
        @model = model
        @logger = Smolagents::AgentLogger.new(output: StringIO.new, level: Smolagents::AgentLogger::DEBUG)
        initialize_evaluation(evaluation_enabled:)
      end
    end
  end

  let(:mock_token_usage) { Smolagents::TokenUsage.new(input_tokens: 50, output_tokens: 20) }

  let(:mock_model) do
    instance_double(Smolagents::Model).tap do |m|
      allow(m).to receive(:generate).and_return(
        Smolagents::ChatMessage.assistant("DONE: 42", token_usage: mock_token_usage)
      )
    end
  end

  describe "EVALUATION_SYSTEM" do
    it "is a short directive" do
      expect(described_class::EVALUATION_SYSTEM.length).to be < 100
    end
  end

  describe "EVALUATION_PROMPT" do
    it "includes task placeholder" do
      expect(described_class::EVALUATION_PROMPT).to include("%<task>s")
    end

    it "includes step_count placeholder" do
      expect(described_class::EVALUATION_PROMPT).to include("%<step_count>d")
    end

    it "includes observation placeholder" do
      expect(described_class::EVALUATION_PROMPT).to include("%<observation>s")
    end

    it "includes expected response formats" do
      expect(described_class::EVALUATION_PROMPT).to include("DONE:")
      expect(described_class::EVALUATION_PROMPT).to include("CONTINUE:")
      expect(described_class::EVALUATION_PROMPT).to include("STUCK:")
    end
  end

  describe "#initialize_evaluation" do
    it "sets evaluation_enabled to false by default" do
      agent = test_class.new(model: mock_model)
      expect(agent.evaluation_enabled).to be(false)
    end

    it "sets evaluation_enabled when true" do
      agent = test_class.new(model: mock_model, evaluation_enabled: true)
      expect(agent.evaluation_enabled).to be(true)
    end
  end

  describe "#evaluate_progress" do
    let(:agent) { test_class.new(model: mock_model, evaluation_enabled: true) }
    let(:step) { Smolagents::ActionStep.new(step_number: 1, observations: "The result is 42") }

    it "sends scoped context to model" do
      agent.send(:evaluate_progress, "Calculate 6 * 7", step, 1)

      expect(mock_model).to have_received(:generate).with(
        array_including(
          having_attributes(role: Smolagents::MessageRole::SYSTEM),
          having_attributes(role: Smolagents::MessageRole::USER, content: include("Calculate 6 * 7"))
        ),
        max_tokens: 100
      )
    end

    it "returns an EvaluationResult" do
      result = agent.send(:evaluate_progress, "task", step, 1)
      expect(result).to be_a(Smolagents::Types::EvaluationResult)
    end

    it "includes token usage in result" do
      result = agent.send(:evaluate_progress, "task", step, 1)
      expect(result.token_usage).to eq(mock_token_usage)
    end
  end

  describe "#extract_observation" do
    let(:agent) { test_class.new(model: mock_model) }

    it "extracts observations from step" do
      step = Smolagents::ActionStep.new(step_number: 1, observations: "Found the answer")
      obs = agent.send(:extract_observation, step)
      expect(obs).to eq("Found the answer")
    end

    it "falls back to action_output when observations nil" do
      step = Smolagents::ActionStep.new(step_number: 1, action_output: "output value")
      obs = agent.send(:extract_observation, step)
      expect(obs).to eq("output value")
    end

    it "truncates long observations for token efficiency" do
      long_obs = "x" * 1000
      step = Smolagents::ActionStep.new(step_number: 1, observations: long_obs)
      obs = agent.send(:extract_observation, step)
      expect(obs.length).to eq(500)
    end
  end

  describe "#parse_evaluation" do
    let(:agent) { test_class.new(model: mock_model) }

    context "with DONE response" do
      it "parses goal achieved" do
        result = agent.send(:parse_evaluation, "DONE: The answer is 42")
        expect(result.goal_achieved?).to be(true)
        expect(result.answer).to eq("The answer is 42")
      end

      it "handles lowercase" do
        result = agent.send(:parse_evaluation, "done: answer here")
        expect(result.goal_achieved?).to be(true)
      end

      it "handles multiline" do
        result = agent.send(:parse_evaluation, "DONE: line one\nline two")
        expect(result.goal_achieved?).to be(true)
        expect(result.answer).to include("line one")
      end
    end

    context "with CONTINUE response" do
      it "parses continue status" do
        result = agent.send(:parse_evaluation, "CONTINUE: Need more data")
        expect(result.continue?).to be(true)
        expect(result.reasoning).to eq("Need more data")
      end
    end

    context "with STUCK response" do
      it "parses stuck status" do
        result = agent.send(:parse_evaluation, "STUCK: Tool not available")
        expect(result.stuck?).to be(true)
        expect(result.reasoning).to eq("Tool not available")
      end
    end

    context "with unrecognized format" do
      it "defaults to continue" do
        result = agent.send(:parse_evaluation, "I'm not sure what to do")
        expect(result.continue?).to be(true)
        expect(result.reasoning).to eq("I'm not sure what to do")
      end
    end

    it "includes token usage when provided" do
      result = agent.send(:parse_evaluation, "DONE: answer", mock_token_usage)
      expect(result.token_usage).to eq(mock_token_usage)
    end

    context "with confidence score" do
      it "extracts confidence from DONE response" do
        result = agent.send(:parse_evaluation, "DONE: The answer\nCONFIDENCE: 0.95")
        expect(result.goal_achieved?).to be(true)
        expect(result.confidence).to eq(0.95)
      end

      it "extracts confidence from CONTINUE response" do
        result = agent.send(:parse_evaluation, "CONTINUE: Need more info\nCONFIDENCE: 0.6")
        expect(result.continue?).to be(true)
        expect(result.confidence).to eq(0.6)
      end

      it "extracts confidence from STUCK response" do
        result = agent.send(:parse_evaluation, "STUCK: No progress\nCONFIDENCE: 0.2")
        expect(result.stuck?).to be(true)
        expect(result.confidence).to eq(0.2)
      end

      it "clamps confidence to 0.0-1.0 range" do
        result = agent.send(:parse_evaluation, "DONE: answer\nCONFIDENCE: 1.5")
        expect(result.confidence).to eq(1.0)
      end

      it "uses default confidence when not provided" do
        result = agent.send(:parse_evaluation, "DONE: answer")
        expect(result.confidence).to eq(Smolagents::Types::DEFAULT_CONFIDENCE[:goal_achieved])
      end

      it "uses low default confidence for unrecognized format" do
        result = agent.send(:parse_evaluation, "Not sure what to say")
        expect(result.confidence).to eq(0.3)
      end
    end
  end

  describe "#execute_evaluation_if_needed" do
    let(:step) { Smolagents::ActionStep.new(step_number: 1, observations: "Result") }

    context "when evaluation disabled" do
      let(:agent) { test_class.new(model: mock_model, evaluation_enabled: false) }

      it "returns nil" do
        result = agent.send(:execute_evaluation_if_needed, "task", step, 1)
        expect(result).to be_nil
      end

      it "does not call model" do
        agent.send(:execute_evaluation_if_needed, "task", step, 1)
        expect(mock_model).not_to have_received(:generate)
      end
    end

    context "when evaluation enabled" do
      let(:agent) { test_class.new(model: mock_model, evaluation_enabled: true) }

      it "calls evaluate_progress" do
        result = agent.send(:execute_evaluation_if_needed, "task", step, 1)
        expect(result).to be_a(Smolagents::Types::EvaluationResult)
        expect(mock_model).to have_received(:generate)
      end

      it "yields result when block given" do
        yielded = nil
        agent.send(:execute_evaluation_if_needed, "task", step, 1) { |r| yielded = r }
        expect(yielded).to be_a(Smolagents::Types::EvaluationResult)
      end
    end

    context "when step is final answer" do
      let(:agent) { test_class.new(model: mock_model, evaluation_enabled: true) }
      let(:final_step) { Smolagents::ActionStep.new(step_number: 1, is_final_answer: true) }

      it "returns nil (already done)" do
        result = agent.send(:execute_evaluation_if_needed, "task", final_step, 1)
        expect(result).to be_nil
      end

      it "does not call model" do
        agent.send(:execute_evaluation_if_needed, "task", final_step, 1)
        expect(mock_model).not_to have_received(:generate)
      end
    end
  end
end
