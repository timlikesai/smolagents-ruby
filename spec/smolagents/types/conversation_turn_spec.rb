require "smolagents"

RSpec.describe Smolagents::Types::ConversationTurn do
  let(:timing) { Smolagents::Types::Timing.new(start_time: Time.now - 2, end_time: Time.now) }
  let(:token_usage) { Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50) }
  let(:steps) { %w[step1 step2 step3] }
  let(:turn) do
    described_class.create(
      turn_number: 0,
      task: "Find Ruby docs",
      steps:,
      token_usage:,
      timing:
    )
  end

  it_behaves_like "a frozen type" do
    let(:instance) { turn }
  end

  it_behaves_like "a pattern matchable type" do
    let(:instance) { turn }
  end

  describe ".create" do
    it "creates a turn with all attributes" do
      expect(turn.turn_number).to eq(0)
      expect(turn.task).to eq("Find Ruby docs")
      expect(turn.steps).to eq(steps)
      expect(turn.token_usage).to eq(token_usage)
      expect(turn.timing).to eq(timing)
    end

    it "defaults steps to empty array" do
      minimal = described_class.create(turn_number: 1, task: "Hello")
      expect(minimal.steps).to eq([])
    end

    it "defaults token_usage to nil" do
      minimal = described_class.create(turn_number: 1, task: "Hello")
      expect(minimal.token_usage).to be_nil
    end

    it "defaults timing to nil" do
      minimal = described_class.create(turn_number: 1, task: "Hello")
      expect(minimal.timing).to be_nil
    end

    it "freezes the steps array" do
      expect(turn.steps).to be_frozen
    end
  end

  describe "#step_count" do
    it "returns the number of steps" do
      expect(turn.step_count).to eq(3)
    end

    it "returns zero for empty steps" do
      empty = described_class.create(turn_number: 0, task: "Empty")
      expect(empty.step_count).to eq(0)
    end
  end

  describe "#duration" do
    it "delegates to timing.duration" do
      expect(turn.duration).to be_a(Float)
      expect(turn.duration).to be_within(0.1).of(2.0)
    end

    it "returns nil when timing is nil" do
      no_timing = described_class.create(turn_number: 0, task: "No timing")
      expect(no_timing.duration).to be_nil
    end
  end

  describe "#deconstruct_keys" do
    it "returns hash with all fields" do
      result = turn.deconstruct_keys(nil)
      expect(result[:turn_number]).to eq(0)
      expect(result[:task]).to eq("Find Ruby docs")
      expect(result[:steps]).to eq(steps)
      expect(result[:token_usage]).to eq(token_usage)
      expect(result[:timing]).to eq(timing)
    end
  end

  describe "pattern matching" do
    it "matches on turn_number and task" do
      matched = case turn
                in { turn_number: 0, task: t }
                  t
                else
                  "no match"
                end

      expect(matched).to eq("Find Ruby docs")
    end

    it "supports conditional matching" do
      matched = case turn
                in { task: /Ruby/ } then "ruby task"
                else "other"
                end

      expect(matched).to eq("ruby task")
    end
  end
end
