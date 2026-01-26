RSpec.describe Smolagents::Testing::SummaryFormatting do
  let(:results) do
    [
      Smolagents::Testing::BenchmarkResult.success(
        model_id: "test-model",
        test_name: "test1",
        level: 1,
        duration: 2.0,
        tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      ),
      Smolagents::Testing::BenchmarkResult.success(
        model_id: "test-model",
        test_name: "test2",
        level: 2,
        duration: 3.0,
        tokens: Smolagents::Types::TokenUsage.new(input_tokens: 150, output_tokens: 75)
      )
    ]
  end

  let(:summary) do
    Smolagents::Testing::BenchmarkSummary.from_results("test-model", results)
  end

  describe "#report" do
    it "returns a formatted report string" do
      report = summary.report

      expect(report).to be_a(String)
      expect(report).to include("test-model")
    end

    it "includes header section" do
      report = summary.report

      expect(report).to include("Model:")
      expect(report).to include("test-model")
    end

    it "includes metrics section" do
      report = summary.report

      expect(report).to include("Rating:")
      expect(report).to include("Pass Rate:")
    end

    it "includes results table" do
      report = summary.report

      expect(report).to include("test1")
      expect(report).to include("test2")
    end

    it "includes separators" do
      report = summary.report

      expect(report).to include("=")
      expect(report).to include("-")
    end
  end

  describe "#capability_flags" do
    it "returns empty string when no capabilities" do
      summary = Smolagents::Testing::BenchmarkSummary.from_results("test", results)

      flags = summary.capability_flags

      expect(flags).to eq("")
    end

    it "includes tool_use when supported" do
      capabilities = instance_double(
        Smolagents::Testing::ModelCapabilities::Capability,
        tool_use?: true,
        vision?: false,
        reasoning: :basic
      )
      summary = Smolagents::Testing::BenchmarkSummary.from_results("test", results, capabilities:)

      flags = summary.capability_flags

      expect(flags).to include("tool_use")
    end

    it "includes vision when supported" do
      capabilities = instance_double(
        Smolagents::Testing::ModelCapabilities::Capability,
        tool_use?: false,
        vision?: true,
        reasoning: :basic
      )
      summary = Smolagents::Testing::BenchmarkSummary.from_results("test", results, capabilities:)

      flags = summary.capability_flags

      expect(flags).to include("vision")
    end

    it "includes reasoning level" do
      capabilities = instance_double(
        Smolagents::Testing::ModelCapabilities::Capability,
        tool_use?: false,
        vision?: false,
        reasoning: :strong
      )
      summary = Smolagents::Testing::BenchmarkSummary.from_results("test", results, capabilities:)

      flags = summary.capability_flags

      expect(flags).to include("strong_reasoning")
    end

    it "combines multiple flags with comma separation" do
      capabilities = instance_double(
        Smolagents::Testing::ModelCapabilities::Capability,
        tool_use?: true,
        vision?: true,
        reasoning: :basic
      )
      summary = Smolagents::Testing::BenchmarkSummary.from_results("test", results, capabilities:)

      flags = summary.capability_flags

      expect(flags).to include("tool_use")
      expect(flags).to include("vision")
      expect(flags).to include("basic_reasoning")
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      hash = summary.to_h

      expect(hash).to be_a(Hash)
      expect(hash[:model_id]).to eq("test-model")
    end

    it "includes model_id" do
      hash = summary.to_h

      expect(hash[:model_id]).to eq("test-model")
    end

    it "includes max_level_passed" do
      hash = summary.to_h

      expect(hash[:max_level_passed]).to eq(2)
    end

    it "includes level_badge" do
      hash = summary.to_h

      expect(hash[:level_badge]).to be_a(String)
    end

    it "includes total_duration" do
      hash = summary.to_h

      expect(hash[:total_duration]).to eq(5.0)
    end

    it "includes total_tokens" do
      hash = summary.to_h

      expect(hash[:total_tokens]).to be_a(Hash)
    end

    it "includes pass_rate" do
      hash = summary.to_h

      expect(hash[:pass_rate]).to eq(1.0)
    end

    it "includes avg_tokens_per_second" do
      hash = summary.to_h

      expect(hash[:avg_tokens_per_second]).to eq(75.0)
    end

    it "includes results array" do
      hash = summary.to_h

      expect(hash[:results]).to be_an(Array)
      expect(hash[:results].size).to eq(2)
    end

    it "converts each result to hash" do
      hash = summary.to_h

      hash[:results].each do |result_hash|
        expect(result_hash).to have_key(:test_name)
        expect(result_hash).to have_key(:level)
        expect(result_hash).to have_key(:passed)
        expect(result_hash).to have_key(:duration)
      end
    end

    it "includes capabilities when present" do
      capabilities = instance_double(
        Smolagents::Testing::ModelCapabilities::Capability,
        to_h: { model_id: "test" }
      )
      summary = Smolagents::Testing::BenchmarkSummary.from_results("test", results, capabilities:)

      hash = summary.to_h

      expect(hash[:capabilities]).to eq({ model_id: "test" })
    end

    it "includes nil capabilities when not present" do
      hash = summary.to_h

      expect(hash[:capabilities]).to be_nil
    end
  end

  describe "private formatting methods" do
    describe "#report_header" do
      it "includes model ID" do
        report = summary.report

        expect(report).to include("test-model")
      end

      it "includes architecture when available" do
        capabilities = instance_double(
          Smolagents::Testing::ModelCapabilities::Capability,
          architecture: "transformer",
          size_str: "7B",
          context_length: 4096,
          tool_use?: false,
          vision?: false,
          reasoning: :basic
        )
        summary = Smolagents::Testing::BenchmarkSummary.from_results("test", results, capabilities:)

        report = summary.report

        expect(report).to include("transformer")
        expect(report).to include("7B")
      end
    end

    describe "#report_metrics" do
      it "includes rating" do
        report = summary.report

        expect(report).to include("Rating:")
      end

      it "includes pass rate" do
        report = summary.report

        expect(report).to include("Pass Rate:")
        expect(report).to include("%")
      end

      it "includes throughput" do
        report = summary.report

        expect(report).to include("Throughput:")
      end

      it "includes total time" do
        report = summary.report

        expect(report).to include("Time:")
      end
    end

    describe "separator" do
      it "appears multiple times in report" do
        report = summary.report

        equals_count = report.count("=" * 70)
        dashes_count = report.count("-" * 70)

        expect(equals_count).to be > 0
        expect(dashes_count).to be > 0
      end
    end
  end

  describe "report completeness" do
    it "includes all test names in report" do
      report = summary.report

      results.each do |result|
        expect(report).to include(result.test_name)
      end
    end

    it "includes pass/fail status for each test" do
      report = summary.report

      results.each do |result|
        expect(report).to include(result.passed? ? "PASS" : "FAIL")
      end
    end

    it "includes duration information" do
      report = summary.report

      expect(report).to include("s") # seconds indicator
    end

    it "includes token throughput" do
      report = summary.report

      expect(report).to include("tok/s")
    end
  end

  describe "formatting edge cases" do
    it "handles summary with no results" do
      empty_summary = Smolagents::Testing::BenchmarkSummary.from_results("test", [])

      report = empty_summary.report

      expect(report).to be_a(String)
      expect(report).to include("test")
    end

    it "handles summary with all failures" do
      failures = [
        Smolagents::Testing::BenchmarkResult.failure(
          model_id: "test",
          test_name: "test1",
          level: 1,
          duration: 1.0,
          error: "Failed"
        )
      ]
      summary = Smolagents::Testing::BenchmarkSummary.from_results("test", failures)

      report = summary.report

      expect(report).to include("FAIL")
      expect(report).to include("0%")
    end

    it "handles large durations" do
      long_result = Smolagents::Testing::BenchmarkResult.success(
        model_id: "test",
        test_name: "slow_test",
        level: 1,
        duration: 123.456,
        tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      )
      summary = Smolagents::Testing::BenchmarkSummary.from_results("test", [long_result])

      report = summary.report

      expect(report).to include("123.46")
    end

    it "handles high throughput" do
      fast_result = Smolagents::Testing::BenchmarkResult.success(
        model_id: "test",
        test_name: "fast_test",
        level: 1,
        duration: 0.1,
        tokens: Smolagents::Types::TokenUsage.new(input_tokens: 10_000, output_tokens: 5000)
      )
      summary = Smolagents::Testing::BenchmarkSummary.from_results("test", [fast_result])

      report = summary.report

      expect(report).to include("tok/s")
    end
  end
end
