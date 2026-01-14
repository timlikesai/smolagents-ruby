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
        "done"
      end

      # Verify structural properties: timing object exists and is stopped
      expect(monitor.timing).to be_a(Smolagents::Timing)
      expect(monitor.timing.end_time).to be_a(Time)
      expect(monitor.timing.duration).to be_a(Float)
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

    it "records error in monitor when step fails" do
      error_monitor = nil

      expect do
        instance.monitor_step(:error_step) do |m|
          error_monitor = m
          raise "boom"
        end
      end.to raise_error(RuntimeError, "boom")

      expect(error_monitor.error).to be_a(RuntimeError)
      expect(error_monitor.error?).to be true
    end

    it "logs step start and completion" do
      logger = instance_double(Logger)
      instance.logger = logger

      allow(logger).to receive(:info)

      instance.monitor_step(:test) { "done" }

      expect(logger).to have_received(:info).with(/Starting step: test/)
      expect(logger).to have_received(:info).with(/Completed step: test/)
    end

    it "logs errors with timing" do
      logger = instance_double(Logger)
      instance.logger = logger

      allow(logger).to receive(:info)
      allow(logger).to receive(:error)

      expect do
        instance.monitor_step(:error) { raise "boom" }
      end.to raise_error(RuntimeError, "boom")

      expect(logger).to have_received(:info).with(/Starting step/)
      expect(logger).to have_received(:error).with(/Step failed.*after.*: RuntimeError - boom/)
    end
  end

  describe "#track_tokens" do
    it "accumulates token usage" do
      usage1 = Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 20)
      usage2 = Smolagents::TokenUsage.new(input_tokens: 5, output_tokens: 15)

      instance.track_tokens(usage1)
      instance.track_tokens(usage2)

      totals = instance.total_token_usage
      expect(totals.input_tokens).to eq(15)
      expect(totals.output_tokens).to eq(35)
    end

    it "logs token tracking" do
      logger = instance_double(Logger)
      instance.logger = logger

      allow(logger).to receive(:debug)

      usage = Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 20)
      instance.track_tokens(usage)

      expect(logger).to have_received(:debug).with(/Tokens: \+10 input, \+20 output/)
    end
  end

  describe "#total_token_usage" do
    it "returns zero when no tokens tracked" do
      totals = instance.total_token_usage
      expect(totals).to eq(Smolagents::TokenUsage.zero)
    end

    it "returns accumulated totals" do
      instance.track_tokens(Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50))
      instance.track_tokens(Smolagents::TokenUsage.new(input_tokens: 200, output_tokens: 100))

      totals = instance.total_token_usage
      expect(totals.input_tokens).to eq(300)
      expect(totals.output_tokens).to eq(150)
    end
  end

  describe "#reset_monitoring" do
    it "resets token usage" do
      instance.track_tokens(Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50))
      instance.reset_monitoring

      totals = instance.total_token_usage
      expect(totals).to eq(Smolagents::TokenUsage.zero)
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
      monitor.stop

      # Verify structural properties: duration is calculated and matches timing
      expect(monitor.duration).to be_a(Float)
      expect(monitor.timing.duration).to eq(monitor.duration)
    end
  end

  describe "integration example" do
    it "works in an agent-like class" do
      agent = Class.new do
        include Smolagents::Concerns::Monitorable

        def process_task(task)
          monitor_step(:initialization, metadata: { task: }) do |monitor|
            monitor.record_metric(:tools_loaded, 3)
            "initialized"
          end

          monitor_step(:execution) do |monitor|
            monitor.record_metric(:steps_taken, 5)
            "completed"
          end
        end
      end.new

      result = agent.process_task("test task")

      expect(result).to eq("completed")
      expect(agent.step_monitors.keys).to eq(%i[initialization execution])
    end
  end
end
