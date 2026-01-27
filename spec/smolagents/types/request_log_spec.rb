RSpec.describe Smolagents::Types::RequestLog do
  let(:requested_event) do
    Smolagents::Events::ModelGenerateRequested.create(
      model_id: "gpt-4",
      message_count: 3,
      has_tools: true,
      temperature: 0.7
    )
  end

  let(:completed_event) do
    Smolagents::Events::ModelGenerateCompleted.create(
      model_id: "gpt-4",
      duration_ms: 1500,
      token_usage: { input_tokens: 100, output_tokens: 50 },
      has_tool_calls: true,
      outcome: :success
    )
  end

  let(:log) { described_class.from_events(requested_event, completed_event) }

  describe ".from_events" do
    it "creates a log from request and completion events" do
      expect(log).to be_a(described_class)
    end

    it "captures model_id" do
      expect(log.model_id).to eq("gpt-4")
    end

    it "captures duration_ms" do
      expect(log.duration_ms).to eq(1500)
    end

    it "captures message_count" do
      expect(log.message_count).to eq(3)
    end

    it "captures token_usage" do
      expect(log.token_usage).to eq(input_tokens: 100, output_tokens: 50)
    end

    it "captures outcome" do
      expect(log.outcome).to eq(:success)
    end

    it "captures has_tool_calls" do
      expect(log.has_tool_calls).to be true
    end

    it "captures temperature" do
      expect(log.temperature).to eq(0.7)
    end

    it "captures timestamp from requested event" do
      expect(log.timestamp).to eq(requested_event.created_at)
    end
  end

  describe "#success?" do
    it "returns true when outcome is :success" do
      expect(log.success?).to be true
    end

    it "returns false when outcome is :error" do
      error_event = Smolagents::Events::ModelGenerateCompleted.create(
        model_id: "gpt-4",
        duration_ms: 100,
        outcome: :error
      )
      error_log = described_class.from_events(requested_event, error_event)

      expect(error_log.success?).to be false
    end
  end

  describe "#error?" do
    it "returns true when outcome is :error" do
      error_event = Smolagents::Events::ModelGenerateCompleted.create(
        model_id: "gpt-4",
        duration_ms: 100,
        outcome: :error
      )
      error_log = described_class.from_events(requested_event, error_event)

      expect(error_log.error?).to be true
    end

    it "returns false when outcome is :success" do
      expect(log.error?).to be false
    end
  end

  describe "#total_tokens" do
    it "sums input and output tokens" do
      expect(log.total_tokens).to eq(150)
    end

    it "returns nil when token_usage is nil" do
      no_usage_event = Smolagents::Events::ModelGenerateCompleted.create(
        model_id: "gpt-4",
        duration_ms: 100,
        token_usage: nil,
        outcome: :success
      )
      no_usage_log = described_class.from_events(requested_event, no_usage_event)

      expect(no_usage_log.total_tokens).to be_nil
    end
  end

  describe "#input_tokens" do
    it "returns input tokens from usage" do
      expect(log.input_tokens).to eq(100)
    end
  end

  describe "#output_tokens" do
    it "returns output tokens from usage" do
      expect(log.output_tokens).to eq(50)
    end
  end

  describe "#tokens_per_ms" do
    it "calculates throughput" do
      expect(log.tokens_per_ms).to eq(0.1) # 150 tokens / 1500ms
    end

    it "returns nil when token_usage is nil" do
      no_usage_event = Smolagents::Events::ModelGenerateCompleted.create(
        model_id: "gpt-4",
        duration_ms: 100,
        token_usage: nil,
        outcome: :success
      )
      no_usage_log = described_class.from_events(requested_event, no_usage_event)

      expect(no_usage_log.tokens_per_ms).to be_nil
    end

    it "returns nil when duration is zero" do
      zero_duration_event = Smolagents::Events::ModelGenerateCompleted.create(
        model_id: "gpt-4",
        duration_ms: 0,
        token_usage: { input_tokens: 100, output_tokens: 50 },
        outcome: :success
      )
      zero_duration_log = described_class.from_events(requested_event, zero_duration_event)

      expect(zero_duration_log.tokens_per_ms).to be_nil
    end
  end

  describe "#as_json" do
    it "serializes to hash with ISO8601 timestamp" do
      json = log.as_json

      expect(json[:model_id]).to eq("gpt-4")
      expect(json[:duration_ms]).to eq(1500)
      expect(json[:timestamp]).to be_a(String)
      expect { Time.parse(json[:timestamp]) }.not_to raise_error
    end
  end

  describe "immutability" do
    it "is frozen" do
      expect(log).to be_frozen
    end
  end
end
