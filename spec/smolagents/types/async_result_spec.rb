RSpec.describe Smolagents::Types::AsyncToolError do
  describe "attributes" do
    it "has id and message" do
      error = described_class.new(id: "err_123", message: "Something went wrong")

      expect(error.id).to eq("err_123")
      expect(error.message).to eq("Something went wrong")
    end
  end

  describe "#to_s" do
    it "returns the message" do
      error = described_class.new(id: "err_123", message: "API timeout")

      expect(error.to_s).to eq("API timeout")
    end

    it "handles empty message" do
      error = described_class.new(id: "err_456", message: "")

      expect(error.to_s).to eq("")
    end
  end

  describe "immutability" do
    it "is frozen" do
      error = described_class.new(id: "err_123", message: "Error")

      expect(error).to be_frozen
    end
  end
end

RSpec.describe Smolagents::Types::AsyncResult do
  describe ".success" do
    it "creates a successful result" do
      result = described_class.success(index: 0, value: "response data")

      expect(result.index).to eq(0)
      expect(result.value).to eq("response data")
      expect(result.error).to be_nil
    end

    it "is frozen" do
      result = described_class.success(index: 1, value: {})

      expect(result).to be_frozen
    end
  end

  describe ".failure" do
    it "creates a failed result" do
      error = StandardError.new("Network error")
      result = described_class.failure(index: 2, error: error)

      expect(result.index).to eq(2)
      expect(result.value).to be_nil
      expect(result.error).to eq(error)
    end

    it "is frozen" do
      result = described_class.failure(index: 0, error: RuntimeError.new("fail"))

      expect(result).to be_frozen
    end
  end

  describe "#success?" do
    it "returns true when error is nil" do
      result = described_class.success(index: 0, value: "data")

      expect(result.success?).to be true
    end

    it "returns false when error is present" do
      result = described_class.failure(index: 0, error: StandardError.new("fail"))

      expect(result.success?).to be false
    end
  end

  describe "#failure?" do
    it "returns true when error is present" do
      result = described_class.failure(index: 0, error: StandardError.new("fail"))

      expect(result.failure?).to be true
    end

    it "returns false when error is nil" do
      result = described_class.success(index: 0, value: "data")

      expect(result.failure?).to be false
    end
  end

  describe "pattern matching" do
    it "matches on success" do
      result = described_class.success(index: 1, value: "hello")

      matched = case result
                in index: 1, value: "hello", error: nil
                  "matched success"
                else
                  "no match"
                end

      expect(matched).to eq("matched success")
    end

    it "matches on failure" do
      error = StandardError.new("boom")
      result = described_class.failure(index: 2, error: error)

      matched = case result
                in index: 2, value: nil
                  "matched failure"
                else
                  "no match"
                end

      expect(matched).to eq("matched failure")
    end
  end
end
