require "smolagents"

RSpec.describe Smolagents::Types::QueuedRequest do
  let(:result_queue) { Thread::Queue.new }
  let(:messages) { [{ role: "user", content: "Hello" }] }

  describe ".new" do
    it "creates a queued request" do
      request = described_class.new(
        id: "req-123",
        priority: :high,
        messages:,
        kwargs: { temperature: 0.7 },
        result_queue:,
        queued_at: Time.now
      )

      expect(request.id).to eq("req-123")
      expect(request.priority).to eq(:high)
      expect(request.messages).to eq(messages)
      expect(request.kwargs).to eq({ temperature: 0.7 })
      expect(request.result_queue).to eq(result_queue)
    end

    it "is immutable" do
      request = described_class.new(
        id: "x", priority: :normal, messages: [],
        kwargs: {}, result_queue:, queued_at: Time.now
      )
      expect(request).to be_frozen
    end
  end

  describe ".high_priority" do
    it "creates high priority request" do
      request = described_class.high_priority(
        messages:,
        kwargs: { temperature: 0.7 }
      )

      expect(request.priority).to eq(:high)
      expect(request.high_priority?).to be true
      expect(request.messages).to eq(messages)
      expect(request.id).to match(/\A[0-9a-f-]{36}\z/) # UUID format
    end

    it "sets queued_at to current time" do
      before = Time.now
      request = described_class.high_priority(messages:)
      after = Time.now

      expect(request.queued_at).to be_between(before, after)
    end

    it "creates result_queue by default" do
      request = described_class.high_priority(messages:)
      expect(request.result_queue).to be_a(Thread::Queue)
    end
  end

  describe ".normal_priority" do
    it "creates normal priority request" do
      request = described_class.normal_priority(messages:)

      expect(request.priority).to eq(:normal)
      expect(request.high_priority?).to be false
      expect(request.normal_priority?).to be true
    end
  end

  describe "#wait_time" do
    it "calculates time since queued" do
      request = described_class.new(
        id: "x", priority: :normal, messages: [],
        kwargs: {}, result_queue:, queued_at: Time.now - 5
      )

      expect(request.wait_time).to be >= 5
      expect(request.wait_time).to be < 6
    end
  end

  describe "#high_priority?" do
    it "returns true for high priority" do
      request = described_class.high_priority(messages:)
      expect(request.high_priority?).to be true
    end

    it "returns false for normal priority" do
      request = described_class.normal_priority(messages:)
      expect(request.high_priority?).to be false
    end
  end

  describe "#normal_priority?" do
    it "returns true for normal priority" do
      request = described_class.normal_priority(messages:)
      expect(request.normal_priority?).to be true
    end

    it "returns false for high priority" do
      request = described_class.high_priority(messages:)
      expect(request.normal_priority?).to be false
    end
  end

  describe "pattern matching" do
    it "supports deconstruct_keys" do
      request = described_class.high_priority(messages:)

      case request
      in { priority: :high, messages: }
        expect(messages).to eq([{ role: "user", content: "Hello" }])
      else
        raise "Pattern should match"
      end
    end
  end
end
