require "spec_helper"

RSpec.describe Smolagents::Privacy::PIIDetector do
  describe "default configuration" do
    subject(:detector) { described_class.new }

    describe "email detection" do
      it "detects standard email addresses" do
        result = detector.scan("Contact me at user@example.com please")

        expect(result.detected?).to be true
        expect(result.types).to eq([:email])
        expect(result.detections.first.original).to eq("user@example.com")
      end

      it "detects emails with subdomains" do
        result = detector.scan("Email: admin@mail.company.com")

        expect(result.detected?).to be true
        expect(result.detections.first.original).to eq("admin@mail.company.com")
      end

      it "detects emails with plus addressing" do
        result = detector.scan("Use user+tag@gmail.com")

        expect(result.detected?).to be true
        expect(result.detections.first.original).to eq("user+tag@gmail.com")
      end

      it "detects emails with numbers" do
        result = detector.scan("Contact user123@test456.org")

        expect(result.detected?).to be true
        expect(result.detections.first.original).to eq("user123@test456.org")
      end
    end

    describe "phone detection" do
      it "detects US phone numbers with dashes" do
        result = detector.scan("Call 555-123-4567")

        expect(result.detected?).to be true
        expect(result.types).to eq([:phone])
        expect(result.detections.first.original).to eq("555-123-4567")
      end

      it "detects US phone numbers with dots" do
        result = detector.scan("Call 555.123.4567")

        expect(result.detected?).to be true
        expect(result.detections.first.original).to eq("555.123.4567")
      end

      it "detects US phone numbers with spaces" do
        result = detector.scan("Call 555 123 4567")

        expect(result.detected?).to be true
        expect(result.detections.first.original).to eq("555 123 4567")
      end

      it "detects phone numbers with parentheses" do
        result = detector.scan("Call (555) 123-4567")

        expect(result.detected?).to be true
        # Pattern captures area code through end
        expect(result.detections.first.original).to include("123-4567")
      end

      it "detects phone numbers with country code" do
        result = detector.scan("Call +1-555-123-4567")

        expect(result.detected?).to be true
        # Pattern captures the number portion
        expect(result.detections.first.original).to include("555-123-4567")
      end
    end

    describe "SSN detection" do
      it "detects SSN format" do
        result = detector.scan("SSN: 123-45-6789")

        expect(result.detected?).to be true
        expect(result.types).to include(:ssn)
        expect(result.detections.find { |d| d.pii_type == :ssn }.original).to eq("123-45-6789")
      end

      it "does not detect partial SSNs" do
        result = detector.scan("Not an SSN: 12-34-5678")

        expect(result.detections.none? { |d| d.pii_type == :ssn }).to be true
      end
    end

    describe "credit card detection" do
      it "detects credit card with dashes" do
        result = detector.scan("Card: 1234-5678-9012-3456")

        expect(result.detected?).to be true
        expect(result.types).to include(:credit_card)
      end

      it "detects credit card with spaces" do
        result = detector.scan("Card: 1234 5678 9012 3456")

        expect(result.detected?).to be true
        expect(result.types).to include(:credit_card)
      end

      it "detects credit card without separators" do
        result = detector.scan("Card: 1234567890123456")

        expect(result.detected?).to be true
        expect(result.types).to include(:credit_card)
      end
    end

    describe "API key detection" do
      it "detects API keys with standard prefixes" do
        # Pattern: prefix[-_]?[alphanumeric]{20,}
        result = detector.scan("API key: sk12345678901234567890abc")

        expect(result.detected?).to be true
        expect(result.types).to eq([:api_key])
      end

      it "detects api prefix keys" do
        result = detector.scan("Use api12345678901234567890xyz")

        expect(result.detected?).to be true
        expect(result.types).to eq([:api_key])
      end

      it "detects key prefix" do
        result = detector.scan("Key: key_abcdefghijklmnopqrstuvwx")

        expect(result.detected?).to be true
        expect(result.types).to eq([:api_key])
      end

      it "detects token prefix" do
        result = detector.scan("Token: token1234567890abcdefghij")

        expect(result.detected?).to be true
        expect(result.types).to eq([:api_key])
      end

      it "detects secret prefix" do
        result = detector.scan("Secret: secret_12345678901234567890")

        expect(result.detected?).to be true
        expect(result.types).to eq([:api_key])
      end
    end
  end

  describe "strict configuration" do
    subject(:detector) { described_class.new(Smolagents::Types::PrivacyConfig.strict) }

    describe "IP address detection" do
      it "detects IPv4 addresses" do
        result = detector.scan("Server IP: 192.168.1.100")

        expect(result.detected?).to be true
        expect(result.types).to include(:ip_address)
        expect(result.detections.find { |d| d.pii_type == :ip_address }.original).to eq("192.168.1.100")
      end

      it "detects localhost" do
        result = detector.scan("Connect to 127.0.0.1")

        expect(result.detected?).to be true
        expect(result.types).to include(:ip_address)
      end
    end

    describe "name detection" do
      it "detects two-word names" do
        result = detector.scan("Author: John Smith")

        expect(result.detected?).to be true
        expect(result.types).to include(:name)
      end

      it "detects three-word names" do
        result = detector.scan("Author: John Robert Smith")

        expect(result.detected?).to be true
        expect(result.types).to include(:name)
      end
    end

    describe "address detection" do
      it "detects street addresses" do
        result = detector.scan("Located at 123 Main St")

        expect(result.detected?).to be true
        expect(result.types).to include(:address)
      end

      it "detects addresses with multi-word street names" do
        result = detector.scan("Address: 456 Oak Tree Ave")

        expect(result.detected?).to be true
        expect(result.types).to include(:address)
      end
    end

    describe "date of birth detection" do
      it "detects MM/DD/YYYY format" do
        result = detector.scan("DOB: 01/15/1990")

        expect(result.detected?).to be true
        expect(result.types).to include(:date_of_birth)
      end

      it "detects YYYY-MM-DD format" do
        result = detector.scan("Born: 1990-01-15")

        expect(result.detected?).to be true
        expect(result.types).to include(:date_of_birth)
      end
    end
  end

  describe "custom configuration" do
    it "only detects specified types" do
      config = Smolagents::Types::PrivacyConfig.create(types: [:email])
      detector = described_class.new(config)

      result = detector.scan("Email: user@example.com, Phone: 555-1234")

      expect(result.types).to eq([:email])
    end

    it "respects disabled config" do
      config = Smolagents::Types::PrivacyConfig.disabled
      detector = described_class.new(config)

      result = detector.scan("Secret: user@example.com 123-45-6789")

      expect(result.detected?).to be false
    end
  end

  describe "multiple detections" do
    subject(:detector) { described_class.new }

    it "detects multiple PII items in same text" do
      result = detector.scan("Contact user@example.com or call 555-123-4567")

      expect(result.count).to eq(2)
      expect(result.types).to contain_exactly(:email, :phone)
    end

    it "detects multiple items of same type" do
      result = detector.scan("Emails: alice@example.com and bob@example.com")

      expect(result.count).to eq(2)
      expect(result.detections.all? { |d| d.pii_type == :email }).to be true
    end

    it "orders detections by position" do
      result = detector.scan("Phone: 555-1234 Email: test@example.com")
      positions = result.detections.map(&:position_start)

      expect(positions).to eq(positions.sort)
    end
  end

  describe "position tracking" do
    subject(:detector) { described_class.new }

    it "correctly tracks start position" do
      result = detector.scan("Contact: user@example.com")
      token = result.detections.first

      expect(token.position_start).to eq(9)
    end

    it "correctly tracks end position" do
      result = detector.scan("Contact: user@example.com")
      token = result.detections.first

      expect(token.position_end).to eq(25)
    end

    it "positions allow correct string slicing" do
      text = "Email is user@example.com here"
      result = detector.scan(text)
      token = result.detections.first

      expect(text[token.position_start...token.position_end]).to eq(token.original)
    end
  end

  describe "scan timing" do
    subject(:detector) { described_class.new }

    it "records scan time in milliseconds" do
      result = detector.scan("Test text with user@example.com")

      expect(result.scan_time_ms).to be_a(Numeric)
      expect(result.scan_time_ms).to be >= 0
    end
  end

  describe ".pattern_for" do
    it "returns pattern for known type" do
      pattern = described_class.pattern_for(:email)

      expect(pattern).to be_a(Regexp)
      expect(pattern).to match("test@example.com")
    end

    it "returns nil for unknown type" do
      pattern = described_class.pattern_for(:unknown)

      expect(pattern).to be_nil
    end
  end

  describe ".supported_types" do
    it "returns all supported PII types" do
      types = described_class.supported_types

      expect(types).to include(:email, :phone, :ssn, :credit_card, :api_key)
      expect(types).to include(:ip_address, :name, :address, :date_of_birth)
    end
  end

  describe "no false positives" do
    subject(:detector) { described_class.new }

    it "does not detect random numbers as SSN" do
      result = detector.scan("Order number: 123456789")

      expect(result.types).not_to include(:ssn)
    end

    it "does not detect short strings as API keys" do
      result = detector.scan("Use token abc123")

      expect(result.types).not_to include(:api_key)
    end
  end
end
