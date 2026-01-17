require "spec_helper"

RSpec.describe Smolagents::Concerns::TimingHelpers do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::TimingHelpers
    end
  end

  let(:instance) { test_class.new }

  describe "#monotonic_now" do
    it "returns a Float" do
      expect(instance.monotonic_now).to be_a(Float)
    end

    it "returns increasing values" do
      t1 = instance.monotonic_now
      t2 = instance.monotonic_now
      expect(t2).to be >= t1
    end
  end

  describe "#elapsed_since" do
    it "returns elapsed time as Float" do
      start = instance.monotonic_now
      elapsed = instance.elapsed_since(start)
      expect(elapsed).to be_a(Float)
    end
  end

  describe "#elapsed_ms" do
    it "returns elapsed time in milliseconds" do
      start = instance.monotonic_now
      elapsed = instance.elapsed_ms(start)
      expect(elapsed).to be_a(Float)
    end

    it "rounds to 2 decimal places by default" do
      start = instance.monotonic_now
      elapsed = instance.elapsed_ms(start)
      expect(elapsed.to_s.split(".").last.length).to be <= 2
    end

    it "respects custom precision" do
      start = instance.monotonic_now
      elapsed = instance.elapsed_ms(start, precision: 0)
      expect(elapsed).to eq(elapsed.to_i.to_f)
    end
  end

  describe "#with_timing" do
    it "returns duration as Float" do
      duration = instance.with_timing { nil }
      expect(duration).to be_a(Float)
    end

    it "executes the block" do
      executed = false
      instance.with_timing { executed = true }
      expect(executed).to be true
    end
  end

  describe "#with_timed_result" do
    it "returns array with result and duration" do
      result, duration = instance.with_timed_result { "value" }
      expect(result).to eq("value")
      expect(duration).to be_a(Float)
    end

    it "preserves block return value" do
      result, = instance.with_timed_result { { key: "value" } }
      expect(result).to eq({ key: "value" })
    end

    it "handles nil return value" do
      result, = instance.with_timed_result { nil }
      expect(result).to be_nil
    end
  end
end
