require "spec_helper"

RSpec.describe Smolagents::Concerns::ModelHealth do
  describe "HealthStatus" do
    let(:status) do
      Smolagents::Types::HealthStatus.new(
        status: :healthy,
        latency_ms: 100,
        error: nil,
        checked_at: Time.now,
        model_id: "gpt-4",
        details: { model_count: 5 }
      )
    end

    describe "predicates" do
      it "correctly identifies healthy status" do
        expect(status.healthy?).to be true
        expect(status.degraded?).to be false
        expect(status.unhealthy?).to be false
      end

      it "correctly identifies degraded status" do
        degraded = Smolagents::Types::HealthStatus.new(
          status: :degraded, latency_ms: 3000, error: nil,
          checked_at: Time.now, model_id: "gpt-4", details: {}
        )
        expect(degraded.degraded?).to be true
        expect(degraded.healthy?).to be false
        expect(degraded.unhealthy?).to be false
      end

      it "correctly identifies unhealthy status" do
        unhealthy = Smolagents::Types::HealthStatus.new(
          status: :unhealthy, latency_ms: 10_000, error: "Connection timeout",
          checked_at: Time.now, model_id: "gpt-4", details: {}
        )
        expect(unhealthy.unhealthy?).to be true
        expect(unhealthy.healthy?).to be false
        expect(unhealthy.degraded?).to be false
      end
    end

    describe "#to_h" do
      it "converts to hash with all fields" do
        hash = status.to_h
        expect(hash).to be_a(Hash)
        expect(hash[:status]).to eq(:healthy)
        expect(hash[:latency_ms]).to eq(100)
        expect(hash[:error]).to be_nil
        expect(hash[:checked_at]).to be_a(String)
        expect(hash[:model_id]).to eq("gpt-4")
        expect(hash[:details]).to eq({ model_count: 5 })
      end

      it "converts checked_at to ISO8601 format" do
        now = Time.parse("2024-01-15 10:30:00 UTC")
        health = Smolagents::Types::HealthStatus.new(
          status: :healthy, latency_ms: 50, error: nil,
          checked_at: now, model_id: "test", details: {}
        )
        expect(health.to_h[:checked_at]).to match(/2024-01-15T10:30:00/)
      end

      it "includes error in hash when present" do
        unhealthy = Smolagents::Types::HealthStatus.new(
          status: :unhealthy, latency_ms: 5000, error: "API timeout",
          checked_at: Time.now, model_id: "gpt-4", details: {}
        )
        hash = unhealthy.to_h
        expect(hash[:error]).to eq("API timeout")
      end
    end

    describe "immutability" do
      it "is immutable (Data class)" do
        expect { status.status = :degraded }.to raise_error(NoMethodError)
      end

      it "freezes attributes" do
        expect(status).to be_frozen
      end
    end
  end

  describe "ModelInfo" do
    let(:model_info) do
      Smolagents::Types::ModelInfo.new(
        id: "gpt-4",
        object: "model",
        created: 1_234_567_890,
        owned_by: "openai",
        loaded: true
      )
    end

    describe "attributes" do
      it "stores model id" do
        expect(model_info.id).to eq("gpt-4")
      end

      it "stores object type" do
        expect(model_info.object).to eq("model")
      end

      it "stores creation timestamp" do
        expect(model_info.created).to eq(1_234_567_890)
      end

      it "stores owner" do
        expect(model_info.owned_by).to eq("openai")
      end

      it "stores loaded state" do
        expect(model_info.loaded).to be true
      end
    end

    describe "#to_h" do
      it "converts to hash with all fields" do
        hash = model_info.to_h
        expect(hash).to be_a(Hash)
        expect(hash[:id]).to eq("gpt-4")
        expect(hash[:object]).to eq("model")
        expect(hash[:created]).to eq(1_234_567_890)
        expect(hash[:owned_by]).to eq("openai")
        expect(hash[:loaded]).to be true
      end

      it "handles nil values" do
        model = Smolagents::Types::ModelInfo.new(
          id: "test", object: "model", created: nil, owned_by: nil, loaded: nil
        )
        hash = model.to_h
        expect(hash[:created]).to be_nil
        expect(hash[:owned_by]).to be_nil
        expect(hash[:loaded]).to be_nil
      end
    end

    describe "immutability" do
      it "is immutable" do
        expect { model_info.id = "gpt-3.5" }.to raise_error(NoMethodError)
      end

      it "freezes attributes" do
        expect(model_info).to be_frozen
      end
    end
  end

  describe "HEALTH_THRESHOLDS" do
    it "defines healthy latency threshold" do
      expect(described_class::HEALTH_THRESHOLDS[:healthy_latency_ms]).to eq(1000)
    end

    it "defines degraded latency threshold" do
      expect(described_class::HEALTH_THRESHOLDS[:degraded_latency_ms]).to eq(5000)
    end

    it "defines timeout threshold" do
      expect(described_class::HEALTH_THRESHOLDS[:timeout_ms]).to eq(10_000)
    end

    it "is frozen to prevent modification" do
      expect(described_class::HEALTH_THRESHOLDS).to be_frozen
    end
  end

  describe "ClassMethods#health_thresholds" do
    let(:test_class) do
      Class.new do
        extend Smolagents::Concerns::ModelHealth::ClassMethods
      end
    end

    describe "as getter" do
      it "returns default thresholds when not configured" do
        thresholds = test_class.health_thresholds
        expect(thresholds[:healthy_latency_ms]).to eq(1000)
        expect(thresholds[:degraded_latency_ms]).to eq(5000)
        expect(thresholds[:timeout_ms]).to eq(10_000)
      end

      it "returns configured thresholds" do
        test_class.health_thresholds(healthy_latency_ms: 500)
        thresholds = test_class.health_thresholds
        expect(thresholds[:healthy_latency_ms]).to eq(500)
        expect(thresholds[:degraded_latency_ms]).to eq(5000)
      end
    end

    describe "as setter" do
      it "sets custom healthy latency" do
        test_class.health_thresholds(healthy_latency_ms: 500)
        expect(test_class.health_thresholds[:healthy_latency_ms]).to eq(500)
      end

      it "sets multiple thresholds" do
        test_class.health_thresholds(
          healthy_latency_ms: 300,
          degraded_latency_ms: 2000,
          timeout_ms: 5000
        )
        thresholds = test_class.health_thresholds
        expect(thresholds[:healthy_latency_ms]).to eq(300)
        expect(thresholds[:degraded_latency_ms]).to eq(2000)
        expect(thresholds[:timeout_ms]).to eq(5000)
      end

      it "merges with defaults" do
        test_class.health_thresholds(healthy_latency_ms: 300)
        thresholds = test_class.health_thresholds
        expect(thresholds[:degraded_latency_ms]).to eq(5000)
      end

      it "returns self for chaining" do
        result = test_class.health_thresholds(healthy_latency_ms: 500)
        expect(result).to be_a(Hash)
      end
    end

    it "allows multiple class instances to have different thresholds" do
      class1 = Class.new { extend Smolagents::Concerns::ModelHealth::ClassMethods }
      class2 = Class.new { extend Smolagents::Concerns::ModelHealth::ClassMethods }

      class1.health_thresholds(healthy_latency_ms: 100)
      class2.health_thresholds(healthy_latency_ms: 2000)

      expect(class1.health_thresholds[:healthy_latency_ms]).to eq(100)
      expect(class2.health_thresholds[:healthy_latency_ms]).to eq(2000)
    end
  end
end
