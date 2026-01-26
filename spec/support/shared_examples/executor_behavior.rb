# Shared examples for Ruby executors.
# Focuses on Ruby-specific behavior (language support).
# Use with "an executor" and "a safe executor" for complete coverage.

RSpec.shared_examples "a ruby executor" do
  describe "#supports?" do
    it "supports Ruby" do
      expect(executor.supports?(:ruby)).to be true
    end

    it "supports Ruby as string" do
      expect(executor.supports?("ruby")).to be true
    end

    it "does not support other languages" do
      expect(executor.supports?(:python)).to be false
      expect(executor.supports?(:javascript)).to be false
    end
  end

  describe "#execute language validation" do
    it "requires language to be :ruby" do
      expect do
        executor.execute("code", language: :python)
      end.to raise_error(ArgumentError, /not supported: python/)
    end

    it "executes Ruby-specific syntax" do
      result = executor.execute("[1, 2, 3].sum", language: :ruby)
      expect(result.success?).to be true
      expect(result.output).to eq(6)
    end

    it "executes blocks" do
      result = executor.execute("[1, 2, 3].map { |x| x * 2 }", language: :ruby)
      expect(result.success?).to be true
      expect(result.output).to eq([2, 4, 6])
    end

    it "executes symbols" do
      result = executor.execute(":hello.to_s", language: :ruby)
      expect(result.success?).to be true
      expect(result.output).to eq("hello")
    end

    it "executes ranges" do
      result = executor.execute("(1..5).to_a", language: :ruby)
      expect(result.success?).to be true
      expect(result.output).to eq([1, 2, 3, 4, 5])
    end
  end
end
