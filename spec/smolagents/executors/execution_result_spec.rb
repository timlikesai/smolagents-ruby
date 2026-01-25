RSpec.describe Smolagents::Executors::ExecutionResult do
  describe "initialization" do
    it "creates result with defaults" do
      result = described_class.new
      expect(result.output).to be_nil
      expect(result.logs).to eq("")
      expect(result.error).to be_nil
      expect(result.final_answer).to be false
    end

    it "creates result with custom values" do
      result = described_class.new(
        output: 42,
        logs: "processing...",
        error: "oops",
        final_answer: true
      )
      expect(result.output).to eq(42)
      expect(result.logs).to eq("processing...")
      expect(result.error).to eq("oops")
      expect(result.final_answer).to be true
    end

    it "allows partial initialization" do
      result = described_class.new(output: "done")
      expect(result.output).to eq("done")
      expect(result.logs).to eq("")
      expect(result.error).to be_nil
    end
  end

  describe ".success" do
    it "creates successful result" do
      result = described_class.success(output: 42)
      expect(result.output).to eq(42)
      expect(result.error).to be_nil
      expect(result.success?).to be true
    end

    it "sets logs when provided" do
      result = described_class.success(output: "done", logs: "progress: 50%")
      expect(result.logs).to eq("progress: 50%")
    end

    it "marks final_answer when flag is true" do
      result = described_class.success(output: "final", final_answer: true)
      expect(result.final_answer).to be true
    end

    it "defaults final_answer to false" do
      result = described_class.success(output: "data")
      expect(result.final_answer).to be false
    end

    it "defaults logs to empty string" do
      result = described_class.success(output: 100)
      expect(result.logs).to eq("")
    end
  end

  describe ".failure" do
    it "creates failed result" do
      result = described_class.failure(error: "something broke")
      expect(result.error).to eq("something broke")
      expect(result.output).to be_nil
      expect(result.failure?).to be true
    end

    it "includes logs with error" do
      result = described_class.failure(error: "timeout", logs: "Waiting for response...")
      expect(result.logs).to eq("Waiting for response...")
    end

    it "defaults final_answer to false" do
      result = described_class.failure(error: "bad")
      expect(result.final_answer).to be false
    end

    it "defaults logs to empty string" do
      result = described_class.failure(error: "failed")
      expect(result.logs).to eq("")
    end
  end

  describe "#success?" do
    it "returns true when error is nil" do
      result = described_class.new(output: 42)
      expect(result.success?).to be true
    end

    it "returns false when error is present" do
      result = described_class.new(error: "error message")
      expect(result.success?).to be false
    end

    it "returns false for empty string error" do
      result = described_class.new(error: "")
      expect(result.success?).to be false
    end
  end

  describe "#failure?" do
    it "returns true when error is present" do
      result = described_class.new(error: "something wrong")
      expect(result.failure?).to be true
    end

    it "returns false when error is nil" do
      result = described_class.new(output: 42)
      expect(result.failure?).to be false
    end

    it "is the opposite of success?" do
      result_success = described_class.success(output: "ok")
      result_failure = described_class.failure(error: "bad")

      expect(result_success.failure?).to eq(!result_success.success?)
      expect(result_failure.failure?).to eq(!result_failure.success?)
    end
  end

  describe "immutability" do
    it "is a Data.define class" do
      result = described_class.new(output: 42)
      expect(result).to be_a(Data)
    end

    it "raises when trying to call setter methods" do
      result = described_class.new(output: 42)
      # Data.define classes don't have setter methods, so this raises NoMethodError
      expect { result.output = 100 }.to raise_error(NoMethodError)
    end
  end

  describe "typical workflows" do
    it "models successful code execution" do
      result = described_class.success(output: 100, logs: "Computed result")
      expect(result.success?).to be true
      expect(result.failure?).to be false
      expect(result.output).to eq(100)
    end

    it "models failed code execution with debugging info" do
      result = described_class.failure(
        error: "NameError: undefined variable 'x'",
        logs: "Step 1: computed x\nStep 2: failed here"
      )
      expect(result.failure?).to be true
      expect(result.success?).to be false
      expect(result.logs).to include("Step 1")
    end

    it "models final_answer call during execution" do
      result = described_class.success(output: "The answer", final_answer: true)
      expect(result.final_answer).to be true
      expect(result.success?).to be true
    end

    it "models execution with complex output" do
      output = { results: [1, 2, 3], summary: "done" }
      result = described_class.success(output:, logs: "processed 3 items")
      expect(result.output).to eq(output)
    end
  end
end
