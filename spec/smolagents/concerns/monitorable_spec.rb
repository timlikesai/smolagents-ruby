# frozen_string_literal: true

RSpec.describe Smolagents::Concerns::Monitorable do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Monitorable

      attr_accessor :logger
    end
  end

  let(:instance) { test_class.new }

  describe "#monitor_step" do
    it "executes block and returns result" do
      result = instance.monitor_step(:test_step) do
        "step result"
      end

      expect(result).to eq("step result")
    end

    it "tracks timing automatically" do
      monitor = nil
      instance.monitor_step(:timed_step) do |m|
        monitor = m
        sleep 0.01
        "done"
      end

      expect(monitor.timing).to be_a(Smolagents::Timing)
      expect(monitor.timing.duration).to be > 0
      expect(monitor.timing.duration).to be < 1.0
    end

    it "allows recording custom metrics" do
      monitor = nil
      instance.monitor_step(:custom_metrics) do |m|
        monitor = m
        m.record_metric(:items_processed, 42)
        m.record_metric(:cache_hits, 10)
        "done"
      end

      expect(monitor.metrics[:items_processed]).to eq(42)
      expect(monitor.metrics[:cache_hits]).to eq(10)
    end

    it "includes metadata in monitor" do
      monitor = nil
      instance.monitor_step(:with_metadata, metadata: { user: "alice", task: "search" }) do |m|
        monitor = m
        "done"
      end

      expect(monitor.metadata).to eq({ user: "alice", task: "search" })
    end

    it "calls on_step_complete callback" do
      callback_called = false
      callback_monitor = nil

      instance.register_callback(:on_step_complete) do |_step_name, monitor|
        callback_called = true
        callback_monitor = monitor
      end

      instance.monitor_step(:test) { "done" }

      expect(callback_called).to be true
      expect(callback_monitor).to be_a(Smolagents::Concerns::Monitorable::StepMonitor)
    end

    it "calls on_step_error callback on error" do
      error_callback_called = false
      captured_error = nil

      instance.register_callback(:on_step_error) do |_step_name, error, _monitor|
        error_callback_called = true
        captured_error = error
      end

      expect do
        instance.monitor_step(:failing_step) do
          raise StandardError, "test error"
        end
      end.to raise_error(StandardError, "test error")

      expect(error_callback_called).to be true
      expect(captured_error).to be_a(StandardError)
      expect(captured_error.message).to eq("test error")
    end

    it "records error in monitor when step fails" do
      error_monitor = nil
      instance.register_callback(:on_step_error) do |_, _, monitor|
        error_monitor = monitor
      end

      expect do
        instance.monitor_step(:error_step) { raise "boom" }
      end.to raise_error(RuntimeError, "boom")

      expect(error_monitor.error).to be_a(RuntimeError)
      expect(error_monitor.error?).to be true
    end

    it "logs step start and completion" do
      logger = instance_double(Logger)
      instance.logger = logger

      expect(logger).to receive(:info).with(/Starting step: test/)
      expect(logger).to receive(:info).with(/Completed step: test/)

      instance.monitor_step(:test) { "done" }
    end

    it "logs errors with timing" do
      logger = instance_double(Logger)
      instance.logger = logger

      expect(logger).to receive(:info).with(/Starting step/)
      expect(logger).to receive(:error).with(/Step failed.*after.*: RuntimeError - boom/)

      expect do
        instance.monitor_step(:error) { raise "boom" }
      end.to raise_error(RuntimeError, "boom")
    end
  end

  describe "#track_tokens" do
    it "accumulates token usage" do
      usage1 = Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 20)
      usage2 = Smolagents::TokenUsage.new(input_tokens: 5, output_tokens: 15)

      instance.track_tokens(usage1)
      instance.track_tokens(usage2)

      totals = instance.total_token_usage
      expect(totals[:input]).to eq(15)
      expect(totals[:output]).to eq(35)
    end

    it "calls on_tokens_tracked callback" do
      tracked_usage = nil
      instance.register_callback(:on_tokens_tracked) do |usage|
        tracked_usage = usage
      end

      usage = Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      instance.track_tokens(usage)

      expect(tracked_usage).to eq(usage)
    end

    it "logs token tracking" do
      logger = instance_double(Logger)
      instance.logger = logger

      expect(logger).to receive(:debug).with(/Tokens: \+10 input, \+20 output/)

      usage = Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 20)
      instance.track_tokens(usage)
    end
  end

  describe "#register_callback" do
    it "registers and calls callback" do
      called = false
      instance.register_callback(:on_step_complete) do
        called = true
      end

      instance.monitor_step(:test) { "done" }
      expect(called).to be true
    end

    it "allows multiple callbacks for same event" do
      call_order = []

      instance.register_callback(:on_step_complete) { call_order << :first }
      instance.register_callback(:on_step_complete) { call_order << :second }

      instance.monitor_step(:test) { "done" }
      expect(call_order).to eq(%i[first second])
    end

    it "accepts proc as callback" do
      called = false
      callback = proc { called = true }

      instance.register_callback(:on_step_complete, callback)
      instance.monitor_step(:test) { "done" }

      expect(called).to be true
    end

    it "handles callback errors gracefully" do
      instance.register_callback(:on_step_complete) do
        raise "callback error"
      end

      # Should not raise, just log
      expect do
        instance.monitor_step(:test) { "done" }
      end.not_to raise_error
    end
  end

  describe "#clear_callbacks" do
    it "clears callbacks for specific event" do
      called = false
      instance.register_callback(:on_step_complete) { called = true }
      instance.clear_callbacks(:on_step_complete)

      instance.monitor_step(:test) { "done" }
      expect(called).to be false
    end

    it "clears all callbacks when no event specified" do
      calls = { complete: false, tokens: false }

      instance.register_callback(:on_step_complete) { calls[:complete] = true }
      instance.register_callback(:on_tokens_tracked) { calls[:tokens] = true }

      instance.clear_callbacks

      instance.monitor_step(:test) { "done" }
      usage = Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 20)
      instance.track_tokens(usage)

      expect(calls[:complete]).to be false
      expect(calls[:tokens]).to be false
    end
  end

  describe "#total_token_usage" do
    it "returns zero when no tokens tracked" do
      totals = instance.total_token_usage
      expect(totals).to eq({ input: 0, output: 0 })
    end

    it "returns accumulated totals" do
      instance.track_tokens(Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50))
      instance.track_tokens(Smolagents::TokenUsage.new(input_tokens: 200, output_tokens: 100))

      totals = instance.total_token_usage
      expect(totals[:input]).to eq(300)
      expect(totals[:output]).to eq(150)
    end
  end

  describe "#reset_monitoring" do
    it "resets token usage" do
      instance.track_tokens(Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50))
      instance.reset_monitoring

      totals = instance.total_token_usage
      expect(totals).to eq({ input: 0, output: 0 })
    end
  end

  describe "StepMonitor" do
    let(:monitor) { Smolagents::Concerns::Monitorable::StepMonitor.new(:test_step, { key: "value" }) }

    it "initializes with step name and metadata" do
      expect(monitor.step_name).to eq(:test_step)
      expect(monitor.metadata).to eq({ key: "value" })
    end

    it "starts timing automatically" do
      timing = monitor.timing
      expect(timing).to be_a(Smolagents::Timing)
      expect(timing.start_time).to be_a(Time)
      expect(timing.end_time).to be_nil
    end

    it "records custom metrics" do
      monitor.record_metric(:count, 42)
      monitor.record_metric(:rate, 1.5)

      expect(monitor.metrics[:count]).to eq(42)
      expect(monitor.metrics[:rate]).to eq(1.5)
    end

    it "tracks errors" do
      expect(monitor.error?).to be false

      monitor.error = StandardError.new("test")
      expect(monitor.error?).to be true
    end

    it "calculates duration after stopping" do
      sleep 0.01
      monitor.stop

      expect(monitor.duration).to be > 0
      expect(monitor.duration).to be < 1.0
      expect(monitor.timing.duration).to eq(monitor.duration)
    end
  end

  describe "integration example" do
    it "works in an agent-like class" do
      agent = Class.new do
        include Smolagents::Concerns::Monitorable

        def process_task(task)
          monitor_step(:initialization, metadata: { task: task }) do |monitor|
            # Simulate initialization
            monitor.record_metric(:tools_loaded, 3)
            "initialized"
          end

          monitor_step(:execution) do |monitor|
            # Simulate execution
            monitor.record_metric(:steps_taken, 5)
            "completed"
          end
        end
      end.new

      step_names = []
      agent.register_callback(:on_step_complete) do |name, _|
        step_names << name
      end

      result = agent.process_task("test task")

      expect(result).to eq("completed")
      expect(step_names).to eq(%i[initialization execution])
    end
  end
end
