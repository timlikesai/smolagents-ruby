require "spec_helper"

RSpec.describe Smolagents::Concerns::CircuitBreaker do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::CircuitBreaker
    end
  end

  let(:instance) { test_class.new }
  let(:emitted_events) { [] }

  before do
    Stoplight.default_data_store = Stoplight::DataStore::Memory.new
    Stoplight.default_notifiers = []

    # Capture emitted events
    allow(instance).to receive(:emit) { |event| emitted_events << event }
  end

  describe "#with_circuit_breaker" do
    it "returns result on successful operation" do
      result = instance.with_circuit_breaker("test_circuit") do
        "success"
      end

      expect(result).to eq("success")
    end

    it "allows multiple successful operations" do
      5.times do
        result = instance.with_circuit_breaker("test_circuit") do
          "success"
        end
        expect(result).to eq("success")
      end
    end

    it "passes through the first failure" do
      expect do
        instance.with_circuit_breaker("test_circuit") do
          raise StandardError, "API error"
        end
      end.to raise_error(StandardError, "API error")
    end

    it "passes through the second failure" do
      expect do
        instance.with_circuit_breaker("test_circuit") do
          raise StandardError, "API error"
        end
      end.to raise_error(StandardError)

      expect do
        instance.with_circuit_breaker("test_circuit") do
          raise StandardError, "API error"
        end
      end.to raise_error(StandardError)
    end

    context "when threshold is reached" do
      it "opens circuit after threshold failures (default 3)" do
        3.times do
          expect do
            instance.with_circuit_breaker("test_circuit") do
              raise StandardError, "API error"
            end
          end.to raise_error(StandardError)
        end

        expect do
          instance.with_circuit_breaker("test_circuit") do
            "this should not execute"
          end
        end.to raise_error(Smolagents::AgentGenerationError, /Service unavailable \(circuit open\): test_circuit/)
      end

      it "opens circuit with custom threshold" do
        2.times do
          expect do
            instance.with_circuit_breaker("custom_threshold_circuit", threshold: 2) do
              raise StandardError, "API error"
            end
          end.to raise_error(StandardError)
        end

        expect do
          instance.with_circuit_breaker("custom_threshold_circuit", threshold: 2) do
            "this should not execute"
          end
        end.to raise_error(Smolagents::AgentGenerationError,
                           /Service unavailable \(circuit open\): custom_threshold_circuit/)
      end

      it "prevents execution when circuit is open" do
        3.times do
          expect do
            instance.with_circuit_breaker("test_circuit") do
              raise StandardError, "API error"
            end
          end.to raise_error(StandardError)
        end

        executed = false
        expect do
          instance.with_circuit_breaker("test_circuit") do
            executed = true
            "success"
          end
        end.to raise_error(Smolagents::AgentGenerationError)

        expect(executed).to be false
      end
    end

    context "with multiple circuits" do
      it "maintains separate state for different circuits" do
        3.times do
          expect do
            instance.with_circuit_breaker("circuit_a") do
              raise StandardError, "API error"
            end
          end.to raise_error(StandardError)
        end

        expect do
          instance.with_circuit_breaker("circuit_a") do
            "should not execute"
          end
        end.to raise_error(Smolagents::AgentGenerationError, /circuit_a/)

        result = instance.with_circuit_breaker("circuit_b") do
          "success"
        end
        expect(result).to eq("success")
      end
    end

    context "when circuit recovers" do
      it "allows retry after cool_off period with custom cool_off time" do
        3.times do
          expect do
            instance.with_circuit_breaker("quick_recovery", cool_off: 1) do
              raise StandardError, "API error"
            end
          end.to raise_error(StandardError)
        end

        expect do
          instance.with_circuit_breaker("quick_recovery", cool_off: 1) do
            "should not execute"
          end
        end.to raise_error(Smolagents::AgentGenerationError)

        Timecop.travel(Time.now + 2)

        result = instance.with_circuit_breaker("quick_recovery", cool_off: 1) do
          "recovered"
        end
        expect(result).to eq("recovered")
      end
    end

    context "when handling errors" do
      it "raises AgentGenerationError when circuit is open" do
        3.times do
          expect do
            instance.with_circuit_breaker("test_circuit") do
              raise StandardError, "API error"
            end
          end.to raise_error(StandardError)
        end

        expect do
          instance.with_circuit_breaker("test_circuit") do
            "should not execute"
          end
        end.to raise_error(Smolagents::AgentGenerationError) do |error|
          expect(error.message).to include("Service unavailable")
          expect(error.message).to include("circuit open")
          expect(error.message).to include("test_circuit")
        end
      end

      it "does not catch non-circuit breaker exceptions" do
        expect do
          instance.with_circuit_breaker("test_circuit") do
            raise ArgumentError, "invalid argument"
          end
        end.to raise_error(ArgumentError, "invalid argument")
      end
    end

    context "with realistic API failure scenarios" do
      it "protects against repeated API timeouts" do
        3.times do
          expect do
            instance.with_circuit_breaker("api_timeout") do
              raise Faraday::TimeoutError, "Request timeout"
            end
          end.to raise_error(Faraday::TimeoutError)
        end

        expect do
          instance.with_circuit_breaker("api_timeout") do
            raise Faraday::TimeoutError, "Request timeout"
          end
        end.to raise_error(Smolagents::AgentGenerationError, /Service unavailable/)
      end

      it "protects against repeated connection errors" do
        3.times do
          expect do
            instance.with_circuit_breaker("connection_error") do
              raise Faraday::ConnectionFailed, "Connection refused"
            end
          end.to raise_error(Faraday::ConnectionFailed)
        end

        expect do
          instance.with_circuit_breaker("connection_error") do
            raise Faraday::ConnectionFailed, "Connection refused"
          end
        end.to raise_error(Smolagents::AgentGenerationError, /Service unavailable/)
      end
    end
  end

  describe "integration with model-like class" do
    let(:api_client) do
      Class.new do
        include Smolagents::Concerns::CircuitBreaker

        attr_accessor :fail_count

        def initialize
          @fail_count = 0
        end

        def call_api
          with_circuit_breaker("api_client") do
            if @fail_count > 0
              @fail_count -= 1
              raise StandardError, "API error"
            end
            { response: "Hello, world!" }
          end
        end
      end
    end

    it "allows successful API calls" do
      client = api_client.new
      result = client.call_api
      expect(result[:response]).to eq("Hello, world!")
    end

    it "opens circuit after repeated API failures" do
      client = api_client.new
      client.fail_count = 5

      3.times do
        expect { client.call_api }.to raise_error(StandardError, "API error")
      end

      expect { client.call_api }.to raise_error(Smolagents::AgentGenerationError, /Service unavailable/)
    end
  end

  describe "CircuitStateChanged events" do
    it "emits event when circuit opens after threshold failures" do
      3.times do
        expect do
          instance.with_circuit_breaker("event_circuit") do
            raise StandardError, "API error"
          end
        end.to raise_error(StandardError)
      end

      state_changes = emitted_events.select { |e| e.is_a?(Smolagents::Events::CircuitStateChanged) }
      expect(state_changes).not_to be_empty

      open_event = state_changes.find { |e| e.to_state == :open }
      expect(open_event).not_to be_nil
      expect(open_event.circuit_name).to eq("event_circuit")
      expect(open_event.from_state).to eq(:closed)
      expect(open_event.to_state).to eq(:open)
      expect(open_event.error_count).to be >= 3
      expect(open_event.cool_off_until).to be_a(Time)
    end

    it "does not emit event when state remains unchanged" do
      instance.with_circuit_breaker("stable_circuit") { "success" }

      state_changes = emitted_events.select { |e| e.is_a?(Smolagents::Events::CircuitStateChanged) }
      expect(state_changes).to be_empty
    end

    it "emits event when circuit transitions to half_open after cool_off" do
      # Open the circuit
      3.times do
        expect do
          instance.with_circuit_breaker("recovery_circuit", cool_off: 1) do
            raise StandardError, "API error"
          end
        end.to raise_error(StandardError)
      end

      emitted_events.clear

      # Wait for cool_off period
      Timecop.travel(Time.now + 2)

      # Attempt should transition to half_open
      instance.with_circuit_breaker("recovery_circuit", cool_off: 1) { "recovered" }

      state_changes = emitted_events.select { |e| e.is_a?(Smolagents::Events::CircuitStateChanged) }
      # Should have transition from open->half_open and possibly half_open->closed
      expect(state_changes).not_to be_empty
    end

    it "includes correct predicate methods" do
      3.times do
        expect do
          instance.with_circuit_breaker("predicate_circuit") do
            raise StandardError, "API error"
          end
        end.to raise_error(StandardError)
      end

      state_changes = emitted_events.select { |e| e.is_a?(Smolagents::Events::CircuitStateChanged) }
      open_event = state_changes.find { |e| e.to_state == :open }

      expect(open_event.open?).to be true
      expect(open_event.closed?).to be false
      expect(open_event.half_open?).to be false
    end
  end
end
