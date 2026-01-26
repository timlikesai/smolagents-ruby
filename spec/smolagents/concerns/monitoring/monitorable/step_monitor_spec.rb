require "spec_helper"

RSpec.describe Smolagents::Concerns::Monitorable::StepMonitor do
  describe "initialization" do
    it "creates a monitor with step name" do
      monitor = described_class.new(:search)
      expect(monitor.step_name).to eq(:search)
    end

    it "accepts metadata" do
      metadata = { query: "ruby", count: 5 }
      monitor = described_class.new(:search, metadata)
      expect(monitor.metadata).to eq(metadata)
    end

    it "initializes with empty metadata" do
      monitor = described_class.new(:search)
      expect(monitor.metadata).to eq({})
    end

    it "initializes timing" do
      monitor = described_class.new(:search)
      expect(monitor.timing).to be_a(Smolagents::Types::Timing)
    end

    it "initializes with no error" do
      monitor = described_class.new(:search)
      expect(monitor.error).to be_nil
    end

    it "initializes with empty metrics" do
      monitor = described_class.new(:search)
      expect(monitor.metrics).to eq({})
    end
  end

  describe "#step_name" do
    it "returns the step name" do
      monitor = described_class.new(:search)
      expect(monitor.step_name).to eq(:search)
    end

    it "can be string or symbol" do
      monitor_sym = described_class.new(:process)
      monitor_str = described_class.new("process")

      expect(monitor_sym.step_name).to eq(:process)
      expect(monitor_str.step_name).to eq("process")
    end
  end

  describe "#metadata" do
    it "returns provided metadata" do
      metadata = { a: 1, b: "test" }
      monitor = described_class.new(:step, metadata)
      expect(monitor.metadata).to eq(metadata)
    end

    it "returns empty hash when not provided" do
      monitor = described_class.new(:step)
      expect(monitor.metadata).to eq({})
    end

    it "is read-only" do
      metadata = { a: 1 }
      monitor = described_class.new(:step, metadata)
      expect(monitor).not_to respond_to(:metadata=)
    end
  end

  describe "#timing" do
    it "returns timing object" do
      monitor = described_class.new(:step)
      expect(monitor.timing).to be_a(Smolagents::Types::Timing)
    end

    it "timing starts immediately" do
      monitor = described_class.new(:step)
      expect(monitor.timing.start_time).to be_a(Time)
    end
  end

  describe "#error" do
    it "defaults to nil" do
      monitor = described_class.new(:step)
      expect(monitor.error).to be_nil
    end

    it "can be set" do
      monitor = described_class.new(:step)
      error = RuntimeError.new("test")
      monitor.error = error
      expect(monitor.error).to eq(error)
    end
  end

  describe "#stop" do
    it "stops the timing" do
      monitor = described_class.new(:step)
      monitor.stop

      expect(monitor.timing.end_time).to be_a(Time)
    end

    it "returns the stopped timing" do
      monitor = described_class.new(:step)
      result = monitor.stop

      expect(result).to be_a(Smolagents::Types::Timing)
      expect(result.end_time).to be_a(Time)
    end

    it "calculates duration" do
      start_time = Time.new(2024, 1, 1, 12, 0, 0)
      end_time = Time.new(2024, 1, 1, 12, 0, 1) # 1 second later

      allow(Time).to receive(:now).and_return(start_time, end_time)
      monitor = described_class.new(:step)
      monitor.stop

      expect(monitor.duration).to eq(1.0)
    end

    it "can be called multiple times" do
      start_time = Time.new(2024, 1, 1, 12, 0, 0)
      first_end = Time.new(2024, 1, 1, 12, 0, 1)
      second_end = Time.new(2024, 1, 1, 12, 0, 2)

      allow(Time).to receive(:now).and_return(start_time, first_end, second_end)
      monitor = described_class.new(:step)
      monitor.stop
      first_stop = monitor.timing.end_time

      monitor.stop
      second_stop = monitor.timing.end_time

      # Second stop updates the timing
      expect(second_stop).to be > first_stop
    end
  end

  describe "#record_metric" do
    it "records a metric" do
      monitor = described_class.new(:step)
      monitor.record_metric(:items_processed, 42)

      expect(monitor.metrics[:items_processed]).to eq(42)
    end

    it "handles symbol keys" do
      monitor = described_class.new(:step)
      monitor.record_metric(:count, 10)

      expect(monitor.metrics[:count]).to eq(10)
    end

    it "converts string keys to symbols" do
      monitor = described_class.new(:step)
      monitor.record_metric("count", 10)

      expect(monitor.metrics[:count]).to eq(10)
    end

    it "returns the recorded value" do
      monitor = described_class.new(:step)
      result = monitor.record_metric(:score, 95)

      expect(result).to eq(95)
    end

    it "overwrites existing metrics" do
      monitor = described_class.new(:step)
      monitor.record_metric(:count, 10)
      monitor.record_metric(:count, 20)

      expect(monitor.metrics[:count]).to eq(20)
    end

    it "handles different value types" do
      monitor = described_class.new(:step)
      monitor.record_metric(:string_val, "test")
      monitor.record_metric(:float_val, 3.14)
      monitor.record_metric(:array_val, [1, 2, 3])
      monitor.record_metric(:hash_val, { a: 1 })

      expect(monitor.metrics[:string_val]).to eq("test")
      expect(monitor.metrics[:float_val]).to eq(3.14)
      expect(monitor.metrics[:array_val]).to eq([1, 2, 3])
      expect(monitor.metrics[:hash_val]).to eq({ a: 1 })
    end
  end

  describe "#metrics" do
    it "returns empty hash initially" do
      monitor = described_class.new(:step)
      expect(monitor.metrics).to eq({})
    end

    it "returns all recorded metrics" do
      monitor = described_class.new(:step)
      monitor.record_metric(:a, 1)
      monitor.record_metric(:b, 2)
      monitor.record_metric(:c, 3)

      expect(monitor.metrics).to eq({ a: 1, b: 2, c: 3 })
    end

    it "reflects updates after recording" do
      monitor = described_class.new(:step)
      monitor.record_metric(:initial, 0)

      metrics = monitor.metrics
      expect(metrics[:initial]).to eq(0)

      monitor.record_metric(:initial, 10)
      expect(monitor.metrics[:initial]).to eq(10)
    end
  end

  describe "#error?" do
    it "returns false when no error" do
      monitor = described_class.new(:step)
      expect(monitor.error?).to be false
    end

    it "returns true when error is set" do
      monitor = described_class.new(:step)
      monitor.error = RuntimeError.new("test")
      expect(monitor.error?).to be true
    end

    it "returns false when error is cleared" do
      monitor = described_class.new(:step)
      monitor.error = RuntimeError.new("test")
      monitor.error = nil
      expect(monitor.error?).to be false
    end
  end

  describe "#duration" do
    it "returns nil while running" do
      monitor = described_class.new(:step)
      # Before stopping, duration should be nil
      expect(monitor.duration).to be_nil
    end

    it "returns duration after stopping" do
      start_time = Time.new(2024, 1, 1, 12, 0, 0)
      end_time = Time.new(2024, 1, 1, 12, 0, 5) # 5 seconds later

      allow(Time).to receive(:now).and_return(start_time, end_time)
      monitor = described_class.new(:step)
      monitor.stop

      expect(monitor.duration).to eq(5.0)
    end

    it "calculates correct duration" do
      start_time = Time.new(2024, 1, 1, 12, 0, 0)
      end_time = Time.new(2024, 1, 1, 12, 0, 0.05) # 50ms later

      allow(Time).to receive(:now).and_return(start_time, end_time)
      monitor = described_class.new(:step)
      monitor.stop

      expect(monitor.duration).to eq(0.05)
    end

    it "returns duration in seconds" do
      start_time = Time.new(2024, 1, 1, 12, 0, 0)
      end_time = Time.new(2024, 1, 1, 12, 0, 2.5) # 2.5 seconds later

      allow(Time).to receive(:now).and_return(start_time, end_time)
      monitor = described_class.new(:step)
      monitor.stop

      duration = monitor.duration
      expect(duration).to be_a(Float)
      expect(duration).to eq(2.5)
    end
  end

  describe "integration" do
    it "tracks full step lifecycle" do
      start_time = Time.new(2024, 1, 1, 12, 0, 0)
      end_time = Time.new(2024, 1, 1, 12, 0, 1)

      allow(Time).to receive(:now).and_return(start_time, end_time)
      monitor = described_class.new(:search, { query: "ruby" })

      monitor.record_metric(:queries_made, 1)
      monitor.record_metric(:results_found, 42)

      monitor.stop

      expect(monitor.step_name).to eq(:search)
      expect(monitor.metadata[:query]).to eq("ruby")
      expect(monitor.metrics[:queries_made]).to eq(1)
      expect(monitor.metrics[:results_found]).to eq(42)
      expect(monitor.duration).to eq(1.0)
      expect(monitor.error?).to be false
    end

    it "tracks errors" do
      start_time = Time.new(2024, 1, 1, 12, 0, 0)
      end_time = Time.new(2024, 1, 1, 12, 0, 3)

      allow(Time).to receive(:now).and_return(start_time, end_time)
      monitor = described_class.new(:process)
      error = RuntimeError.new("Processing failed")

      monitor.record_metric(:items_processed, 10)
      monitor.error = error
      monitor.stop

      expect(monitor.error?).to be true
      expect(monitor.error).to eq(error)
      expect(monitor.metrics[:items_processed]).to eq(10)
      expect(monitor.duration).to eq(3.0)
    end

    it "multiple metrics can be accumulated" do
      monitor = described_class.new(:aggregate)

      10.times do |i|
        monitor.record_metric(:items, (i + 1) * 10)
      end

      # Only last one is kept (overwrite)
      expect(monitor.metrics[:items]).to eq(100)
    end
  end

  describe "attributes" do
    it "has read-only step_name" do
      monitor = described_class.new(:test)
      expect(monitor).not_to respond_to(:step_name=)
    end

    it "has read-only metadata" do
      monitor = described_class.new(:test, { a: 1 })
      expect(monitor).not_to respond_to(:metadata=)
    end

    it "has read-only timing" do
      monitor = described_class.new(:test)
      expect(monitor).not_to respond_to(:timing=)
    end

    it "has writable error" do
      monitor = described_class.new(:test)
      error = RuntimeError.new("test")
      monitor.error = error
      expect(monitor.error).to eq(error)
    end
  end
end
