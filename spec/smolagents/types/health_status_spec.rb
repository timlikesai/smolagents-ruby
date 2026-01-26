require "smolagents"

RSpec.describe Smolagents::Types::HealthStatus do
  describe ".healthy" do
    it "creates healthy status" do
      status = described_class.healthy(model_id: "gpt-4", latency_ms: 250)

      expect(status.status).to eq(:healthy)
      expect(status.healthy?).to be true
      expect(status.degraded?).to be false
      expect(status.unhealthy?).to be false
      expect(status.model_id).to eq("gpt-4")
      expect(status.latency_ms).to eq(250)
      expect(status.error).to be_nil
    end

    it "sets checked_at to current time" do
      before = Time.now
      status = described_class.healthy(model_id: "gpt-4", latency_ms: 100)
      after = Time.now

      expect(status.checked_at).to be_between(before, after)
    end

    it "accepts details hash" do
      status = described_class.healthy(
        model_id: "gpt-4",
        latency_ms: 100,
        details: { model_count: 5 }
      )

      expect(status.details).to eq({ model_count: 5 })
    end
  end

  describe ".degraded" do
    it "creates degraded status" do
      status = described_class.degraded(model_id: "gpt-4", latency_ms: 3000)

      expect(status.status).to eq(:degraded)
      expect(status.healthy?).to be false
      expect(status.degraded?).to be true
      expect(status.unhealthy?).to be false
      expect(status.error).to be_nil
    end
  end

  describe ".unhealthy" do
    it "creates unhealthy status with error" do
      status = described_class.unhealthy(
        model_id: "gpt-4",
        error: "Connection refused"
      )

      expect(status.status).to eq(:unhealthy)
      expect(status.healthy?).to be false
      expect(status.degraded?).to be false
      expect(status.unhealthy?).to be true
      expect(status.error).to eq("Connection refused")
      expect(status.latency_ms).to eq(0)
    end

    it "accepts custom latency_ms" do
      status = described_class.unhealthy(
        model_id: "gpt-4",
        error: "Timeout",
        latency_ms: 10_000
      )

      expect(status.latency_ms).to eq(10_000)
    end
  end

  describe "#error?" do
    it "returns true when error present" do
      status = described_class.unhealthy(model_id: "x", error: "error")
      expect(status.error?).to be true
    end

    it "returns false when no error" do
      status = described_class.healthy(model_id: "x", latency_ms: 100)
      expect(status.error?).to be false
    end
  end

  describe "#to_h" do
    it "returns serializable hash" do
      time = Time.now
      status = described_class.new(
        status: :healthy,
        latency_ms: 250,
        error: nil,
        checked_at: time,
        model_id: "gpt-4",
        details: { key: "value" }
      )

      hash = status.to_h

      expect(hash[:status]).to eq(:healthy)
      expect(hash[:latency_ms]).to eq(250)
      expect(hash[:error]).to be_nil
      expect(hash[:checked_at]).to eq(time.iso8601)
      expect(hash[:model_id]).to eq("gpt-4")
      expect(hash[:details]).to eq({ key: "value" })
    end
  end

  describe "pattern matching" do
    it "supports deconstruct_keys" do
      status = described_class.healthy(model_id: "gpt-4", latency_ms: 100)

      case status
      in { status: :healthy, latency_ms: }
        expect(latency_ms).to eq(100)
      else
        raise "Pattern should match"
      end
    end
  end

  describe "immutability" do
    it "is frozen" do
      status = described_class.healthy(model_id: "gpt-4", latency_ms: 100)
      expect(status).to be_frozen
    end
  end
end
