require "json"
require "faraday"
require "webmock/rspec"
require "spec_helper"

RSpec.describe Smolagents::Concerns::ModelHealth::Checks do
  # Test class that includes the Checks concern
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::TimingHelpers
      include Smolagents::Events::Emitter
      include Smolagents::Concerns::ModelHealth::Checks

      attr_accessor :model_id, :api_base

      def initialize
        @model_id = "test-model"
        @api_base = "http://localhost:1234/v1"
        @emitted_events = []
      end

      # Track emitted events for testing
      def emit(event)
        @emitted_events << event
        super
      end

      attr_reader :emitted_events

      # Required by Checks concern
      def models_request(timeout: 10)
        conn = Faraday.new do |f|
          f.options.timeout = timeout
          f.adapter(Faraday.default_adapter)
        end
        JSON.parse(conn.get("#{@api_base}/models").body)
      end

      def parse_models_response(response)
        data = response.is_a?(Hash) ? response : response.to_h
        (data["data"] || []).map do |m|
          Smolagents::Concerns::ModelHealth::ModelInfo.new(
            id: m["id"], object: "model", created: nil, owned_by: m["owned_by"], loaded: m["loaded"]
          )
        end
      end
    end
  end

  let(:instance) { test_class.new }

  let(:models_response) do
    {
      "data" => [
        { "id" => "model-a", "owned_by" => "test", "loaded" => true },
        { "id" => "model-b", "owned_by" => "test", "loaded" => false }
      ]
    }
  end

  before do
    stub_request(:get, "http://localhost:1234/v1/models")
      .to_return(status: 200, body: models_response.to_json, headers: { "Content-Type" => "application/json" })
  end

  describe "#health_check" do
    it "emits HealthCheckRequested with :full check_type" do
      instance.health_check

      requested_event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheckRequested) }
      expect(requested_event).not_to be_nil
      expect(requested_event.model_id).to eq("test-model")
      expect(requested_event.check_type).to eq(:full)
    end

    it "emits HealthCheckCompleted with healthy status" do
      instance.health_check

      completed_event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheckCompleted) }
      expect(completed_event).not_to be_nil
      expect(completed_event.model_id).to eq("test-model")
      expect(completed_event.status).to eq(:healthy)
      expect(completed_event.latency_ms).to be >= 0
      expect(completed_event.error).to be_nil
    end

    context "when using cache" do
      it "emits HealthCheckRequested with :cached check_type" do
        instance.health_check
        instance.emitted_events.clear

        instance.health_check(cache_for: 60)

        requested_event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheckRequested) }
        expect(requested_event).not_to be_nil
        expect(requested_event.check_type).to eq(:cached)
      end
    end

    context "when server is unavailable" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_return(status: 500, body: "Server Error")
      end

      it "emits HealthCheckCompleted with unhealthy status" do
        instance.health_check

        completed_event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheckCompleted) }
        expect(completed_event).not_to be_nil
        expect(completed_event.status).to eq(:unhealthy)
        expect(completed_event.error).not_to be_nil
      end
    end

    context "when connection fails" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
      end

      it "emits HealthCheckCompleted with unhealthy status and error" do
        instance.health_check

        completed_event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheckCompleted) }
        expect(completed_event.status).to eq(:unhealthy)
        expect(completed_event.error).to include("Connection failed")
      end
    end
  end

  describe "#healthy?" do
    it "returns true when server responds" do
      expect(instance.healthy?).to be true
    end

    context "when server is unavailable" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_return(status: 500, body: "Server Error")
      end

      it "returns false" do
        expect(instance.healthy?).to be false
      end
    end
  end
end
