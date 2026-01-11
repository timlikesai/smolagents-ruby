require "smolagents/concerns/circuit_breaker"

RSpec.describe Smolagents::Concerns::CircuitBreaker do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::CircuitBreaker
    end
  end

  let(:instance) { test_class.new }

  before do
    Stoplight.default_data_store = Stoplight::DataStore::Memory.new
    Stoplight.default_notifiers = []
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
      # First failure
      expect do
        instance.with_circuit_breaker("test_circuit") do
          raise StandardError, "API error"
        end
      end.to raise_error(StandardError)

      # Second failure
      expect do
        instance.with_circuit_breaker("test_circuit") do
          raise StandardError, "API error"
        end
      end.to raise_error(StandardError)
    end

    context "when threshold is reached" do
      it "opens circuit after threshold failures (default 3)" do
        # Fail 3 times to reach threshold
        3.times do
          expect do
            instance.with_circuit_breaker("test_circuit") do
              raise StandardError, "API error"
            end
          end.to raise_error(StandardError)
        end

        # Circuit should now be open
        expect do
          instance.with_circuit_breaker("test_circuit") do
            "this should not execute"
          end
        end.to raise_error(Smolagents::AgentGenerationError, /Service unavailable \(circuit open\): test_circuit/)
      end

      it "opens circuit with custom threshold" do
        # Custom threshold of 2
        2.times do
          expect do
            instance.with_circuit_breaker("custom_threshold_circuit", threshold: 2) do
              raise StandardError, "API error"
            end
          end.to raise_error(StandardError)
        end

        # Circuit should now be open
        expect do
          instance.with_circuit_breaker("custom_threshold_circuit", threshold: 2) do
            "this should not execute"
          end
        end.to raise_error(Smolagents::AgentGenerationError, /Service unavailable \(circuit open\): custom_threshold_circuit/)
      end

      it "prevents execution when circuit is open" do
        # Open the circuit
        3.times do
          expect do
            instance.with_circuit_breaker("test_circuit") do
              raise StandardError, "API error"
            end
          end.to raise_error(StandardError)
        end

        # Verify circuit is open and block doesn't execute
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
        # Fail one circuit
        3.times do
          expect do
            instance.with_circuit_breaker("circuit_a") do
              raise StandardError, "API error"
            end
          end.to raise_error(StandardError)
        end

        # circuit_a should be open
        expect do
          instance.with_circuit_breaker("circuit_a") do
            "should not execute"
          end
        end.to raise_error(Smolagents::AgentGenerationError, /circuit_a/)

        # circuit_b should still work
        result = instance.with_circuit_breaker("circuit_b") do
          "success"
        end
        expect(result).to eq("success")
      end
    end

    context "circuit recovery" do
      it "allows retry after cool_off period with custom cool_off time" do
        # Open the circuit with very short cool_off for testing
        3.times do
          expect do
            instance.with_circuit_breaker("quick_recovery", cool_off: 1) do
              raise StandardError, "API error"
            end
          end.to raise_error(StandardError)
        end

        # Circuit should be open
        expect do
          instance.with_circuit_breaker("quick_recovery", cool_off: 1) do
            "should not execute"
          end
        end.to raise_error(Smolagents::AgentGenerationError)

        # Wait for cool_off period
        sleep(1.1)

        # Circuit should allow one attempt
        result = instance.with_circuit_breaker("quick_recovery", cool_off: 1) do
          "recovered"
        end
        expect(result).to eq("recovered")
      end
    end

    context "error handling" do
      it "raises AgentGenerationError when circuit is open" do
        # Open the circuit
        3.times do
          expect do
            instance.with_circuit_breaker("test_circuit") do
              raise StandardError, "API error"
            end
          end.to raise_error(StandardError)
        end

        # Verify correct error type and message
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

    context "realistic API failure scenarios" do
      it "protects against repeated API timeouts" do
        # Simulate API timeouts
        3.times do
          expect do
            instance.with_circuit_breaker("api_timeout") do
              raise Faraday::TimeoutError, "Request timeout"
            end
          end.to raise_error(Faraday::TimeoutError)
        end

        # Circuit should now fail fast
        expect do
          instance.with_circuit_breaker("api_timeout") do
            raise Faraday::TimeoutError, "Request timeout"
          end
        end.to raise_error(Smolagents::AgentGenerationError, /Service unavailable/)
      end

      it "protects against repeated connection errors" do
        # Simulate connection errors
        3.times do
          expect do
            instance.with_circuit_breaker("connection_error") do
              raise Faraday::ConnectionFailed, "Connection refused"
            end
          end.to raise_error(Faraday::ConnectionFailed)
        end

        # Circuit should now fail fast
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

      # First 3 failures reach the threshold
      3.times do
        expect { client.call_api }.to raise_error(StandardError, "API error")
      end

      # Circuit should now be open
      expect { client.call_api }.to raise_error(Smolagents::AgentGenerationError, /Service unavailable/)
    end
  end
end
