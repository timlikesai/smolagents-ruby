require "spec_helper"

RSpec.describe Smolagents::Types::PlanningStep do
  let(:input_messages) { [Smolagents::ChatMessage.system("Plan the task...")] }
  let(:output_message) { Smolagents::ChatMessage.assistant("1. Search\n2. Analyze") }
  let(:timing) { Smolagents::Types::Timing.new(start_time: Time.now - 1, end_time: Time.now) }
  let(:token_usage) { Smolagents::Types::TokenUsage.new(input_tokens: 50, output_tokens: 100) }
  let(:step) do
    described_class.new(
      model_input_messages: input_messages,
      model_output_message: output_message,
      plan: "1. Search\n2. Analyze",
      timing:,
      token_usage:
    )
  end

  it_behaves_like "a step type" do
    let(:step) do
      described_class.new(
        model_input_messages: [Smolagents::ChatMessage.system("Plan")],
        model_output_message: Smolagents::ChatMessage.assistant("Done"),
        plan: "Plan",
        timing: nil,
        token_usage: nil
      )
    end
  end

  describe ".new" do
    it "creates a planning step with all attributes" do
      expect(step.model_input_messages).to eq(input_messages)
      expect(step.model_output_message).to eq(output_message)
      expect(step.plan).to eq("1. Search\n2. Analyze")
      expect(step.timing).to eq(timing)
      expect(step.token_usage).to eq(token_usage)
    end

    it "accepts nil timing and token_usage" do
      minimal = described_class.new(
        model_input_messages: [],
        model_output_message: nil,
        plan: "Simple plan",
        timing: nil,
        token_usage: nil
      )
      expect(minimal.timing).to be_nil
      expect(minimal.token_usage).to be_nil
    end
  end

  describe "#to_h" do
    it "returns hash with plan, timing, and token_usage" do
      result = step.to_h
      expect(result[:plan]).to eq("1. Search\n2. Analyze")
      expect(result[:timing]).to be_a(Hash)
      expect(result[:token_usage]).to be_a(Hash)
    end

    it "excludes nil timing" do
      no_timing = described_class.new(
        model_input_messages: [],
        model_output_message: nil,
        plan: "Plan",
        timing: nil,
        token_usage:
      )
      expect(no_timing.to_h).not_to have_key(:timing)
    end

    it "excludes nil token_usage" do
      no_usage = described_class.new(
        model_input_messages: [],
        model_output_message: nil,
        plan: "Plan",
        timing:,
        token_usage: nil
      )
      expect(no_usage.to_h).not_to have_key(:token_usage)
    end
  end

  describe "#to_messages" do
    it "returns input messages followed by output message" do
      messages = step.to_messages
      expect(messages.size).to eq(2)
      expect(messages.first).to eq(input_messages.first)
      expect(messages.last).to eq(output_message)
    end

    context "with summary_mode: true" do
      it "omits input messages" do
        messages = step.to_messages(summary_mode: true)
        expect(messages.size).to eq(1)
        expect(messages.first).to eq(output_message)
      end
    end

    context "with nil output message" do
      let(:no_output) do
        described_class.new(
          model_input_messages: input_messages,
          model_output_message: nil,
          plan: "Plan",
          timing: nil,
          token_usage: nil
        )
      end

      it "excludes nil from messages array" do
        messages = no_output.to_messages
        expect(messages).to eq(input_messages)
        expect(messages).not_to include(nil)
      end
    end

    context "with empty input messages" do
      let(:no_input) do
        described_class.new(
          model_input_messages: [],
          model_output_message: output_message,
          plan: "Plan",
          timing: nil,
          token_usage: nil
        )
      end

      it "returns only output message" do
        messages = no_input.to_messages
        expect(messages).to eq([output_message])
      end
    end
  end

  describe "#deconstruct_keys" do
    it "returns hash for pattern matching" do
      result = step.deconstruct_keys(nil)
      expect(result[:plan]).to eq("1. Search\n2. Analyze")
    end

    it "includes timing and token_usage when present" do
      result = step.deconstruct_keys(nil)
      expect(result).to have_key(:timing)
      expect(result).to have_key(:token_usage)
    end
  end

  describe "pattern matching" do
    it "matches on plan" do
      result = case step
               in { plan: p }
                 p
               end

      expect(result).to eq("1. Search\n2. Analyze")
    end

    it "supports conditional matching" do
      result = case step
               in { plan: /Search/ } then "has search"
               else "no search"
               end

      expect(result).to eq("has search")
    end
  end
end
