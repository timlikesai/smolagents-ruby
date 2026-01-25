require "spec_helper"

RSpec.describe Smolagents::Types::WorkResult do
  describe ".success" do
    subject(:result) do
      described_class.success(
        work_item_id: "abc-123",
        value: { response: "Hello" },
        duration_ms: 150,
        metrics: { tokens: 50 }
      )
    end

    it "creates a success result" do
      expect(result.outcome).to eq(:success)
    end

    it "stores the value" do
      expect(result.value).to eq({ response: "Hello" })
    end

    it "stores duration" do
      expect(result.duration_ms).to eq(150)
    end

    it "stores metrics" do
      expect(result.metrics).to eq({ tokens: 50 })
    end

    it "has no error" do
      expect(result.error).to be_nil
    end

    it "freezes metrics" do
      expect(result.metrics).to be_frozen
    end
  end

  describe ".error" do
    subject(:result) do
      described_class.error(
        work_item_id: "abc-123",
        error:,
        duration_ms: 30_000
      )
    end

    let(:error) { StandardError.new("API timeout") }

    it "creates an error result" do
      expect(result.outcome).to eq(:error)
    end

    it "stores the error" do
      expect(result.error).to eq(error)
    end

    it "has no value" do
      expect(result.value).to be_nil
    end
  end

  describe ".timeout" do
    subject(:result) do
      described_class.timeout(
        work_item_id: "abc-123",
        duration_ms: 60_000
      )
    end

    it "creates a timeout result" do
      expect(result.outcome).to eq(:timeout)
    end

    it "has no error" do
      expect(result.error).to be_nil
    end
  end

  describe ".cancelled" do
    subject(:result) do
      described_class.cancelled(work_item_id: "abc-123")
    end

    it "creates a cancelled result" do
      expect(result.outcome).to eq(:cancelled)
    end

    it "has zero duration by default" do
      expect(result.duration_ms).to eq(0)
    end
  end

  describe "outcome predicates" do
    it "identifies success" do
      result = described_class.success(work_item_id: "x", value: nil, duration_ms: 0)
      expect(result.success?).to be true
      expect(result.failed?).to be false
      expect(result.completed?).to be true
    end

    it "identifies error" do
      result = described_class.error(
        work_item_id: "x",
        error: StandardError.new("fail"),
        duration_ms: 0
      )
      expect(result.error?).to be true
      expect(result.failed?).to be true
      expect(result.completed?).to be true
    end

    it "identifies timeout" do
      result = described_class.timeout(work_item_id: "x", duration_ms: 0)
      expect(result.timeout?).to be true
      expect(result.failed?).to be true
      expect(result.completed?).to be true
    end

    it "identifies cancelled" do
      result = described_class.cancelled(work_item_id: "x")
      expect(result.cancelled?).to be true
      expect(result.failed?).to be true
      expect(result.completed?).to be false
    end
  end

  describe "#error_message" do
    it "returns nil when no error" do
      result = described_class.success(work_item_id: "x", value: nil, duration_ms: 0)
      expect(result.error_message).to be_nil
    end

    it "returns the error message" do
      result = described_class.error(
        work_item_id: "x",
        error: StandardError.new("Something went wrong"),
        duration_ms: 0
      )
      expect(result.error_message).to eq("Something went wrong")
    end
  end

  describe "#duration_seconds" do
    it "converts milliseconds to seconds" do
      result = described_class.success(work_item_id: "x", value: nil, duration_ms: 1500)
      expect(result.duration_seconds).to eq(1.5)
    end
  end

  describe "#metric" do
    it "returns metric value by key" do
      result = described_class.success(
        work_item_id: "x",
        value: nil,
        duration_ms: 0,
        metrics: { tokens: 100, cost: 0.01 }
      )
      expect(result.metric(:tokens)).to eq(100)
      expect(result.metric(:cost)).to eq(0.01)
    end

    it "returns nil for missing metric" do
      result = described_class.success(work_item_id: "x", value: nil, duration_ms: 0)
      expect(result.metric(:unknown)).to be_nil
    end
  end

  describe "pattern matching" do
    it "supports deconstruction" do
      result = described_class.success(
        work_item_id: "abc-123",
        value: "done",
        duration_ms: 100
      )

      # rubocop:disable RSpec/DescribedClass -- pattern matching requires literal class
      case result
      in Smolagents::Types::WorkResult[outcome: :success, value:]
        expect(value).to eq("done")
      else
        raise "Pattern did not match"
      end
      # rubocop:enable RSpec/DescribedClass
    end
  end
end
