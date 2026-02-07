require "spec_helper"

RSpec.describe Smolagents::Concerns::Evaluation do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Evaluation

      def emit(event)
        @last_event = event
      end

      def emitting? = true

      attr_reader :last_event
    end
  end

  let(:instance) { test_class.new }
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
        instance.send(:record_evaluation_to_context, result)
        expect(mock_context).to have_received(:add_tokens).with(token_usage)
      end

      it "records evaluation result to context" do
        instance.send(:record_evaluation_to_context, result)
        expect(mock_context).to have_received(:record_evaluation).with(result)
      end

      it "performs both operations in sequence" do
        call_order = []
        allow(mock_context).to receive(:add_tokens) { call_order << :tokens }
        allow(mock_context).to receive(:record_evaluation) { call_order << :evaluation }

        instance.send(:record_evaluation_to_context, result)

        expect(call_order).to eq(%i[tokens evaluation])
      end
    end

    context "when ObservabilityContext is nil" do
      before do
        allow(Smolagents::Types::ObservabilityContext).to receive(:current).and_return(nil)
      end

      it "does nothing without raising" do
        expect do
          instance.send(:record_evaluation_to_context, result)
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
      instance.send(:emit_evaluation_event, result, 5)

      expect(Smolagents::Events::EvaluationCompleted).to have_received(:create)
    end

    it "includes step_number in event" do
      instance.send(:emit_evaluation_event, result, 5)

      expect(Smolagents::Events::EvaluationCompleted).to have_received(:create).with(
        hash_including(step_number: 5)
      )
    end

    it "includes status in event" do
      instance.send(:emit_evaluation_event, result, 5)

      expect(Smolagents::Events::EvaluationCompleted).to have_received(:create).with(
        hash_including(status: :goal_achieved)
      )
    end

    it "includes answer in event" do
      instance.send(:emit_evaluation_event, result, 5)

      expect(Smolagents::Events::EvaluationCompleted).to have_received(:create).with(
        hash_including(answer: "The answer is 42")
      )
    end

    it "includes confidence in event" do
      instance.send(:emit_evaluation_event, result, 5)

      expect(Smolagents::Events::EvaluationCompleted).to have_received(:create).with(
        hash_including(confidence: 0.95)
      )
    end

    it "includes token_usage in event" do
      instance.send(:emit_evaluation_event, result, 5)

      expect(Smolagents::Events::EvaluationCompleted).to have_received(:create).with(
        hash_including(token_usage:)
      )
    end

    it "includes reasoning in event" do
      result_with_reasoning = Smolagents::Types::EvaluationResult.new(
        status: :stuck,
        answer: nil,
        reasoning: "Cannot find required data",
        confidence: nil,
        token_usage:
      )

      instance.send(:emit_evaluation_event, result_with_reasoning, 3)

      expect(Smolagents::Events::EvaluationCompleted).to have_received(:create).with(
        hash_including(reasoning: "Cannot find required data")
      )
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

    it "records and emits events in sequence" do
      allow(Smolagents::Types::ObservabilityContext).to receive(:current).and_return(nil)

      event_class = class_double(Smolagents::Events::EvaluationCompleted).as_stubbed_const
      allow(event_class).to receive(:create).and_return(double("event"))

      instance.send(:record_evaluation_to_context, result)
      instance.send(:emit_evaluation_event, result, 5)

      expect(instance.last_event).not_to be_nil
    end
  end
end
