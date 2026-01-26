RSpec.describe Smolagents::Types::RetryInfo do
  describe "attributes" do
    it "has backoff_seconds, attempt, max_attempts, and error" do
      error = StandardError.new("timeout")
      info = described_class.new(
        backoff_seconds: 2.5,
        attempt: 1,
        max_attempts: 3,
        error:
      )

      expect(info.backoff_seconds).to eq(2.5)
      expect(info.attempt).to eq(1)
      expect(info.max_attempts).to eq(3)
      expect(info.error).to eq(error)
    end
  end

  describe "#retries_remaining?" do
    it "returns true when attempt < max_attempts" do
      info = described_class.new(
        backoff_seconds: 1.0,
        attempt: 1,
        max_attempts: 3,
        error: StandardError.new("fail")
      )

      expect(info.retries_remaining?).to be true
    end

    it "returns false when attempt == max_attempts" do
      info = described_class.new(
        backoff_seconds: 1.0,
        attempt: 3,
        max_attempts: 3,
        error: StandardError.new("fail")
      )

      expect(info.retries_remaining?).to be false
    end

    it "returns false when attempt > max_attempts" do
      info = described_class.new(
        backoff_seconds: 1.0,
        attempt: 5,
        max_attempts: 3,
        error: StandardError.new("fail")
      )

      expect(info.retries_remaining?).to be false
    end
  end

  describe "immutability" do
    it "is frozen" do
      info = described_class.new(
        backoff_seconds: 1.0,
        attempt: 1,
        max_attempts: 3,
        error: StandardError.new("fail")
      )

      expect(info).to be_frozen
    end
  end
end

RSpec.describe Smolagents::Types::RetryResult do
  describe ".success" do
    it "creates a success result with value" do
      result = described_class.success("response data")

      expect(result.status).to eq(:success)
      expect(result.value).to eq("response data")
      expect(result.retry_info).to be_nil
      expect(result.error).to be_nil
    end

    it "is frozen" do
      result = described_class.success({})

      expect(result).to be_frozen
    end
  end

  describe ".needs_retry" do
    it "creates a retry-needed result with info" do
      info = Smolagents::Types::RetryInfo.new(
        backoff_seconds: 2.0,
        attempt: 1,
        max_attempts: 3,
        error: StandardError.new("timeout")
      )

      result = described_class.needs_retry(info)

      expect(result.status).to eq(:retry_needed)
      expect(result.value).to be_nil
      expect(result.retry_info).to eq(info)
      expect(result.error).to be_nil
    end

    it "is frozen" do
      info = Smolagents::Types::RetryInfo.new(
        backoff_seconds: 1.0,
        attempt: 1,
        max_attempts: 3,
        error: StandardError.new("fail")
      )

      expect(described_class.needs_retry(info)).to be_frozen
    end
  end

  describe ".exhausted" do
    it "creates an exhausted result with final error" do
      error = StandardError.new("final error")
      result = described_class.exhausted(error)

      expect(result.status).to eq(:exhausted)
      expect(result.value).to be_nil
      expect(result.retry_info).to be_nil
      expect(result.error).to eq(error)
    end

    it "is frozen" do
      expect(described_class.exhausted(StandardError.new("x"))).to be_frozen
    end
  end

  describe ".error" do
    it "creates a non-retryable error result" do
      error = ArgumentError.new("invalid arg")
      result = described_class.error(error)

      expect(result.status).to eq(:error)
      expect(result.value).to be_nil
      expect(result.retry_info).to be_nil
      expect(result.error).to eq(error)
    end

    it "is frozen" do
      expect(described_class.error(RuntimeError.new("x"))).to be_frozen
    end
  end

  describe "#success?" do
    it "returns true for success status" do
      result = described_class.success("data")

      expect(result.success?).to be true
    end

    it "returns false for other statuses" do
      info = Smolagents::Types::RetryInfo.new(
        backoff_seconds: 1.0,
        attempt: 1,
        max_attempts: 3,
        error: StandardError.new("x")
      )

      expect(described_class.needs_retry(info).success?).to be false
      expect(described_class.exhausted(StandardError.new("x")).success?).to be false
      expect(described_class.error(StandardError.new("x")).success?).to be false
    end
  end

  describe "#retry_needed?" do
    it "returns true for retry_needed status" do
      info = Smolagents::Types::RetryInfo.new(
        backoff_seconds: 1.0,
        attempt: 1,
        max_attempts: 3,
        error: StandardError.new("x")
      )
      result = described_class.needs_retry(info)

      expect(result.retry_needed?).to be true
    end

    it "returns false for other statuses" do
      expect(described_class.success("x").retry_needed?).to be false
      expect(described_class.exhausted(StandardError.new("x")).retry_needed?).to be false
      expect(described_class.error(StandardError.new("x")).retry_needed?).to be false
    end
  end

  describe "#exhausted?" do
    it "returns true for exhausted status" do
      result = described_class.exhausted(StandardError.new("final"))

      expect(result.exhausted?).to be true
    end

    it "returns false for other statuses" do
      info = Smolagents::Types::RetryInfo.new(
        backoff_seconds: 1.0,
        attempt: 1,
        max_attempts: 3,
        error: StandardError.new("x")
      )

      expect(described_class.success("x").exhausted?).to be false
      expect(described_class.needs_retry(info).exhausted?).to be false
      expect(described_class.error(StandardError.new("x")).exhausted?).to be false
    end
  end

  describe "#error?" do
    it "returns true for error status" do
      result = described_class.error(ArgumentError.new("bad"))

      expect(result.error?).to be true
    end

    it "returns false for other statuses" do
      info = Smolagents::Types::RetryInfo.new(
        backoff_seconds: 1.0,
        attempt: 1,
        max_attempts: 3,
        error: StandardError.new("x")
      )

      expect(described_class.success("x").error?).to be false
      expect(described_class.needs_retry(info).error?).to be false
      expect(described_class.exhausted(StandardError.new("x")).error?).to be false
    end
  end

  describe "pattern matching" do
    it "matches success" do
      result = described_class.success("data")

      matched = case result
                in status: :success, value:
                  "got: #{value}"
                else
                  "no match"
                end

      expect(matched).to eq("got: data")
    end

    it "matches retry_needed with info" do
      info = Smolagents::Types::RetryInfo.new(
        backoff_seconds: 2.0,
        attempt: 1,
        max_attempts: 3,
        error: StandardError.new("x")
      )
      result = described_class.needs_retry(info)

      matched = case result
                in status: :retry_needed, retry_info: { backoff_seconds: }
                  "wait #{backoff_seconds}s"
                else
                  "no match"
                end

      expect(matched).to eq("wait 2.0s")
    end
  end
end
