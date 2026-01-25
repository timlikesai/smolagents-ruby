RSpec.describe Smolagents::Events do
  describe Smolagents::Events::ConfigurationChanged do
    it "creates ConfigurationChanged event" do
      event = described_class.create

      expect(event).to be_a(described_class)
      expect(event.id).not_to be_nil
      expect(event.created_at).to be_a(Time)
    end

    it "is frozen" do
      event = described_class.create

      expect(event).to be_frozen
    end
  end

  describe Smolagents::Events::HealthCheckRequested do
    it "creates HealthCheckRequested event" do
      event = described_class.create(model_id: "gpt-4", check_type: :full)

      expect(event.model_id).to eq("gpt-4")
      expect(event.check_type).to eq(:full)
    end

    it "has full? predicate" do
      event = described_class.create(model_id: "gpt-4", check_type: :full)

      expect(event.full?).to be true
      expect(event.cached?).to be false
    end

    it "has cached? predicate" do
      event = described_class.create(model_id: "gpt-4", check_type: :cached)

      expect(event.cached?).to be true
      expect(event.full?).to be false
    end
  end

  describe Smolagents::Events::HealthCheckCompleted do
    it "creates HealthCheckCompleted event" do
      event = described_class.create(
        model_id: "gpt-4",
        status: :healthy,
        latency_ms: 150,
        error: nil
      )

      expect(event.model_id).to eq("gpt-4")
      expect(event.status).to eq(:healthy)
      expect(event.latency_ms).to eq(150)
    end

    it "has status predicates" do
      event = described_class.create(
        model_id: "gpt-4",
        status: :healthy,
        latency_ms: 100
      )

      expect(event.healthy?).to be true
      expect(event.degraded?).to be false
      expect(event.unhealthy?).to be false
    end

    it "defaults error to nil" do
      event = described_class.create(
        model_id: "gpt-4",
        status: :healthy,
        latency_ms: 100
      )

      expect(event.error).to be_nil
    end

    it "allows setting error" do
      event = described_class.create(
        model_id: "gpt-4",
        status: :unhealthy,
        latency_ms: 5000,
        error: "Timeout"
      )

      expect(event.error).to eq("Timeout")
    end
  end

  describe Smolagents::Events::ModelDiscovered do
    it "creates ModelDiscovered event" do
      event = described_class.create(
        model_id: "gpt-4",
        provider: "openai",
        capabilities: { vision: true, function_calling: true }
      )

      expect(event.model_id).to eq("gpt-4")
      expect(event.provider).to eq("openai")
    end

    it "freezes capabilities" do
      caps = { vision: true }
      event = described_class.create(
        model_id: "gpt-4",
        provider: "openai",
        capabilities: caps
      )

      expect(event.capabilities).to be_frozen
    end

    it "defaults capabilities to empty hash" do
      event = described_class.create(
        model_id: "gpt-4",
        provider: "openai"
      )

      expect(event.capabilities).to eq({})
    end
  end

  describe Smolagents::Events::ModelChanged do
    it "creates ModelChanged event" do
      event = described_class.create(
        from_model_id: "gpt-3.5",
        to_model_id: "gpt-4"
      )

      expect(event.from_model_id).to eq("gpt-3.5")
      expect(event.to_model_id).to eq("gpt-4")
    end
  end

  describe Smolagents::Events::CircuitStateChanged do
    it "creates CircuitStateChanged event" do
      event = described_class.create(
        circuit_name: "model_api",
        from_state: :closed,
        to_state: :open,
        error_count: 5,
        cool_off_until: Time.now + 60
      )

      expect(event.circuit_name).to eq("model_api")
      expect(event.from_state).to eq(:closed)
      expect(event.to_state).to eq(:open)
    end

    it "has state predicates" do
      event = described_class.create(
        circuit_name: "api",
        from_state: :closed,
        to_state: :half_open,
        error_count: 3,
        cool_off_until: Time.now + 60
      )

      expect(event.half_open?).to be true
      expect(event.closed?).to be false
      expect(event.open?).to be false
    end
  end

  describe Smolagents::Events::RateLimitViolated do
    it "creates RateLimitViolated event" do
      event = described_class.create(
        tool_name: "search",
        retry_after: 60,
        request_count: 100,
        limit_interval: 3600
      )

      expect(event.tool_name).to eq("search")
      expect(event.retry_after).to eq(60)
      expect(event.request_count).to eq(100)
    end
  end

  describe Smolagents::Events::QueueRequestStarted do
    it "creates QueueRequestStarted event" do
      event = described_class.create(
        model_id: "gpt-4",
        queue_depth: 5,
        wait_time: 2.5
      )

      expect(event.model_id).to eq("gpt-4")
      expect(event.queue_depth).to eq(5)
      expect(event.wait_time).to eq(2.5)
    end
  end

  describe Smolagents::Events::QueueRequestCompleted do
    it "creates QueueRequestCompleted event with success" do
      event = described_class.create(
        model_id: "gpt-4",
        duration: 1.5,
        success: true
      )

      expect(event.model_id).to eq("gpt-4")
      expect(event.duration).to eq(1.5)
      expect(event.success).to be true
    end

    it "has success? predicate" do
      event = described_class.create(
        model_id: "gpt-4",
        duration: 1.5,
        success: true
      )

      expect(event.success?).to be true
      expect(event.failure?).to be false
    end

    it "has failure? predicate" do
      event = described_class.create(
        model_id: "gpt-4",
        duration: 1.5,
        success: false
      )

      expect(event.failure?).to be true
      expect(event.success?).to be false
    end
  end

  describe Smolagents::Events::RequestFailed do
    it "creates RequestFailed event" do
      error_obj = StandardError.new("Connection timeout")
      event = described_class.create(
        model_id: "gpt-4",
        error: error_obj,
        error_message: "Connection timeout",
        dlq_size: 3
      )

      expect(event.model_id).to eq("gpt-4")
      expect(event.error_message).to eq("Connection timeout")
      expect(event.dlq_size).to eq(3)
    end
  end

  describe Smolagents::Events::RequestRetried do
    it "creates RequestRetried event" do
      event = described_class.create(
        model_id: "gpt-4",
        attempt: 2,
        original_error: "Timeout"
      )

      expect(event.model_id).to eq("gpt-4")
      expect(event.attempt).to eq(2)
      expect(event.original_error).to eq("Timeout")
    end
  end

  describe Smolagents::Events::ToolRetrying do
    it "creates ToolRetrying event" do
      event = described_class.create(
        attempt: 1,
        max_attempts: 3,
        backoff_seconds: 2.0,
        error_message: "Connection failed"
      )

      expect(event.attempt).to eq(1)
      expect(event.max_attempts).to eq(3)
      expect(event.backoff_seconds).to eq(2.0)
      expect(event.error_message).to eq("Connection failed")
    end
  end

  describe "event configuration" do
    it "all events have event_config" do
      events = [
        Smolagents::Events::HealthCheckRequested,
        Smolagents::Events::HealthCheckCompleted,
        Smolagents::Events::CircuitStateChanged
      ]

      events.each do |event_class|
        expect(event_class).to respond_to(:event_config)
        expect(event_class.event_config).to be_a(Smolagents::Events::EventConfig)
      end
    end
  end
end
