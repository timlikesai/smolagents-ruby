RSpec.describe Smolagents::Events do
  describe Smolagents::Events::HealthCheck do
    it "creates requested event" do
      event = described_class.create(phase: :requested, model_id: "gpt-4", check_type: :full)

      expect(event.model_id).to eq("gpt-4")
      expect(event.check_type).to eq(:full)
      expect(event.requested?).to be true
    end

    it "creates completed event" do
      event = described_class.create(
        phase: :completed,
        model_id: "gpt-4",
        status: :healthy,
        latency_ms: 150,
        error: nil
      )

      expect(event.model_id).to eq("gpt-4")
      expect(event.status).to eq(:healthy)
      expect(event.latency_ms).to eq(150)
      expect(event.completed?).to be true
    end

    it "defaults error to nil" do
      event = described_class.create(
        phase: :completed,
        model_id: "gpt-4",
        status: :healthy,
        latency_ms: 100
      )

      expect(event.error).to be_nil
    end

    it "allows setting error" do
      event = described_class.create(
        phase: :completed,
        model_id: "gpt-4",
        status: :unhealthy,
        latency_ms: 5000,
        error: "Timeout"
      )

      expect(event.error).to eq("Timeout")
    end
  end

  describe Smolagents::Events::ModelReliability do
    it "creates discovered event" do
      event = described_class.create(
        phase: :discovered,
        model_id: "gpt-4",
        provider: "openai",
        capabilities: { vision: true, function_calling: true }
      )

      expect(event.model_id).to eq("gpt-4")
      expect(event.provider).to eq("openai")
      expect(event.discovered?).to be true
    end

    it "freezes capabilities" do
      caps = { vision: true }
      event = described_class.create(
        phase: :discovered,
        model_id: "gpt-4",
        provider: "openai",
        capabilities: caps
      )

      expect(event.capabilities).to be_frozen
    end

    it "defaults capabilities to empty hash" do
      event = described_class.create(
        phase: :discovered,
        model_id: "gpt-4",
        provider: "openai"
      )

      expect(event.capabilities).to eq({})
    end

    it "creates changed event" do
      event = described_class.create(
        phase: :changed,
        model_id: "gpt-4",
        from_model_id: "gpt-3.5",
        to_model_id: "gpt-4"
      )

      expect(event.from_model_id).to eq("gpt-3.5")
      expect(event.to_model_id).to eq("gpt-4")
      expect(event.changed?).to be true
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

    it "defaults optional fields to nil" do
      event = described_class.create(tool_name: "api", retry_after: 1.0)

      expect(event.request_count).to be_nil
      expect(event.limit_interval).to be_nil
      expect(event.original_request).to be_nil
    end

    it "includes original_request when provided" do
      event = described_class.create(
        tool_name: "api",
        retry_after: 1.0,
        original_request: { query: "test" }
      )

      expect(event.original_request).to eq({ query: "test" })
    end
  end

  describe Smolagents::Events::QueueRequest do
    it "creates started event" do
      event = described_class.create(
        phase: :started,
        model_id: "gpt-4",
        queue_depth: 5,
        wait_time: 2.5
      )

      expect(event.model_id).to eq("gpt-4")
      expect(event.queue_depth).to eq(5)
      expect(event.wait_time).to eq(2.5)
      expect(event.started?).to be true
    end

    it "creates completed event with success" do
      event = described_class.create(
        phase: :completed,
        model_id: "gpt-4",
        duration: 1.5,
        success: true
      )

      expect(event.model_id).to eq("gpt-4")
      expect(event.duration).to eq(1.5)
      expect(event.success).to be true
      expect(event.completed?).to be true
    end
  end

  describe Smolagents::Events::RequestReliability do
    it "creates failed event" do
      event = described_class.create(
        phase: :failed,
        model_id: "gpt-4",
        error_message: "Connection timeout",
        dlq_size: 3
      )

      expect(event.model_id).to eq("gpt-4")
      expect(event.error_message).to eq("Connection timeout")
      expect(event.dlq_size).to eq(3)
      expect(event.failed?).to be true
    end

    it "creates retried event" do
      event = described_class.create(
        phase: :retried,
        model_id: "gpt-4",
        attempt: 2,
        original_error: "Timeout"
      )

      expect(event.model_id).to eq("gpt-4")
      expect(event.attempt).to eq(2)
      expect(event.original_error).to eq("Timeout")
      expect(event.retried?).to be true
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
        Smolagents::Events::HealthCheck,
        Smolagents::Events::ModelReliability,
        Smolagents::Events::CircuitStateChanged
      ]

      events.each do |event_class|
        expect(event_class).to respond_to(:event_config)
        expect(event_class.event_config).to be_a(Smolagents::Events::EventConfig)
      end
    end
  end
end
