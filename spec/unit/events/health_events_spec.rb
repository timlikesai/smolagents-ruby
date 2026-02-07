require "json"
require "faraday"
require "webmock/rspec"
require "spec_helper"

WebMock.disable_net_connect!

# rubocop:disable RSpec/DescribeClass -- integration test for event emission
RSpec.describe "Health Check Events" do
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

      def emit(event)
        @emitted_events << event
        super
      end

      attr_reader :emitted_events

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
          Smolagents::Types::ModelInfo.new(
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
        { "id" => "model-a", "owned_by" => "test", "loaded" => true }
      ]
    }
  end

  describe "HealthCheck (phase: :requested) event" do
    before do
      stub_request(:get, "http://localhost:1234/v1/models")
        .to_return(status: 200, body: models_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "is emitted before health check" do
      instance.health_check

      requested = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.requested? }
      completed = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.completed? }

      requested_idx = instance.emitted_events.index(requested)
      completed_idx = instance.emitted_events.index(completed)

      expect(requested_idx).to be < completed_idx
    end

    it "includes model_id" do
      instance.health_check

      event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.requested? }
      expect(event.model_id).to eq("test-model")
    end

    it "has check_type :full for actual checks" do
      instance.health_check

      event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.requested? }
      expect(event.check_type).to eq(:full)
    end

    it "has check_type :cached when using cache" do
      instance.health_check
      instance.emitted_events.clear

      instance.health_check(cache_for: 60)

      event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.requested? }
      expect(event.check_type).to eq(:cached)
    end
  end

  describe "HealthCheck (phase: :completed) event" do
    context "when server is healthy" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_return(status: 200, body: models_response.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "is emitted after health check" do
        instance.health_check

        event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.completed? }
        expect(event).not_to be_nil
      end

      it "includes model_id" do
        instance.health_check

        event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.completed? }
        expect(event.model_id).to eq("test-model")
      end

      it "has healthy status" do
        instance.health_check

        event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.completed? }
        expect(event.status).to eq(:healthy)
      end

      it "captures latency_ms" do
        instance.health_check

        event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.completed? }
        expect(event.latency_ms).to be >= 0
        expect(event.latency_ms).to be_a(Integer)
      end

      it "has nil error" do
        instance.health_check

        event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.completed? }
        expect(event.error).to be_nil
      end
    end

    context "when server is unhealthy" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_return(status: 500, body: "Server Error")
      end

      it "has unhealthy status" do
        instance.health_check

        event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.completed? }
        expect(event.status).to eq(:unhealthy)
      end

      it "captures error_message" do
        instance.health_check

        event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.completed? }
        expect(event.error).not_to be_nil
      end
    end

    context "when connection fails" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
      end

      it "has unhealthy status" do
        instance.health_check

        event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.completed? }
        expect(event.status).to eq(:unhealthy)
      end

      it "captures connection error message" do
        instance.health_check

        event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.completed? }
        expect(event.error).to include("Connection failed")
      end

      it "sets latency_ms to 0 for connection failures" do
        instance.health_check

        event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.completed? }
        expect(event.latency_ms).to eq(0)
      end
    end

    context "when request times out" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_raise(Faraday::TimeoutError.new("Timeout"))
      end

      it "has unhealthy status" do
        instance.health_check

        event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.completed? }
        expect(event.status).to eq(:unhealthy)
      end

      it "captures timeout error" do
        instance.health_check

        event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.completed? }
        expect(event.error).to eq("Request timeout")
      end
    end
  end

  describe "both events per health check" do
    before do
      stub_request(:get, "http://localhost:1234/v1/models")
        .to_return(status: 200, body: models_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "emits exactly one of each phase per check" do
      instance.health_check

      requested_count = instance.emitted_events.count { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.requested? }
      completed_count = instance.emitted_events.count { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.completed? }

      expect(requested_count).to eq(1)
      expect(completed_count).to eq(1)
    end

    it "does not emit completed phase for cached checks" do
      instance.health_check
      instance.emitted_events.clear

      instance.health_check(cache_for: 60)

      completed_count = instance.emitted_events.count { |e| e.is_a?(Smolagents::Events::HealthCheck) && e.completed? }
      expect(completed_count).to eq(0)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
