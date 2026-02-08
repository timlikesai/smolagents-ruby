require "smolagents"

RSpec.describe Smolagents::Types::FailureSnapshot do
  let(:now) { Time.now }
  let(:instance) do
    described_class.new(
      timestamp: now,
      model_id: "gemma-3n",
      error_class: "RuntimeError",
      error_message: "Connection refused",
      request_summary: "POST /v1/chat/completions (2048 tokens)",
      response_summary: "500 Internal Server Error",
      step_number: 3
    )
  end
  let(:instance_a) do
    described_class.new(
      timestamp: now,
      model_id: "gemma-3n",
      error_class: "RuntimeError",
      error_message: "Connection refused",
      request_summary: "POST /v1/chat/completions",
      response_summary: "500 Internal Server Error",
      step_number: 1
    )
  end
  let(:instance_b) do
    described_class.new(
      timestamp: now,
      model_id: "llama-3",
      error_class: "Timeout::Error",
      error_message: "execution expired",
      request_summary: "POST /v1/completions",
      response_summary: "504 Gateway Timeout",
      step_number: 2
    )
  end

  it_behaves_like "a data type"
  it_behaves_like "a type with to_h",
                  expected_keys: %i[timestamp model_id error_class error_message
                                    request_summary response_summary step_number]

  describe ".capture" do
    it "creates a snapshot from an error" do
      error = RuntimeError.new("Connection refused")
      snapshot = described_class.capture(
        model_id: "gemma-3n",
        error:,
        request_summary: "POST /v1/chat/completions (2048 tokens)",
        response_summary: "500 Internal Server Error",
        step_number: 3
      )

      expect(snapshot.timestamp).to be_a(Time)
      expect(snapshot.model_id).to eq("gemma-3n")
      expect(snapshot.error_class).to eq("RuntimeError")
      expect(snapshot.error_message).to eq("Connection refused")
      expect(snapshot.request_summary).to eq("POST /v1/chat/completions (2048 tokens)")
      expect(snapshot.response_summary).to eq("500 Internal Server Error")
      expect(snapshot.step_number).to eq(3)
    end

    it "creates a snapshot with minimal args" do
      error = StandardError.new("oops")
      snapshot = described_class.capture(model_id: "test-model", error:)

      expect(snapshot.timestamp).to be_a(Time)
      expect(snapshot.model_id).to eq("test-model")
      expect(snapshot.error_class).to eq("StandardError")
      expect(snapshot.error_message).to eq("oops")
      expect(snapshot.request_summary).to be_nil
      expect(snapshot.response_summary).to be_nil
      expect(snapshot.step_number).to be_nil
    end

    it "truncates long error messages at 500 characters" do
      long_message = "x" * 600
      error = RuntimeError.new(long_message)
      snapshot = described_class.capture(model_id: "test", error:)

      expect(snapshot.error_message.length).to eq(500)
      expect(snapshot.error_message).to end_with("...")
    end

    it "truncates long request summaries at 500 characters" do
      long_summary = "y" * 600
      error = RuntimeError.new("err")
      snapshot = described_class.capture(
        model_id: "test",
        error:,
        request_summary: long_summary
      )

      expect(snapshot.request_summary.length).to eq(500)
      expect(snapshot.request_summary).to end_with("...")
    end

    it "truncates long response summaries at 500 characters" do
      long_summary = "z" * 600
      error = RuntimeError.new("err")
      snapshot = described_class.capture(
        model_id: "test",
        error:,
        response_summary: long_summary
      )

      expect(snapshot.response_summary.length).to eq(500)
      expect(snapshot.response_summary).to end_with("...")
    end
  end

  describe "#summary" do
    it "returns a human-readable one-line summary" do
      summary = instance.summary

      expect(summary).to include(instance.timestamp_short)
      expect(summary).to include("RuntimeError: Connection refused")
      expect(summary).to include("(step 3)")
      expect(summary).to include("model=gemma-3n")
    end

    it "omits step when step_number is nil" do
      snapshot = instance.with(step_number: nil)
      expect(snapshot.summary).not_to include("step")
    end

    it "omits model when model_id is nil" do
      snapshot = instance.with(model_id: nil)
      expect(snapshot.summary).not_to include("model=")
    end
  end

  describe "#timestamp_short" do
    it "formats as HH:MM:SS" do
      expect(instance.timestamp_short).to match(/\A\d{2}:\d{2}:\d{2}\z/)
    end
  end

  describe "#request?" do
    it "returns true when request_summary is present" do
      expect(instance.request?).to be true
    end

    it "returns false when request_summary is nil" do
      snapshot = instance.with(request_summary: nil)
      expect(snapshot.request?).to be false
    end
  end

  describe "#response?" do
    it "returns true when response_summary is present" do
      expect(instance.response?).to be true
    end

    it "returns false when response_summary is nil" do
      snapshot = instance.with(response_summary: nil)
      expect(snapshot.response?).to be false
    end
  end

  describe "#to_h" do
    it "returns serializable hash with ISO 8601 timestamp" do
      hash = instance.to_h

      expect(hash[:timestamp]).to eq(now.iso8601)
      expect(hash[:model_id]).to eq("gemma-3n")
      expect(hash[:error_class]).to eq("RuntimeError")
      expect(hash[:error_message]).to eq("Connection refused")
      expect(hash[:request_summary]).to eq("POST /v1/chat/completions (2048 tokens)")
      expect(hash[:response_summary]).to eq("500 Internal Server Error")
      expect(hash[:step_number]).to eq(3)
    end
  end

  describe "immutability" do
    it "is frozen on creation" do
      expect(instance).to be_frozen
    end

    it "returns a new instance with #with" do
      updated = instance.with(step_number: 5)
      expect(updated.step_number).to eq(5)
      expect(instance.step_number).to eq(3)
      expect(updated).not_to equal(instance)
    end
  end

  describe "pattern matching" do
    it "supports deconstruct_keys" do
      case instance
      in { error_class: "RuntimeError", step_number: 3 }
        matched = true
      end

      expect(matched).to be true
    end

    it "supports filtered key deconstruction" do
      keys = instance.deconstruct_keys(%i[model_id error_class])
      expect(keys).to eq(model_id: "gemma-3n", error_class: "RuntimeError")
    end
  end
end
