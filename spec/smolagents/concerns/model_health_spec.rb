require "spec_helper"
require "webmock/rspec"

RSpec.describe Smolagents::Concerns::ModelHealth do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ModelHealth

      attr_reader :model_id

      def initialize(model_id: "test-model", api_base: "http://localhost:1234/v1")
        @model_id = model_id
        @api_base = api_base
      end

      private

      def models_endpoint_uri
        "#{@api_base}/models"
      end
    end
  end

  let(:instance) { test_class.new }

  describe "#healthy?" do
    context "when server is responding" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_return(status: 200, body: { data: [{ id: "test-model" }] }.to_json)
      end

      it "returns true" do
        expect(instance.healthy?).to be true
      end
    end

    context "when server is not responding" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
      end

      it "returns false" do
        expect(instance.healthy?).to be false
      end
    end

    context "with caching" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_return(status: 200, body: { data: [] }.to_json)
      end

      it "caches results for specified duration" do
        instance.healthy?(cache_for: 10)
        instance.healthy?(cache_for: 10)

        expect(WebMock).to have_requested(:get, "http://localhost:1234/v1/models").once
      end
    end
  end

  describe "#health_check" do
    context "when server is healthy" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_return(status: 200, body: { data: [{ id: "llama3" }] }.to_json)
      end

      it "returns healthy status" do
        result = instance.health_check

        expect(result.status).to eq(:healthy).or eq(:degraded)
        expect(result.healthy? || result.degraded?).to be true
        expect(result.error).to be_nil
        expect(result.model_id).to eq("test-model")
      end

      it "includes latency measurement" do
        result = instance.health_check

        expect(result.latency_ms).to be_a(Integer)
        expect(result.latency_ms).to be >= 0
      end

      it "includes model details" do
        result = instance.health_check

        expect(result.details[:model_count]).to eq(1)
        expect(result.details[:models]).to include("llama3")
      end
    end

    context "when server times out" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_raise(Faraday::TimeoutError.new("timeout"))
      end

      it "returns unhealthy status" do
        result = instance.health_check

        expect(result.status).to eq(:unhealthy)
        expect(result.error).to include("timeout")
      end
    end

    context "when connection fails" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_raise(Faraday::ConnectionFailed.new("refused"))
      end

      it "returns unhealthy status with error" do
        result = instance.health_check

        expect(result.unhealthy?).to be true
        expect(result.error).to include("Connection failed")
      end
    end
  end

  describe "#available_models" do
    before do
      stub_request(:get, "http://localhost:1234/v1/models")
        .to_return(status: 200, body: {
          data: [
            { id: "llama3", object: "model", owned_by: "meta" },
            { id: "mistral", object: "model", owned_by: "mistral" }
          ]
        }.to_json)
    end

    it "returns list of available models" do
      models = instance.available_models

      expect(models.size).to eq(2)
      expect(models.map(&:id)).to contain_exactly("llama3", "mistral")
    end

    it "returns ModelInfo objects" do
      models = instance.available_models

      expect(models.first).to be_a(described_class::ModelInfo)
      expect(models.first.id).to eq("llama3")
      expect(models.first.owned_by).to eq("meta")
    end
  end

  describe "#loaded_model" do
    before do
      stub_request(:get, "http://localhost:1234/v1/models")
        .to_return(status: 200, body: {
          data: [
            { id: "llama3", object: "model", loaded: true },
            { id: "mistral", object: "model", loaded: false }
          ]
        }.to_json)
    end

    it "returns the loaded model when marked" do
      loaded = instance.loaded_model

      expect(loaded.id).to eq("llama3")
      expect(loaded.loaded).to be true
    end
  end

  describe "#on_model_change" do
    before do
      stub_request(:get, "http://localhost:1234/v1/models")
        .to_return(status: 200, body: { data: [{ id: "llama3", loaded: true }] }.to_json)
        .then.to_return(status: 200, body: { data: [{ id: "mistral", loaded: true }] }.to_json)
    end

    it "calls callback when model changes" do
      callback_called = false
      old_model = nil
      new_model = nil

      instance.on_model_change do |old, new|
        callback_called = true
        old_model = old
        new_model = new
      end

      instance.model_changed? # First check - establishes baseline
      instance.clear_health_cache
      instance.model_changed? # Second check - detects change

      expect(callback_called).to be true
      expect(old_model).to eq("llama3")
      expect(new_model).to eq("mistral")
    end
  end

  describe "HealthStatus" do
    let(:status) do
      described_class::HealthStatus.new(
        status: :healthy,
        latency_ms: 50,
        error: nil,
        checked_at: Time.now,
        model_id: "test",
        details: { model_count: 1 }
      )
    end

    it "provides convenience predicates" do
      expect(status.healthy?).to be true
      expect(status.degraded?).to be false
      expect(status.unhealthy?).to be false
    end

    it "converts to hash" do
      hash = status.to_h
      expect(hash[:status]).to eq(:healthy)
      expect(hash[:latency_ms]).to eq(50)
    end
  end
end
