require "spec_helper"
require "smolagents/testing/test_run"

RSpec.describe Smolagents::Testing::TestRun do
  # Mock test case - use instance_double for verified testing
  let(:test_case) { instance_double(Smolagents::Testing::TestCase, name: "example_test") }

  # Mock result structure - use instance_double for verified testing
  let(:passing_result) do
    instance_double(Smolagents::Testing::TestResult, passed: true, duration: 1.0, steps: 3, tokens: 100)
  end
  let(:failing_result) do
    instance_double(Smolagents::Testing::TestResult, passed: false, duration: 2.0, steps: 5, tokens: 150)
  end

  describe ".new" do
    it "creates a test run with default threshold of 1.0" do
      run = described_class.new(test_case:, results: [passing_result])

      expect(run.test_case).to eq(test_case)
      expect(run.results).to eq([passing_result])
      expect(run.threshold).to eq(1.0)
    end

    it "accepts a custom threshold" do
      run = described_class.new(test_case:, results: [passing_result], threshold: 0.8)

      expect(run.threshold).to eq(0.8)
    end
  end

  describe "#pass_rate" do
    it "returns 1.0 when all results pass" do
      run = described_class.new(test_case:, results: [passing_result, passing_result])

      expect(run.pass_rate).to eq(1.0)
    end

    it "returns 0.0 when all results fail" do
      run = described_class.new(test_case:, results: [failing_result, failing_result])

      expect(run.pass_rate).to eq(0.0)
    end

    it "returns fractional rate for mixed results" do
      run = described_class.new(test_case:, results: [passing_result, failing_result])

      expect(run.pass_rate).to eq(0.5)
    end
  end

  describe "#passed?" do
    it "returns true when pass_rate meets threshold" do
      run = described_class.new(test_case:, results: [passing_result, passing_result], threshold: 1.0)

      expect(run.passed?).to be true
    end

    it "returns true when pass_rate exceeds threshold" do
      run = described_class.new(test_case:, results: [passing_result, passing_result], threshold: 0.5)

      expect(run.passed?).to be true
    end

    it "returns false when pass_rate is below threshold" do
      run = described_class.new(test_case:, results: [passing_result, failing_result], threshold: 0.8)

      expect(run.passed?).to be false
    end
  end

  describe "#failed?" do
    it "returns false when passed" do
      run = described_class.new(test_case:, results: [passing_result], threshold: 1.0)

      expect(run.failed?).to be false
    end

    it "returns true when not passed" do
      run = described_class.new(test_case:, results: [failing_result], threshold: 1.0)

      expect(run.failed?).to be true
    end
  end

  describe "average metrics" do
    let(:results) { [passing_result, failing_result] }
    let(:run) { described_class.new(test_case:, results:) }

    describe "#avg_duration" do
      it "calculates average duration" do
        expect(run.avg_duration).to eq(1.5)
      end
    end

    describe "#avg_steps" do
      it "calculates average steps" do
        expect(run.avg_steps).to eq(4.0)
      end
    end

    describe "#avg_tokens" do
      it "calculates average tokens" do
        expect(run.avg_tokens).to eq(125.0)
      end
    end
  end

  describe "percentile metrics" do
    let(:result1) do
      instance_double(Smolagents::Testing::TestResult, passed: true, duration: 1.0, steps: 3, tokens: 100)
    end
    let(:result2) do
      instance_double(Smolagents::Testing::TestResult, passed: true, duration: 2.0, steps: 4, tokens: 120)
    end
    let(:result3) do
      instance_double(Smolagents::Testing::TestResult, passed: true, duration: 3.0, steps: 5, tokens: 140)
    end
    let(:result4) do
      instance_double(Smolagents::Testing::TestResult, passed: true, duration: 4.0, steps: 6, tokens: 160)
    end
    let(:result5) do
      instance_double(Smolagents::Testing::TestResult, passed: false, duration: 10.0, steps: 10, tokens: 300)
    end
    let(:results) { [result1, result2, result3, result4, result5] }
    let(:run) { described_class.new(test_case:, results:) }

    describe "#p50_duration" do
      it "returns the 50th percentile duration" do
        expect(run.p50_duration).to eq(3.0)
      end
    end

    describe "#p95_duration" do
      it "returns the 95th percentile duration" do
        expect(run.p95_duration).to eq(10.0)
      end
    end

    describe "#p99_duration" do
      it "returns the 99th percentile duration" do
        expect(run.p99_duration).to eq(10.0)
      end
    end
  end

  describe "#summary" do
    let(:results) { [passing_result, failing_result] }
    let(:run) { described_class.new(test_case:, results:, threshold: 0.8) }

    it "returns a hash with all metrics" do
      summary = run.summary

      expect(summary[:test_case]).to eq("example_test")
      expect(summary[:runs]).to eq(2)
      expect(summary[:pass_rate]).to eq(0.5)
      expect(summary[:threshold]).to eq(0.8)
      expect(summary[:avg_duration]).to eq(1.5)
      expect(summary[:avg_steps]).to eq(4.0)
      expect(summary[:avg_tokens]).to eq(125.0)
      expect(summary).to have_key(:p50_duration)
      expect(summary).to have_key(:p99_duration)
    end
  end

  describe "#to_h" do
    it "returns the same as summary" do
      run = described_class.new(test_case:, results: [passing_result])

      expect(run.to_h).to eq(run.summary)
    end
  end

  describe "#deconstruct_keys" do
    it "enables pattern matching" do
      run = described_class.new(test_case:, results: [passing_result, passing_result])

      case run
      in { pass_rate: rate, runs: count } if rate == 1.0
        expect(count).to eq(2)
      else
        raise "Pattern matching failed"
      end
    end
  end
end
