require "spec_helper"

RSpec.describe Smolagents::Concerns::Compression::ModelBased do
  let(:model_based_class) do
    Class.new do
      include Smolagents::Concerns::Compression::ModelBased
    end
  end

  let(:instance) { model_based_class.new }

  let(:model) do
    response = Smolagents::Types::ChatMessage.assistant("Concise summary of observations")
    instance_double(Smolagents::Models::Model).tap do |m|
      allow(m).to receive(:generate).and_return(response)
    end
  end

  def build_action_step(number, observations:)
    Smolagents::Types::ActionStep.new(step_number: number, observations:)
  end

  describe ".strategy_name" do
    it "returns :model_based" do
      expect(model_based_class.strategy_name).to eq(:model_based)
    end
  end

  describe "#compress" do
    context "with empty steps" do
      it "returns nil" do
        result = instance.compress([], budget: 200, model:)

        expect(result).to be_nil
      end
    end

    context "with steps to compress" do
      let(:steps) do
        [
          build_action_step(0, observations: "Found Ruby documentation"),
          build_action_step(1, observations: "Searched for version info"),
          build_action_step(2, observations: "Located release notes")
        ]
      end

      it "returns a SummaryStep" do
        result = instance.compress(steps, budget: 200, model:)

        expect(result).to be_a(Smolagents::Types::SummaryStep)
      end

      it "includes summary from model" do
        result = instance.compress(steps, budget: 200, model:)

        expect(result.summary).to eq("Concise summary of observations")
      end

      it "records original step range" do
        result = instance.compress(steps, budget: 200, model:)

        expect(result.original_step_range).to eq(0..2)
      end

      it "records original step count" do
        result = instance.compress(steps, budget: 200, model:)

        expect(result.original_step_count).to eq(3)
      end

      it "calculates tokens saved" do
        result = instance.compress(steps, budget: 200, model:)

        expect(result.tokens_saved).to be >= 0
      end

      it "calls model.generate with summarization prompt" do
        instance.compress(steps, budget: 200, model:)

        expect(model).to have_received(:generate) do |messages, **kwargs|
          expect(messages.size).to eq(1)
          expect(messages.first.role).to eq(:user)
          expect(messages.first.content).to include("Summarize")
          expect(messages.first.content).to include("Found Ruby documentation")
          expect(kwargs[:tools]).to eq([])
          expect(kwargs[:max_tokens]).to eq(200)
        end
      end
    end

    context "with single step" do
      let(:steps) do
        [build_action_step(5, observations: "Single observation")]
      end

      it "creates summary with single-element range" do
        result = instance.compress(steps, budget: 200, model:)

        expect(result.original_step_range).to eq(5..5)
        expect(result.original_step_count).to eq(1)
      end
    end

    context "when step has no observations" do
      let(:steps) do
        [Smolagents::Types::ActionStep.new(step_number: 0, observations: nil)]
      end

      it "falls back to to_h.inspect" do
        instance.compress(steps, budget: 200, model:)

        expect(model).to have_received(:generate) do |messages, **_kwargs|
          # Should include some representation of the step
          expect(messages.first.content).to include("step_number")
        end
      end
    end

    context "when model returns string response" do
      let(:model) do
        instance_double(Smolagents::Models::Model).tap do |m|
          allow(m).to receive(:generate).and_return("Plain string summary")
        end
      end

      let(:steps) do
        [build_action_step(0, observations: "Test observation")]
      end

      it "extracts content from string response" do
        result = instance.compress(steps, budget: 200, model:)

        expect(result.summary).to eq("Plain string summary")
      end
    end
  end

  describe "tokens_saved calculation" do
    it "calculates positive savings for compression" do
      long_observations = "x" * 400
      steps = [
        build_action_step(0, observations: long_observations),
        build_action_step(1, observations: long_observations)
      ]

      result = instance.compress(steps, budget: 200, model:)

      # Summary is shorter than original, so savings should be positive
      expect(result.tokens_saved).to be > 0
    end

    it "returns zero for expansion (no negative savings)" do
      short_observation = "x"
      steps = [build_action_step(0, observations: short_observation)]

      # Model returns longer summary
      long_response = Smolagents::Types::ChatMessage.assistant("x" * 1000)
      allow(model).to receive(:generate).and_return(long_response)

      result = instance.compress(steps, budget: 200, model:)

      expect(result.tokens_saved).to eq(0)
    end
  end
end
