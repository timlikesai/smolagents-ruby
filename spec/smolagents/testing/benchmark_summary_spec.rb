RSpec.describe Smolagents::Testing::BenchmarkSummary do
  describe ".from_results" do
    let(:result1) do
      Smolagents::Testing::BenchmarkResult.success(
        model_id: "test-model",
        test_name: "test1",
        level: 1,
        duration: 2.0,
        tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      )
    end

    let(:result2) do
      Smolagents::Testing::BenchmarkResult.success(
        model_id: "test-model",
        test_name: "test2",
        level: 2,
        duration: 3.0,
        tokens: Smolagents::Types::TokenUsage.new(input_tokens: 150, output_tokens: 75)
      )
    end

    let(:result3) do
      Smolagents::Testing::BenchmarkResult.failure(
        model_id: "test-model",
        test_name: "test3",
        level: 3,
        duration: 1.0,
        error: "Timeout"
      )
    end

    it "creates a summary from results" do
      summary = described_class.from_results("test-model", [result1, result2])

      expect(summary.model_id).to eq("test-model")
      expect(summary.results).to contain_exactly(result1, result2)
    end

    it "includes optional capabilities" do
      capability = instance_double(Smolagents::Testing::ModelCapabilities::Capability)
      summary = described_class.from_results("test-model", [result1], capabilities: capability)

      expect(summary.capabilities).to equal(capability)
    end

    it "computes max_level_passed correctly" do
      summary = described_class.from_results("test-model", [result1, result2, result3])

      # Max level among passing results
      expect(summary.max_level_passed).to eq(2)
    end

    it "computes pass_rate correctly" do
      summary = described_class.from_results("test-model", [result1, result2, result3])

      # 2 passed out of 3 = 0.666...
      expect(summary.pass_rate).to be_within(0.01).of(0.667)
    end

    it "computes total_duration correctly" do
      summary = described_class.from_results("test-model", [result1, result2, result3])

      expect(summary.total_duration).to eq(6.0)
    end

    it "computes avg_tokens_per_second correctly" do
      summary = described_class.from_results("test-model", [result1, result2])

      # Total tokens: (100+50) + (150+75) = 375
      # Total duration: 2 + 3 = 5
      # TPS: 375 / 5 = 75
      expect(summary.avg_tokens_per_second).to eq(75.0)
    end

    it "handles empty results" do
      summary = described_class.from_results("test-model", [])

      expect(summary.max_level_passed).to eq(0)
      expect(summary.pass_rate).to eq(0.0)
      expect(summary.total_duration).to eq(0)
    end

    it "handles all failed results" do
      failure1 = Smolagents::Testing::BenchmarkResult.failure(
        model_id: "test-model",
        test_name: "test1",
        level: 1,
        duration: 1.0,
        error: "Failed"
      )
      failure2 = Smolagents::Testing::BenchmarkResult.failure(
        model_id: "test-model",
        test_name: "test2",
        level: 2,
        duration: 1.0,
        error: "Failed"
      )

      summary = described_class.from_results("test-model", [failure1, failure2])

      expect(summary.max_level_passed).to eq(0)
      expect(summary.pass_rate).to eq(0.0)
    end
  end

  describe "#level_badge" do
    let(:results) do
      [
        Smolagents::Testing::BenchmarkResult.success(
          model_id: "test",
          test_name: "test",
          level: 3,
          duration: 1.0
        )
      ]
    end

    it "returns INCOMPATIBLE for level 0" do
      summary = described_class.from_results("test", [])

      expect(summary.level_badge).to eq("INCOMPATIBLE")
    end

    it "returns BASIC for level 1" do
      result = Smolagents::Testing::BenchmarkResult.success(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 1.0
      )
      summary = described_class.from_results("test", [result])

      expect(summary.level_badge).to eq("BASIC")
    end

    it "returns FORMAT_OK for level 2" do
      result = Smolagents::Testing::BenchmarkResult.success(
        model_id: "test",
        test_name: "test",
        level: 2,
        duration: 1.0
      )
      summary = described_class.from_results("test", [result])

      expect(summary.level_badge).to eq("FORMAT_OK")
    end

    it "returns TOOL_CAPABLE for level 3" do
      result = Smolagents::Testing::BenchmarkResult.success(
        model_id: "test",
        test_name: "test",
        level: 3,
        duration: 1.0
      )
      summary = described_class.from_results("test", [result])

      expect(summary.level_badge).to eq("TOOL_CAPABLE")
    end

    it "returns MULTI_STEP for level 4" do
      result = Smolagents::Testing::BenchmarkResult.success(
        model_id: "test",
        test_name: "test",
        level: 4,
        duration: 1.0
      )
      summary = described_class.from_results("test", [result])

      expect(summary.level_badge).to eq("MULTI_STEP")
    end

    it "returns REASONING for level 5" do
      result = Smolagents::Testing::BenchmarkResult.success(
        model_id: "test",
        test_name: "test",
        level: 5,
        duration: 1.0
      )
      summary = described_class.from_results("test", [result])

      expect(summary.level_badge).to eq("REASONING")
    end

    it "returns VISION for level 6" do
      result = Smolagents::Testing::BenchmarkResult.success(
        model_id: "test",
        test_name: "test",
        level: 6,
        duration: 1.0
      )
      summary = described_class.from_results("test", [result])

      expect(summary.level_badge).to eq("VISION")
    end
  end

  describe "Data.define behavior" do
    let(:results) do
      [
        Smolagents::Testing::BenchmarkResult.success(
          model_id: "test",
          test_name: "test",
          level: 2,
          duration: 1.0
        )
      ]
    end

    it "is immutable" do
      summary = described_class.from_results("test", results)

      expect(summary).to be_frozen
    end

    it "enables pattern matching" do
      summary = described_class.from_results("test-model", results)

      matched = case summary
                in { model_id: "test-model", max_level_passed: l }
                  l
                else
                  nil
                end

      expect(matched).to eq(2)
    end

    it "supports to_h conversion" do
      summary = described_class.from_results("test", results)

      hash = summary.to_h

      expect(hash[:model_id]).to eq("test")
      expect(hash[:max_level_passed]).to eq(2)
      expect(hash[:pass_rate]).to be_a(Float)
    end
  end

  describe "statistics computation" do
    it "correctly sums token usage across multiple results" do
      results = [
        Smolagents::Testing::BenchmarkResult.success(
          model_id: "test",
          test_name: "test1",
          level: 1,
          duration: 1.0,
          tokens: Smolagents::Types::TokenUsage.new(input_tokens: 50, output_tokens: 25)
        ),
        Smolagents::Testing::BenchmarkResult.success(
          model_id: "test",
          test_name: "test2",
          level: 1,
          duration: 1.0,
          tokens: Smolagents::Types::TokenUsage.new(input_tokens: 50, output_tokens: 25)
        )
      ]

      summary = described_class.from_results("test", results)

      expect(summary.total_tokens.input_tokens).to eq(100)
      expect(summary.total_tokens.output_tokens).to eq(50)
    end

    it "handles results without token usage" do
      results = [
        Smolagents::Testing::BenchmarkResult.success(
          model_id: "test",
          test_name: "test",
          level: 1,
          duration: 1.0,
          tokens: nil
        )
      ]

      summary = described_class.from_results("test", results)

      expect(summary.total_tokens).to be_a(Smolagents::Types::TokenUsage)
    end

    it "calculates pass_rate as fraction between 0 and 1" do
      results = [
        Smolagents::Testing::BenchmarkResult.success(
          model_id: "test",
          test_name: "test1",
          level: 1,
          duration: 1.0
        ),
        Smolagents::Testing::BenchmarkResult.failure(
          model_id: "test",
          test_name: "test2",
          level: 1,
          duration: 1.0,
          error: "Failed"
        ),
        Smolagents::Testing::BenchmarkResult.failure(
          model_id: "test",
          test_name: "test3",
          level: 1,
          duration: 1.0,
          error: "Failed"
        )
      ]

      summary = described_class.from_results("test", results)

      expect(summary.pass_rate).to eq(1.0 / 3.0)
    end
  end

  describe "edge cases" do
    it "handles zero duration correctly in throughput calculation" do
      result = Smolagents::Testing::BenchmarkResult.success(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 0.0,
        tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      )

      summary = described_class.from_results("test", [result])

      # Should handle gracefully, likely return 0.0
      expect(summary.avg_tokens_per_second).to eq(0.0)
    end

    it "handles single result" do
      result = Smolagents::Testing::BenchmarkResult.success(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 5.0,
        tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      )

      summary = described_class.from_results("test", [result])

      expect(summary.pass_rate).to eq(1.0)
      expect(summary.avg_tokens_per_second).to eq(30.0)
    end
  end
end
