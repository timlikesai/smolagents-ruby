require "json"
require "faraday"
require "webmock/rspec"
require "spec_helper"

WebMock.disable_net_connect!

RSpec.describe Smolagents::Concerns::ModelHealth::Discovery do
  # Test class that includes the Discovery concern
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ModelHealth::Discovery

      attr_accessor :model_id, :api_base, :api_key

      def initialize
        initialize_discovery
        @model_id = "test-model"
        @api_base = "http://localhost:1234/v1"
        @api_key = nil
        @emitted_events = []
      end

      # Track emitted events for testing
      def emit(event)
        @emitted_events << event
        super
      end

      attr_reader :emitted_events

      # Expose private method for testing
      def test_models_request
        models_request
      end
    end
  end

  let(:instance) { test_class.new }

  let(:models_response) do
    {
      "data" => [
        { "id" => "model-a", "object" => "model", "created" => 1_234_567_890, "owned_by" => "test", "loaded" => true },
        { "id" => "model-b", "object" => "model", "created" => 1_234_567_891, "owned_by" => "test", "loaded" => false }
      ]
    }
  end

  before do
    stub_request(:get, "http://localhost:1234/v1/models")
      .to_return(status: 200, body: models_response.to_json, headers: { "Content-Type" => "application/json" })
  end

  describe ".provided_methods" do
    it "documents initialization methods" do
      expect(described_class.provided_methods[:initialization]).to include(:initialize_discovery)
    end

    it "documents query methods" do
      expect(described_class.provided_methods[:queries]).to include(:available_models, :loaded_model, :model_changed?)
    end

    it "documents command methods" do
      expect(described_class.provided_methods[:commands]).to include(:refresh_models, :notify_model_change)
    end

    it "documents callback methods" do
      expect(described_class.provided_methods[:callbacks]).to include(:on_model_change)
    end
  end

  describe "#initialize_discovery" do
    it "initializes model_change_callbacks as an empty array" do
      expect(instance.model_change_callbacks).to eq([])
    end

    it "initializes last_known_model as nil" do
      expect(instance.last_known_model).to be_nil
    end

    it "initializes cache state to nil" do
      expect(instance.cache_valid?).to be false
    end
  end

  describe "#available_models" do
    it "returns an array of ModelInfo objects" do
      models = instance.available_models
      expect(models).to all(be_a(Smolagents::Concerns::ModelHealth::ModelInfo))
    end

    it "parses model data correctly" do
      models = instance.available_models
      expect(models.first.id).to eq("model-a")
      expect(models.first.loaded).to be true
    end

    it "caches the results" do
      instance.available_models
      instance.available_models

      expect(WebMock).to have_requested(:get, "http://localhost:1234/v1/models").once
    end

    it "respects force_refresh: true" do
      instance.available_models
      instance.available_models(force_refresh: true)

      expect(WebMock).to have_requested(:get, "http://localhost:1234/v1/models").twice
    end

    context "when query fails" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "raises DiscoveryError with details" do
        expect { instance.available_models }.to raise_error(Smolagents::DiscoveryError, /Model discovery failed/)
      end
    end
  end

  describe "#loaded_model" do
    it "returns the model marked as loaded" do
      model = instance.loaded_model
      expect(model.id).to eq("model-a")
    end

    context "when no model is marked loaded" do
      let(:models_response) do
        {
          "data" => [
            { "id" => "test-model", "object" => "model", "loaded" => false }
          ]
        }
      end

      it "falls back to matching model_id" do
        model = instance.loaded_model
        expect(model.id).to eq("test-model")
      end
    end

    context "when discovery fails" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_return(status: 500, body: "Error")
      end

      it "raises DiscoveryError by default" do
        expect { instance.loaded_model }.to raise_error(Smolagents::DiscoveryError)
      end

      it "yields to block when provided" do
        result = instance.loaded_model { |_e| "handled" }
        expect(result).to eq("handled")
      end
    end
  end

  describe "#model_changed?" do
    context "when last_known_model is nil" do
      it "returns false" do
        expect(instance.model_changed?).to be false
      end
    end

    context "when model has not changed" do
      before do
        instance.notify_model_change # Set last_known_model
      end

      it "returns false" do
        expect(instance.model_changed?).to be false
      end
    end

    context "when model has changed" do
      before do
        instance.instance_variable_set(:@last_known_model, "old-model")
      end

      it "returns true" do
        expect(instance.model_changed?).to be true
      end
    end

    it "does not modify state (pure query)" do
      instance.instance_variable_set(:@last_known_model, "old-model")
      instance.model_changed?
      expect(instance.last_known_model).to eq("old-model")
    end

    context "when discovery fails" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_return(status: 500, body: "Error")
      end

      it "returns false instead of raising" do
        expect(instance.model_changed?).to be false
      end
    end
  end

  describe "#refresh_models" do
    it "forces a fresh query" do
      instance.available_models
      instance.refresh_models

      expect(WebMock).to have_requested(:get, "http://localhost:1234/v1/models").twice
    end

    it "updates the cache timestamp" do
      expect(instance.cache_valid?).to be false
      instance.refresh_models
      expect(instance.cache_valid?).to be true
    end

    context "when query fails" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_return(status: 500, body: "Server Error")
      end

      it "raises DiscoveryError" do
        expect { instance.refresh_models }.to raise_error(Smolagents::DiscoveryError)
      end
    end
  end

  describe "#notify_model_change" do
    context "when model has changed" do
      before do
        instance.instance_variable_set(:@last_known_model, "old-model")
      end

      it "calls registered callbacks" do
        callback_called = false
        old_model = nil
        new_model = nil

        instance.on_model_change do |old, new|
          callback_called = true
          old_model = old
          new_model = new
        end

        instance.notify_model_change

        expect(callback_called).to be true
        expect(old_model).to eq("old-model")
        expect(new_model).to eq("model-a")
      end

      it "updates last_known_model" do
        instance.notify_model_change
        expect(instance.last_known_model).to eq("model-a")
      end

      it "returns true" do
        expect(instance.notify_model_change).to be true
      end
    end

    context "when model has not changed" do
      before do
        instance.notify_model_change # Set initial state
      end

      it "does not call callbacks" do
        callback_called = false
        instance.on_model_change { callback_called = true }

        instance.notify_model_change

        expect(callback_called).to be false
      end

      it "returns false" do
        expect(instance.notify_model_change).to be false
      end
    end
  end

  describe "#on_model_change" do
    it "registers a callback" do
      callback = proc { |_old, _new| }
      instance.on_model_change(&callback)

      expect(instance.model_change_callbacks).to include(callback)
    end

    it "raises ArgumentError without a block" do
      expect { instance.on_model_change }.to raise_error(ArgumentError, /Block required/)
    end

    it "supports multiple callbacks" do
      callbacks = []
      instance.on_model_change { callbacks << 1 }
      instance.on_model_change { callbacks << 2 }

      expect(instance.model_change_callbacks.size).to eq(2)
    end
  end

  describe "#cache_valid?" do
    it "returns false when cache is empty" do
      expect(instance.cache_valid?).to be false
    end

    it "returns true after refresh" do
      instance.refresh_models
      expect(instance.cache_valid?).to be true
    end

    it "returns false after TTL expires" do
      instance.refresh_models
      # Simulate time passing by setting cache time in the past
      instance.instance_variable_set(:@models_cache_time, Time.now - 61)

      expect(instance.cache_valid?).to be false
    end
  end

  describe "ModelDiscovered event emissions" do
    describe "#refresh_models" do
      it "emits ModelDiscovered for each model" do
        instance.refresh_models

        discovered_events = instance.emitted_events.select { |e| e.is_a?(Smolagents::Events::ModelDiscovered) }
        expect(discovered_events.size).to eq(2)
      end

      it "includes model_id and provider in events" do
        instance.refresh_models

        discovered_events = instance.emitted_events.select { |e| e.is_a?(Smolagents::Events::ModelDiscovered) }

        expect(discovered_events.map(&:model_id)).to contain_exactly("model-a", "model-b")
        expect(discovered_events.first.provider).to eq("test")
      end

      it "sets empty capabilities by default" do
        instance.refresh_models

        discovered_event = instance.emitted_events.find { |e| e.is_a?(Smolagents::Events::ModelDiscovered) }
        expect(discovered_event.capabilities).to eq({})
      end
    end

    describe "#available_models" do
      it "emits ModelDiscovered events on first call" do
        instance.available_models

        discovered_events = instance.emitted_events.select { |e| e.is_a?(Smolagents::Events::ModelDiscovered) }
        expect(discovered_events.size).to eq(2)
      end

      it "does not emit events when using cache" do
        instance.available_models
        instance.emitted_events.clear

        instance.available_models

        discovered_events = instance.emitted_events.select { |e| e.is_a?(Smolagents::Events::ModelDiscovered) }
        expect(discovered_events).to be_empty
      end

      it "emits events on force_refresh" do
        instance.available_models
        instance.emitted_events.clear

        instance.available_models(force_refresh: true)

        discovered_events = instance.emitted_events.select { |e| e.is_a?(Smolagents::Events::ModelDiscovered) }
        expect(discovered_events.size).to eq(2)
      end
    end
  end
end

RSpec.describe Smolagents::DiscoveryError do
  describe ".model_query_failed" do
    it "creates an error with formatted message" do
      error = described_class.model_query_failed("timeout after 10s")
      expect(error.message).to eq("Model discovery failed: timeout after 10s")
    end
  end

  describe ".cache_refresh_failed" do
    it "creates an error with formatted message" do
      error = described_class.cache_refresh_failed("connection refused")
      expect(error.message).to eq("Failed to refresh model cache: connection refused")
    end
  end

  describe ".endpoint_unavailable" do
    it "creates an error with formatted message" do
      error = described_class.endpoint_unavailable("http://localhost:1234/v1/models")
      expect(error.message).to eq("Model endpoint unavailable: http://localhost:1234/v1/models")
    end
  end

  it "inherits from AgentError" do
    expect(described_class.superclass).to eq(Smolagents::Errors::AgentError)
  end
end
