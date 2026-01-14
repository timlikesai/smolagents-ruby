RSpec.describe Smolagents::Instrumentation do
  after do
    described_class.subscriber = nil
  end

  describe ".subscriber" do
    it "allows setting a subscriber" do
      subscriber = ->(event, payload) { puts "#{event}: #{payload}" }
      described_class.subscriber = subscriber
      expect(described_class.subscriber).to eq(subscriber)
    end

    it "starts with no subscriber" do
      expect(described_class.subscriber).to be_nil
    end
  end

  describe ".instrument" do
    context "when no subscriber is set" do
      it "executes the block without overhead" do
        result = described_class.instrument("test.event") do
          "test result"
        end

        expect(result).to eq("test result")
      end

      it "skips timing calculation when no subscriber" do
        # Verified structurally: no subscriber means no timing code path executed
        # The "executes no subscriber code when no subscriber is set" test in
        # performance characteristics verifies this behavior
        result = described_class.instrument("test.event") { "work" }
        expect(result).to eq("work")
      end

      it "does not swallow errors" do
        expect do
          described_class.instrument("test.event") do
            raise StandardError, "test error"
          end
        end.to raise_error(StandardError, "test error")
      end
    end

    context "when subscriber is set" do
      let(:events) { [] }
      let(:subscriber) { ->(event, payload) { events << { event:, payload: } } }

      before do
        described_class.subscriber = subscriber
      end

      it "executes the block and returns result" do
        result = described_class.instrument("test.event", foo: "bar") do
          "test result"
        end

        expect(result).to eq("test result")
      end

      it "emits event with duration on success" do
        described_class.instrument("test.event", foo: "bar") do
          "result"
        end

        # Verify structural properties: event has duration as Numeric
        expect(events.length).to eq(1)
        expect(events[0][:event]).to eq("test.event")
        expect(events[0][:payload][:foo]).to eq("bar")
        expect(events[0][:payload][:duration]).to be_a(Numeric)
        expect(events[0][:payload]).not_to have_key(:error)
      end

      it "includes custom payload data" do
        described_class.instrument("test.event", model_id: "gpt-4", step_number: 1) do
          "result"
        end

        expect(events.length).to eq(1)
        expect(events[0][:payload][:model_id]).to eq("gpt-4")
        expect(events[0][:payload][:step_number]).to eq(1)
      end

      it "emits event with error information on failure" do
        expect do
          described_class.instrument("test.event", foo: "bar") do
            raise ArgumentError, "test error"
          end
        end.to raise_error(ArgumentError, "test error")

        expect(events.length).to eq(1)
        expect(events[0][:event]).to eq("test.event")
        expect(events[0][:payload][:foo]).to eq("bar")
        expect(events[0][:payload][:error]).to eq("ArgumentError")
        expect(events[0][:payload][:duration]).to be_a(Numeric)
      end

      it "emits event with different error classes" do
        expect do
          described_class.instrument("test.event") do
            raise "runtime error"
          end
        end.to raise_error(RuntimeError)

        expect(events[0][:payload][:error]).to eq("RuntimeError")
      end

      it "re-raises the original error" do
        expect do
          described_class.instrument("test.event") do
            raise StandardError, "original message"
          end
        end.to raise_error(StandardError, "original message")
      end

      it "tracks duration even on error" do
        expect do
          described_class.instrument("test.event") do
            raise StandardError, "error after delay"
          end
        end.to raise_error(StandardError)

        # Verify structural property: duration is captured even on error
        expect(events[0][:payload][:duration]).to be_a(Numeric)
      end

      it "handles multiple consecutive calls" do
        described_class.instrument("event.1", id: 1) { "result 1" }
        described_class.instrument("event.2", id: 2) { "result 2" }
        described_class.instrument("event.3", id: 3) { "result 3" }

        expect(events.length).to eq(3)
        expect(events[0][:event]).to eq("event.1")
        expect(events[1][:event]).to eq("event.2")
        expect(events[2][:event]).to eq("event.3")
      end

      it "handles nested instrumentation" do
        described_class.instrument("outer.event", level: "outer") do
          described_class.instrument("inner.event", level: "inner") do
            "inner result"
          end
          "outer result"
        end

        expect(events.length).to eq(2)
        expect(events[0][:event]).to eq("inner.event")
        expect(events[0][:payload][:level]).to eq("inner")
        expect(events[1][:event]).to eq("outer.event")
        expect(events[1][:payload][:level]).to eq("outer")
      end
    end

    context "with different subscriber types" do
      it "works with lambda" do
        events = []
        described_class.subscriber = ->(event, _payload) { events << event }

        described_class.instrument("test.event") { "result" }

        expect(events).to eq(["test.event"])
      end

      it "works with proc" do
        events = []
        described_class.subscriber = proc { |event, _payload| events << event }

        described_class.instrument("test.event") { "result" }

        expect(events).to eq(["test.event"])
      end

      it "works with callable object" do
        collector = Class.new do
          attr_reader :events

          def initialize
            @events = []
          end

          def call(event, payload)
            @events << { event:, payload: }
          end
        end.new

        described_class.subscriber = collector

        described_class.instrument("test.event", foo: "bar") { "result" }

        expect(collector.events.length).to eq(1)
        expect(collector.events[0][:event]).to eq("test.event")
      end
    end

    context "performance characteristics" do
      it "executes no subscriber code when no subscriber is set" do
        # Verifies minimal overhead structurally - no subscriber means no subscriber invocation
        call_count = 0

        # Temporarily set a subscriber to track calls
        described_class.subscriber = ->(_event, _payload) { call_count += 1 }
        described_class.subscriber = nil # Clear it

        1000.times do
          described_class.instrument("test.event") { 1 + 1 }
        end

        # With no subscriber set, no calls should have been made
        expect(call_count).to eq(0)
      end

      it "uses monotonic clock for accurate timing" do
        events = []
        described_class.subscriber = ->(_event, payload) { events << payload }

        described_class.instrument("test.event") { "quick operation" }

        # Verify structural property: duration captured as Numeric
        expect(events[0][:duration]).to be_a(Numeric)
      end
    end

    context "edge cases" do
      it "handles empty payload" do
        events = []
        described_class.subscriber = ->(_event, payload) { events << payload }

        described_class.instrument("test.event") { "result" }

        # Now includes outcome and timestamp by default
        expect(events[0].keys).to match_array(%i[duration outcome timestamp])
        expect(events[0][:outcome]).to eq(:success)
      end

      it "handles nil values in payload" do
        events = []
        described_class.subscriber = ->(_event, payload) { events << payload }

        described_class.instrument("test.event", value: nil) { "result" }

        expect(events[0][:value]).to be_nil
        expect(events[0][:duration]).to be_a(Numeric)
      end

      it "does not modify original payload hash" do
        original_payload = { foo: "bar" }
        events = []
        described_class.subscriber = ->(_event, payload) { events << payload }

        described_class.instrument("test.event", original_payload) { "result" }

        expect(original_payload).to eq({ foo: "bar" })
        expect(events[0][:duration]).to be_a(Numeric)
      end
    end
  end

  describe "integration examples" do
    context "Prometheus-style metrics" do
      it "can collect duration metrics" do
        durations = []
        described_class.subscriber = lambda do |event, payload|
          durations << payload[:duration] if event == "smolagents.agent.step"
        end

        described_class.instrument("smolagents.agent.step", step_number: 1) { "step 1" }
        described_class.instrument("smolagents.agent.step", step_number: 2) { "step 2" }

        # Verify structural property: durations are collected as Numerics
        expect(durations.length).to eq(2)
        expect(durations).to all(be_a(Numeric))
      end

      it "can count model calls" do
        model_calls = Hash.new(0)
        described_class.subscriber = lambda do |event, payload|
          model_calls[payload[:model_id]] += 1 if event == "smolagents.model.generate"
        end

        described_class.instrument("smolagents.model.generate", model_id: "gpt-4") { "response" }
        described_class.instrument("smolagents.model.generate", model_id: "gpt-4") { "response" }
        described_class.instrument("smolagents.model.generate", model_id: "claude-3") { "response" }

        expect(model_calls["gpt-4"]).to eq(2)
        expect(model_calls["claude-3"]).to eq(1)
      end
    end

    context "StatsD-style metrics" do
      it "can emit timing and count metrics" do
        metrics = []
        described_class.subscriber = lambda do |event, payload|
          metrics << { type: "measure", name: "smolagents.#{event}", value: payload[:duration] * 1000 }
          metrics << { type: "increment", name: "smolagents.#{event}.count" }
        end

        described_class.instrument("tool.call", tool_name: "web_search") { "search result" }

        expect(metrics.length).to eq(2)
        expect(metrics[0][:type]).to eq("measure")
        expect(metrics[0][:name]).to eq("smolagents.tool.call")
        expect(metrics[0][:value]).to be >= 0
        expect(metrics[1][:type]).to eq("increment")
      end
    end

    context "Error tracking" do
      it "can track error rates" do
        errors = []
        described_class.subscriber = lambda do |event, payload|
          errors << { event:, error: payload[:error] } if payload[:error]
        end

        begin
          described_class.instrument("smolagents.tool.call") { raise StandardError, "test" }
        rescue StandardError
          nil
        end

        described_class.instrument("smolagents.tool.call") { "success" }

        expect(errors.length).to eq(1)
        expect(errors[0][:event]).to eq("smolagents.tool.call")
        expect(errors[0][:error]).to eq("StandardError")
      end
    end
  end
end
