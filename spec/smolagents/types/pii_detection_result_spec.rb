require "spec_helper"

RSpec.describe Smolagents::Types::PIIDetectionResult do
  let(:email_token) { Smolagents::Types::PIIToken.create(:email, "user@example.com", position_start: 7, position_end: 23) }
  let(:phone_token) { Smolagents::Types::PIIToken.create(:phone, "555-1234", position_start: 30, position_end: 38) }

  describe ".none" do
    it "creates result with no detections" do
      result = described_class.none("Hello world")

      expect(result.text).to eq("Hello world")
      expect(result.detections).to be_empty
      expect(result.scan_time_ms).to eq(0)
    end

    it "indicates nothing was detected" do
      result = described_class.none("Clean text")

      expect(result.detected?).to be false
    end
  end

  describe ".found" do
    it "creates result with detected tokens" do
      result = described_class.found("Email: user@example.com", [email_token], scan_time_ms: 5.2)

      expect(result.text).to include("user@example.com")
      expect(result.detections).to eq([email_token])
      expect(result.scan_time_ms).to eq(5.2)
    end

    it "wraps single token in array" do
      result = described_class.found("Email: user@example.com", email_token, scan_time_ms: 1)

      expect(result.detections).to eq([email_token])
    end

    it "handles multiple detections" do
      result = described_class.found(
        "Email: user@example.com, Phone: 555-1234",
        [email_token, phone_token],
        scan_time_ms: 3
      )

      expect(result.detections.size).to eq(2)
    end
  end

  describe "#detected?" do
    it "returns true when detections present" do
      result = described_class.found("Email: user@example.com", [email_token], scan_time_ms: 1)

      expect(result.detected?).to be true
    end

    it "returns false when no detections" do
      result = described_class.none("Clean text")

      expect(result.detected?).to be false
    end
  end

  describe "#count" do
    it "returns number of detections" do
      result = described_class.found(
        "Multiple PII items",
        [email_token, phone_token],
        scan_time_ms: 1
      )

      expect(result.count).to eq(2)
    end

    it "returns 0 for no detections" do
      result = described_class.none("Clean")

      expect(result.count).to eq(0)
    end
  end

  describe "#types" do
    it "returns unique PII types detected" do
      result = described_class.found(
        "Test",
        [email_token, phone_token],
        scan_time_ms: 1
      )

      expect(result.types).to contain_exactly(:email, :phone)
    end

    it "returns empty array when no detections" do
      result = described_class.none("Clean")

      expect(result.types).to eq([])
    end

    it "deduplicates types" do
      email_token2 = Smolagents::Types::PIIToken.create(:email, "other@example.com", position_start: 50)
      result = described_class.found(
        "Two emails",
        [email_token, email_token2],
        scan_time_ms: 1
      )

      expect(result.types).to eq([:email])
    end
  end

  describe "#positions" do
    it "returns position ranges for all detections" do
      result = described_class.found(
        "Email and phone",
        [email_token, phone_token],
        scan_time_ms: 1
      )

      expect(result.positions).to contain_exactly(7..23, 30..38)
    end

    it "returns empty array when no detections" do
      result = described_class.none("Clean")

      expect(result.positions).to eq([])
    end
  end

  describe "immutability" do
    it "is a frozen Data object" do
      result = described_class.found("Test", [email_token], scan_time_ms: 1)

      expect(result).to be_frozen
    end
  end
end
