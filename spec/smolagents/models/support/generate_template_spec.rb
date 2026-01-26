require "spec_helper"

RSpec.describe Smolagents::Models::ModelSupport::GenerateTemplate do
  let(:test_class) do
    Class.new do
      include Smolagents::Models::ModelSupport::GenerateTemplate

      attr_reader :model_id

      def initialize(model_id:)
        @model_id = model_id
      end

      def build_params(messages, **options)
        { model: model_id, messages: messages.map(&:content), **options }
      end

      def parse_response(response)
        Smolagents::ChatMessage.assistant(response["content"])
      end
    end
  end

  let(:generator) { test_class.new(model_id: "test-model") }
  let(:messages) { [Smolagents::ChatMessage.user("Hello")] }

  describe "#generate_with_instrumentation" do
    it "builds params, calls API, and parses response" do
      result = generator.generate_with_instrumentation(messages, temperature: 0.5) do |params|
        expect(params[:model]).to eq("test-model")
        expect(params[:temperature]).to eq(0.5)
        { "content" => "Hi there!" }
      end

      expect(result).to be_a(Smolagents::ChatMessage)
      expect(result.content).to eq("Hi there!")
    end

    context "with instrumentation subscriber" do
      let(:events) { [] }

      before do
        Smolagents::Instrumentation.subscriber = ->(event, payload) { events << [event, payload] }
      end

      after do
        Smolagents::Instrumentation.subscriber = nil
      end

      it "emits instrumentation event" do
        generator.generate_with_instrumentation(messages) do |_params|
          { "content" => "response" }
        end

        expect(events.length).to eq(1)
        event, payload = events.first
        expect(event).to eq("smolagents.model.generate")
        expect(payload[:model_id]).to eq("test-model")
        expect(payload).to have_key(:model_class)
        expect(payload[:outcome]).to eq(:success)
      end
    end
  end

  describe "#instrument_generate" do
    it "wraps block in instrumentation" do
      result = generator.instrument_generate { "test result" }
      expect(result).to eq("test result")
    end
  end
end
