RSpec.describe Smolagents::Testing::BenchmarkResult do
  describe ".success" do
    it "creates a successful result" do
      tokens = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      result = described_class.success(
        model_id: "gpt-4",
        test_name: "reasoning_test",
        level: 3,
        duration: 2.5,
        tokens:,
        steps: 3,
        metadata: { notes: "test note" }
      )

      expect(result.model_id).to eq("gpt-4")
      expect(result.test_name).to eq("reasoning_test")
      expect(result.level).to eq(3)
      expect(result.passed).to be true
      expect(result.duration).to eq(2.5)
      expect(result.tokens).to equal(tokens)
      expect(result.steps).to eq(3)
      expect(result.error).to be_nil
      expect(result.metadata).to eq({ notes: "test note" })
    end

    it "allows nil tokens" do
      result = described_class.success(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 1.0
      )

      expect(result.tokens).to be_nil
    end

    it "allows nil steps" do
      result = described_class.success(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 1.0,
        steps: nil
      )

      expect(result.steps).to be_nil
    end

    it "provides default empty metadata" do
      result = described_class.success(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 1.0
      )

      expect(result.metadata).to eq({})
    end
  end

  describe ".failure" do
    it "creates a failed result" do
      tokens = Smolagents::Types::TokenUsage.new(input_tokens: 50, output_tokens: 25)
      result = described_class.failure(
        model_id: "gpt-3.5",
        test_name: "reasoning_test",
        level: 4,
        duration: 5.0,
        error: "Timeout exceeded",
        tokens:,
        steps: 5
      )

      expect(result.model_id).to eq("gpt-3.5")
      expect(result.test_name).to eq("reasoning_test")
      expect(result.level).to eq(4)
      expect(result.passed).to be false
      expect(result.duration).to eq(5.0)
      expect(result.error).to eq("Timeout exceeded")
      expect(result.tokens).to equal(tokens)
      expect(result.steps).to eq(5)
    end

    it "allows nil tokens and steps" do
      result = described_class.failure(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 1.0,
        error: "Test failed"
      )

      expect(result.tokens).to be_nil
      expect(result.steps).to be_nil
    end
  end

  describe "#passed?" do
    it "returns true for successful results" do
      result = described_class.success(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 1.0
      )

      expect(result.passed?).to be true
    end

    it "returns false for failed results" do
      result = described_class.failure(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 1.0,
        error: "Failed"
      )

      expect(result.passed?).to be false
    end
  end

  describe "#failed?" do
    it "returns false for successful results" do
      result = described_class.success(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 1.0
      )

      expect(result.failed?).to be false
    end

    it "returns true for failed results" do
      result = described_class.failure(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 1.0,
        error: "Failed"
      )

      expect(result.failed?).to be true
    end
  end

  describe "#tokens_per_second" do
    it "calculates throughput when tokens and duration present" do
      tokens = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      result = described_class.success(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 3.0,
        tokens:
      )

      # 150 total tokens / 3 seconds = 50 tokens/second
      expect(result.tokens_per_second).to eq(50.0)
    end

    it "returns nil when no tokens" do
      result = described_class.success(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 1.0,
        tokens: nil
      )

      expect(result.tokens_per_second).to be_nil
    end

    it "returns nil when duration is zero" do
      tokens = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      result = described_class.success(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 0.0,
        tokens:
      )

      expect(result.tokens_per_second).to be_nil
    end

    it "returns nil when duration is negative" do
      tokens = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      result = described_class.success(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: -1.0,
        tokens:
      )

      expect(result.tokens_per_second).to be_nil
    end

    it "handles high throughput" do
      tokens = Smolagents::Types::TokenUsage.new(input_tokens: 5000, output_tokens: 2500)
      result = described_class.success(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 1.0,
        tokens:
      )

      expect(result.tokens_per_second).to eq(7500.0)
    end
  end

  describe "#to_row" do
    it "formats a passing result as a table row" do
      tokens = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      result = described_class.success(
        model_id: "test",
        test_name: "basic_test",
        level: 1,
        duration: 2.0,
        tokens:
      )

      row = result.to_row

      expect(row).to include("PASS")
      expect(row).to include("basic_test")
      expect(row).to include("2.00s")
      expect(row).to include("75 tok/s")
    end

    it "formats a failing result as a table row" do
      result = described_class.failure(
        model_id: "test",
        test_name: "complex_test",
        level: 4,
        duration: 5.0,
        error: "Timeout exceeded"
      )

      row = result.to_row

      expect(row).to include("FAIL")
      expect(row).to include("complex_test")
      expect(row).to include("5.00s")
      expect(row).to include("Timeout exceeded")
    end

    it "includes dashes when no token usage" do
      result = described_class.success(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 1.0,
        tokens: nil
      )

      row = result.to_row

      expect(row).to include("-")
    end

    it "truncates long error messages" do
      long_error = "A" * 100
      result = described_class.failure(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 1.0,
        error: long_error
      )

      row = result.to_row

      # Error should be truncated to 40 chars
      expect(row.length).to be < (4 + 100)
    end
  end

  describe "Data.define behavior" do
    it "creates immutable result" do
      result = described_class.success(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 1.0
      )

      expect(result).to be_frozen
    end

    it "enables pattern matching" do
      result = described_class.success(
        model_id: "gpt-4",
        test_name: "test",
        level: 3,
        duration: 2.5
      )

      matched = case result
                in { model_id: "gpt-4", level: l }
                  l
                else
                  nil
                end

      expect(matched).to eq(3)
    end

    it "supports to_h conversion" do
      tokens = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      result = described_class.success(
        model_id: "test",
        test_name: "test",
        level: 1,
        duration: 1.0,
        tokens:
      )

      hash = result.to_h

      expect(hash[:model_id]).to eq("test")
      expect(hash[:test_name]).to eq("test")
      expect(hash[:level]).to eq(1)
      expect(hash[:passed]).to be true
      expect(hash[:duration]).to eq(1.0)
      expect(hash[:tokens]).to equal(tokens)
    end
  end
end
