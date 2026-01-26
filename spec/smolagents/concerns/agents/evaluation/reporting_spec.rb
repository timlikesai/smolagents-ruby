require "smolagents/concerns/agents/evaluation/reporting"

RSpec.describe Smolagents::Concerns::Evaluation::Reporting do
  # Mock logger that captures calls with keyword arguments
  # (the implementation uses semantic logging: @logger.info("msg", key: value))
  let(:mock_logger_class) do
    Class.new do
      attr_reader :messages

      def initialize
        @messages = []
      end

      def info(msg, **kwargs)
        @messages << { level: :info, message: msg, kwargs: }
      end

      def warn(msg, **kwargs)
        @messages << { level: :warn, message: msg, kwargs: }
      end

      def debug(msg, **kwargs)
        @messages << { level: :debug, message: msg, kwargs: }
      end

      def last_message
        @messages.last
      end

      def all_output
        @messages.map { |m| "[#{m[:level].to_s.upcase}] #{m[:message]} #{m[:kwargs]}" }.join("\n")
      end
    end
  end

  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Evaluation::Reporting

      attr_accessor :logger

      def initialize
        @logger = nil
      end

      def emit(event)
        @last_event = event
      end

      def emitting?
        true
      end

      attr_reader :last_event
    end
  end

  let(:mock_logger) { mock_logger_class.new }
  let(:instance) do
    inst = test_class.new
    inst.logger = mock_logger
    inst
  end
  let(:token_usage) { Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50) }

  describe "#record_evaluation_to_context" do
    let(:result) do
      instance_double(Smolagents::Types::EvaluationResult,
                      status: :goal_achieved,
                      token_usage:)
    end

    context "when ObservabilityContext exists" do
      let(:mock_context) do
        instance_double(Smolagents::Types::ObservabilityContext)
      end

      before do
        allow(Smolagents::Types::ObservabilityContext).to receive(:current).and_return(mock_context)
        allow(mock_context).to receive(:add_tokens)
        allow(mock_context).to receive(:record_evaluation)
      end

      it "adds tokens to context" do
        instance.record_evaluation_to_context(result)
        expect(mock_context).to have_received(:add_tokens).with(token_usage)
      end

      it "records evaluation result to context" do
        instance.record_evaluation_to_context(result)
        expect(mock_context).to have_received(:record_evaluation).with(result)
      end

      it "performs both operations in sequence" do
        call_order = []
        allow(mock_context).to receive(:add_tokens) { call_order << :tokens }
        allow(mock_context).to receive(:record_evaluation) { call_order << :evaluation }

        instance.record_evaluation_to_context(result)

        expect(call_order).to eq(%i[tokens evaluation])
      end
    end

    context "when ObservabilityContext is nil" do
      before do
        allow(Smolagents::Types::ObservabilityContext).to receive(:current).and_return(nil)
      end

      it "does nothing without raising" do
        expect do
          instance.record_evaluation_to_context(result)
        end.not_to raise_error
      end
    end
  end

  describe "#emit_evaluation_event" do
    let(:result) do
      Smolagents::Types::EvaluationResult.new(
        status: :goal_achieved,
        answer: "The answer is 42",
        reasoning: nil,
        confidence: 0.95,
        token_usage:
      )
    end

    let(:mock_event) { double("event") }

    before do
      # Create a proper class double for the event
      event_class = class_double(Smolagents::Events::EvaluationCompleted).as_stubbed_const
      allow(event_class).to receive(:create).and_return(mock_event)
    end

    it "emits EvaluationCompleted event" do
      instance.emit_evaluation_event(result, 5)

      expect(Smolagents::Events::EvaluationCompleted).to have_received(:create)
    end

    it "includes step_number in event" do
      instance.emit_evaluation_event(result, 5)

      expect(Smolagents::Events::EvaluationCompleted).to have_received(:create).with(
        hash_including(step_number: 5)
      )
    end

    it "includes status in event" do
      instance.emit_evaluation_event(result, 5)

      expect(Smolagents::Events::EvaluationCompleted).to have_received(:create).with(
        hash_including(status: :goal_achieved)
      )
    end

    it "includes answer in event" do
      instance.emit_evaluation_event(result, 5)

      expect(Smolagents::Events::EvaluationCompleted).to have_received(:create).with(
        hash_including(answer: "The answer is 42")
      )
    end

    it "includes confidence in event" do
      instance.emit_evaluation_event(result, 5)

      expect(Smolagents::Events::EvaluationCompleted).to have_received(:create).with(
        hash_including(confidence: 0.95)
      )
    end

    it "includes token_usage in event" do
      instance.emit_evaluation_event(result, 5)

      expect(Smolagents::Events::EvaluationCompleted).to have_received(:create).with(
        hash_including(token_usage:)
      )
    end
  end

  describe "#log_evaluation_result" do
    # Use the mock_logger from the outer context (already set up)

    context "with goal_achieved status" do
      let(:result) do
        Smolagents::Types::EvaluationResult.new(
          status: :goal_achieved,
          answer: "This is the answer",
          reasoning: nil,
          confidence: nil,
          token_usage:
        )
      end

      it "logs at INFO level" do
        instance.log_evaluation_result(result, 5)

        expect(mock_logger.last_message[:level]).to eq(:info)
      end

      it "includes 'goal achieved' message" do
        instance.log_evaluation_result(result, 5)

        expect(mock_logger.last_message[:message]).to include("goal achieved")
      end

      it "includes step number" do
        instance.log_evaluation_result(result, 5)

        expect(mock_logger.last_message[:kwargs][:step]).to eq(5)
      end

      it "includes truncated answer" do
        instance.log_evaluation_result(result, 5)

        expect(mock_logger.last_message[:kwargs][:answer]).to include("This is the answer")
      end

      it "truncates long answers to 50 characters" do
        long_answer = "x" * 100
        result_long = Smolagents::Types::EvaluationResult.new(
          status: :goal_achieved,
          answer: long_answer,
          reasoning: nil,
          confidence: nil,
          token_usage:
        )

        instance.log_evaluation_result(result_long, 5)

        expect(mock_logger.last_message[:kwargs][:answer].length).to eq(50)
      end
    end

    context "with stuck status" do
      let(:result) do
        Smolagents::Types::EvaluationResult.new(
          status: :stuck,
          answer: nil,
          reasoning: "Cannot find required data",
          confidence: nil,
          token_usage:
        )
      end

      it "logs at WARN level" do
        instance.log_evaluation_result(result, 3)

        expect(mock_logger.last_message[:level]).to eq(:warn)
      end

      it "includes 'stuck' message" do
        instance.log_evaluation_result(result, 3)

        expect(mock_logger.last_message[:message]).to include("stuck")
      end

      it "includes reasoning" do
        instance.log_evaluation_result(result, 3)

        expect(mock_logger.last_message[:kwargs][:reason]).to include("Cannot find required data")
      end
    end

    context "with continue status" do
      let(:result) do
        Smolagents::Types::EvaluationResult.new(
          status: :continue,
          answer: nil,
          reasoning: "Need to search for more information",
          confidence: nil,
          token_usage:
        )
      end

      it "logs at DEBUG level" do
        instance.log_evaluation_result(result, 2)

        expect(mock_logger.last_message[:level]).to eq(:debug)
      end

      it "includes 'continue' message" do
        instance.log_evaluation_result(result, 2)

        expect(mock_logger.last_message[:message]).to include("continue")
      end

      it "includes reasoning" do
        instance.log_evaluation_result(result, 2)

        expect(mock_logger.last_message[:kwargs][:reason]).to include("Need to search for more information")
      end
    end

    context "with nil reasoning or answer" do
      let(:result) do
        Smolagents::Types::EvaluationResult.new(
          status: :continue,
          answer: nil,
          reasoning: nil,
          confidence: nil,
          token_usage:
        )
      end

      it "handles nil gracefully" do
        expect do
          instance.log_evaluation_result(result, 1)
        end.not_to raise_error
      end

      it "still logs the evaluation" do
        instance.log_evaluation_result(result, 1)

        expect(mock_logger.last_message[:message]).to include("continue")
      end
    end

    context "with very long reasoning" do
      let(:long_reason) { "x" * 200 }
      let(:result) do
        Smolagents::Types::EvaluationResult.new(
          status: :stuck,
          answer: nil,
          reasoning: long_reason,
          confidence: nil,
          token_usage:
        )
      end

      it "truncates reasoning to 50 characters" do
        instance.log_evaluation_result(result, 2)

        expect(mock_logger.last_message[:kwargs][:reason].length).to eq(50)
      end
    end
  end

  describe "reporting integration" do
    let(:result) do
      Smolagents::Types::EvaluationResult.new(
        status: :goal_achieved,
        answer: "Success",
        reasoning: nil,
        confidence: 0.9,
        token_usage:
      )
    end

    it "can record and log in sequence" do
      allow(Smolagents::Types::ObservabilityContext).to receive(:current).and_return(nil)

      event_class = class_double(Smolagents::Events::EvaluationCompleted).as_stubbed_const
      allow(event_class).to receive(:create).and_return(double("event"))

      instance.record_evaluation_to_context(result)
      instance.log_evaluation_result(result, 5)
      instance.emit_evaluation_event(result, 5)

      expect(instance.last_event).not_to be_nil
      expect(mock_logger.messages).not_to be_empty
    end
  end
end
