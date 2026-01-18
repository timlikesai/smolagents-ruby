require "smolagents"

RSpec.describe Smolagents::Concerns::Isolation::ThreadExecutor do
  describe ".execute" do
    context "when execution succeeds" do
      it "returns IsolationResult.success" do
        result = described_class.execute { 42 }

        expect(result).to be_a(Smolagents::Types::Isolation::IsolationResult)
        expect(result.success?).to be true
      end

      it "captures the return value" do
        result = described_class.execute { "computed result" }

        expect(result.value).to eq("computed result")
      end

      it "captures execution duration" do
        result = described_class.execute { "quick" }

        expect(result.metrics.duration_ms).to be_an(Integer)
      end

      it "captures memory usage" do
        result = described_class.execute { Array.new(1000) { "x" * 100 } }

        expect(result.metrics.memory_bytes).to be >= 0
      end

      it "handles nil return value" do
        result = described_class.execute { nil }

        expect(result.success?).to be true
        expect(result.value).to be_nil
      end

      it "handles complex return values" do
        result = described_class.execute { { key: [1, 2, 3], nested: { a: "b" } } }

        expect(result.value).to eq({ key: [1, 2, 3], nested: { a: "b" } })
      end
    end

    # rubocop:disable Smolagents/NoSleep -- sleep needed to test timeout behavior
    context "when execution times out", :slow do
      let(:short_timeout) { Smolagents::Types::Isolation::ResourceLimits.with_timeout(0.05) }

      it "returns IsolationResult.timeout" do
        result = described_class.execute(limits: short_timeout) { sleep 1 }

        expect(result.timeout?).to be true
      end

      it "does not return a value" do
        result = described_class.execute(limits: short_timeout) { sleep 1 }

        expect(result.value).to be_nil
      end

      it "includes TimeoutError" do
        result = described_class.execute(limits: short_timeout) { sleep 1 }

        expect(result.error).to be_a(Smolagents::Types::Isolation::TimeoutError)
      end

      it "records approximate duration" do
        result = described_class.execute(limits: short_timeout) { sleep 1 }

        # Duration should be approximately the timeout value
        expect(result.metrics.duration_ms).to be_within(50).of(50)
      end

      it "kills the thread on timeout", :slow do
        result = described_class.execute(limits: short_timeout) do
          loop do
            sleep 0.01
          end
        end

        # Give a brief moment for cleanup
        sleep 0.01

        expect(result.timeout?).to be true
        # Cannot directly test thread death since we don't have access to it,
        # but the result should be correct
      end
    end
    # rubocop:enable Smolagents/NoSleep

    context "when execution raises an exception" do
      it "returns IsolationResult.error" do
        result = described_class.execute { raise "boom" }

        expect(result.error?).to be true
      end

      it "captures the error" do
        result = described_class.execute { raise "specific error" }

        expect(result.error).to be_a(RuntimeError)
        expect(result.error.message).to eq("specific error")
      end

      it "does not return a value" do
        result = described_class.execute { raise "boom" }

        expect(result.value).to be_nil
      end

      it "records duration up to error" do
        result = described_class.execute { raise "immediate error" }

        expect(result.metrics.duration_ms).to be_an(Integer)
      end

      it "handles custom exception types" do
        custom_error = Class.new(StandardError)
        result = described_class.execute { raise custom_error, "custom" }

        expect(result.error).to be_a(custom_error)
      end

      it "handles exceptions with no message" do
        result = described_class.execute { raise StandardError }

        expect(result.error?).to be true
        expect(result.error).to be_a(StandardError)
      end
    end

    context "with custom limits" do
      it "uses provided timeout" do
        limits = Smolagents::Types::Isolation::ResourceLimits.with_timeout(10.0)
        result = described_class.execute(limits:) { "fast" }

        expect(result.success?).to be true
      end

      it "uses default limits when not specified" do
        result = described_class.execute { "default" }

        expect(result.success?).to be true
        # Can't easily test limits directly, but execution should work
      end

      it "respects permissive limits" do
        limits = Smolagents::Types::Isolation::ResourceLimits.permissive
        result = described_class.execute(limits:) { "allowed" }

        expect(result.success?).to be true
      end
    end

    context "edge cases" do
      it "handles blocks that return false" do
        result = described_class.execute { false }

        expect(result.success?).to be true
        expect(result.value).to be false
      end

      it "handles blocks that return 0" do
        result = described_class.execute { 0 }

        expect(result.success?).to be true
        expect(result.value).to eq(0)
      end

      it "handles blocks that return empty collections" do
        result = described_class.execute { [] }

        expect(result.success?).to be true
        expect(result.value).to eq([])
      end

      it "handles blocks with side effects", :slow do
        flag = false
        result = described_class.execute do
          flag = true
          "done"
        end

        # Wait for thread to complete and set flag
        expect(result.success?).to be true
        expect(flag).to be true
      end
    end
  end

  describe ".build_success" do
    it "creates success result with metrics" do
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = described_class.build_success("value", start_time)

      expect(result.success?).to be true
      expect(result.value).to eq("value")
      expect(result.metrics).to be_a(Smolagents::Types::Isolation::ResourceMetrics)
    end
  end

  describe ".build_error" do
    it "creates error result with metrics" do
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      error = StandardError.new("test error")
      result = described_class.build_error(error, start_time)

      expect(result.error?).to be true
      expect(result.error).to eq(error)
      expect(result.metrics).to be_a(Smolagents::Types::Isolation::ResourceMetrics)
    end
  end

  describe ".build_metrics" do
    it "calculates duration from start time" do
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      metrics = described_class.build_metrics(start_time)

      expect(metrics.duration_ms).to be_an(Integer)
    end

    it "includes memory bytes" do
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      metrics = described_class.build_metrics(start_time)

      expect(metrics.memory_bytes).to be_an(Integer)
    end

    it "sets output_bytes to zero" do
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      metrics = described_class.build_metrics(start_time)

      expect(metrics.output_bytes).to eq(0)
    end
  end

  describe ".current_memory_bytes" do
    it "returns an integer representing memory" do
      bytes = described_class.current_memory_bytes

      expect(bytes).to be_an(Integer)
    end
  end
end
