RSpec.describe Smolagents::Concerns::Measurable do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Measurable
    end
  end

  let(:instance) { test_class.new }

  describe Smolagents::Concerns::Measurable::TimingResult do
    describe ".new" do
      it "creates immutable timing result" do
        result = described_class.new(value: "test", duration: 1.5, unit: :seconds, error: nil)

        expect(result.value).to eq("test")
        expect(result.duration).to eq(1.5)
        expect(result.unit).to eq(:seconds)
        expect(result.error).to be_nil
      end
    end

    describe "#success?" do
      it "returns true when no error" do
        result = described_class.new(value: "ok", duration: 1.0, unit: :seconds, error: nil)
        expect(result.success?).to be true
      end

      it "returns false when error present" do
        result = described_class.new(value: nil, duration: 1.0, unit: :seconds, error: StandardError.new("failed"))
        expect(result.success?).to be false
      end
    end

    describe "#failed?" do
      it "returns false when no error" do
        result = described_class.new(value: "ok", duration: 1.0, unit: :seconds, error: nil)
        expect(result.failed?).to be false
      end

      it "returns true when error present" do
        result = described_class.new(value: nil, duration: 1.0, unit: :seconds, error: StandardError.new("failed"))
        expect(result.failed?).to be true
      end
    end

    describe "#duration_ms" do
      it "returns duration when unit is milliseconds" do
        result = described_class.new(value: nil, duration: 500.0, unit: :milliseconds, error: nil)
        expect(result.duration_ms).to eq(500.0)
      end

      it "converts seconds to milliseconds" do
        result = described_class.new(value: nil, duration: 1.5, unit: :seconds, error: nil)
        expect(result.duration_ms).to eq(1500.0)
      end
    end

    describe "#duration_s" do
      it "returns duration when unit is seconds" do
        result = described_class.new(value: nil, duration: 1.5, unit: :seconds, error: nil)
        expect(result.duration_s).to eq(1.5)
      end

      it "converts milliseconds to seconds" do
        result = described_class.new(value: nil, duration: 500.0, unit: :milliseconds, error: nil)
        expect(result.duration_s).to eq(0.5)
      end
    end

    describe "#to_h" do
      it "returns hash representation" do
        error = StandardError.new("test error")
        result = described_class.new(value: "data", duration: 1.5, unit: :seconds, error: error)

        hash = result.to_h
        expect(hash[:value]).to eq("data")
        expect(hash[:duration]).to eq(1.5)
        expect(hash[:unit]).to eq(:seconds)
        expect(hash[:error]).to eq("test error")
        expect(hash[:success]).to be false
      end

      it "includes nil error when successful" do
        result = described_class.new(value: "ok", duration: 1.0, unit: :seconds, error: nil)
        expect(result.to_h[:error]).to be_nil
        expect(result.to_h[:success]).to be true
      end
    end

    describe "pattern matching" do
      it "supports pattern matching on success" do
        result = described_class.new(value: "ok", duration: 1.0, unit: :seconds, error: nil)

        case result
        in Smolagents::Concerns::Measurable::TimingResult[value: val, error: nil]
          expect(val).to eq("ok")
        else
          raise "Pattern should have matched"
        end
      end

      it "supports pattern matching on failure" do
        error = StandardError.new("failed")
        result = described_class.new(value: nil, duration: 1.0, unit: :seconds, error: error)

        case result
        in Smolagents::Concerns::Measurable::TimingResult[error: e] if e
          expect(e.message).to eq("failed")
        else
          raise "Pattern should have matched"
        end
      end
    end
  end

  describe "#measure_time" do
    it "returns result and duration as array" do
      result, duration = instance.measure_time { "hello" }

      expect(result).to eq("hello")
      expect(duration).to be_a(Float)
      expect(duration).to be >= 0
    end

    it "measures in seconds by default" do
      result, duration = instance.measure_time { "test" }

      expect(result).to eq("test")
      expect(duration).to be < 1 # should be much less than 1 second
    end

    it "measures in milliseconds when specified" do
      result, duration = instance.measure_time(unit: :milliseconds) { "test" }

      expect(result).to eq("test")
      expect(duration).to be_a(Float)
      expect(duration).to be >= 0
    end

    it "propagates exceptions from block" do
      expect do
        instance.measure_time { raise ArgumentError, "test error" }
      end.to raise_error(ArgumentError, "test error")
    end

    it "calculates duration from clock difference" do
      # Mock clock to return specific times
      call_count = 0
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) do
        call_count += 1
        call_count == 1 ? 100.0 : 100.5 # 0.5 second difference
      end

      _, duration = instance.measure_time { "work" }

      expect(duration).to eq(0.5)
    end

    it "converts to milliseconds correctly" do
      call_count = 0
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) do
        call_count += 1
        call_count == 1 ? 100.0 : 100.025  # 25ms difference
      end

      _, duration = instance.measure_time(unit: :milliseconds) { "work" }

      expect(duration).to eq(25.0)
    end

    it "rounds milliseconds to 2 decimal places" do
      _, duration = instance.measure_time(unit: :milliseconds) { "test" }
      decimal_places = duration.to_s.split(".").last&.length || 0

      expect(decimal_places).to be <= 2
    end
  end

  describe "#measure_timed" do
    it "returns TimingResult on success" do
      timing = instance.measure_timed { "result" }

      expect(timing).to be_a(Smolagents::Concerns::Measurable::TimingResult)
      expect(timing.value).to eq("result")
      expect(timing.success?).to be true
      expect(timing.error).to be_nil
    end

    it "captures exception in TimingResult" do
      timing = instance.measure_timed { raise StandardError, "test error" }

      expect(timing.value).to be_nil
      expect(timing.failed?).to be true
      expect(timing.error).to be_a(StandardError)
      expect(timing.error.message).to eq("test error")
    end

    it "records duration even on failure" do
      timing = instance.measure_timed { raise StandardError, "error" }

      expect(timing.duration).to be_a(Float)
      expect(timing.duration).to be >= 0
    end

    it "uses seconds by default" do
      timing = instance.measure_timed { "test" }
      expect(timing.unit).to eq(:seconds)
    end

    it "uses milliseconds when specified" do
      timing = instance.measure_timed(unit: :milliseconds) { "test" }

      expect(timing.unit).to eq(:milliseconds)
      expect(timing.duration).to be_a(Float)
    end

    it "calculates duration from clock difference" do
      call_count = 0
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) do
        call_count += 1
        call_count == 1 ? 100.0 : 100.025  # 25ms difference
      end

      timing = instance.measure_timed(unit: :milliseconds) { "work" }

      expect(timing.duration).to eq(25.0)
      expect(timing.value).to eq("work")
    end
  end

  describe "integration" do
    it "works when included in a service class" do
      service_class = Class.new do
        include Smolagents::Concerns::Measurable

        def process_request
          result, duration = measure_time { expensive_operation }
          { result: result, duration_ms: (duration * 1000).round }
        end

        private

        def expensive_operation
          "processed"
        end
      end

      service = service_class.new
      response = service.process_request

      expect(response[:result]).to eq("processed")
      expect(response[:duration_ms]).to be >= 0
    end

    it "works with exception handling" do
      service_class = Class.new do
        include Smolagents::Concerns::Measurable

        def safe_operation
          timing = measure_timed { might_fail }
          if timing.success?
            timing.value
          else
            "fallback"
          end
        end

        private

        def might_fail
          raise "oops"
        end
      end

      service = service_class.new
      expect(service.safe_operation).to eq("fallback")
    end
  end
end
