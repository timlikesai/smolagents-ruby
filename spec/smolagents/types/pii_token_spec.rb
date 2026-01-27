require "spec_helper"

RSpec.describe Smolagents::Types::PIIToken do
  describe ".create" do
    it "creates a token with generated UUID" do
      token = described_class.create(:email, "user@example.com")

      expect(token.id).to match(/\A[0-9a-f-]{36}\z/)
      expect(token.pii_type).to eq(:email)
      expect(token.original).to eq("user@example.com")
    end

    it "sets default position_start to 0" do
      token = described_class.create(:email, "user@example.com")

      expect(token.position_start).to eq(0)
    end

    it "calculates position_end from original length when not provided" do
      token = described_class.create(:email, "user@example.com")

      expect(token.position_end).to eq(16)
    end

    it "accepts explicit positions" do
      token = described_class.create(:phone, "555-1234", position_start: 10, position_end: 18)

      expect(token.position_start).to eq(10)
      expect(token.position_end).to eq(18)
    end

    it "handles nil original gracefully" do
      token = described_class.create(:unknown, nil)

      expect(token.original).to be_nil
      expect(token.position_end).to eq(0)
    end
  end

  describe "#placeholder" do
    it "returns formatted placeholder with type and truncated ID" do
      token = described_class.create(:email, "user@example.com")
      placeholder = token.placeholder

      expect(placeholder).to match(/\A\[PII:EMAIL:[a-f0-9]{6}\]\z/)
    end

    it "uppercases the PII type" do
      token = described_class.create(:credit_card, "1234-5678-9012-3456")

      expect(token.placeholder).to include("PII:CREDIT_CARD:")
    end
  end

  describe "#length" do
    it "returns the length of the original text based on positions" do
      token = described_class.create(:phone, "555-1234", position_start: 10, position_end: 18)

      expect(token.length).to eq(8)
    end

    it "returns correct length for default positions" do
      token = described_class.create(:ssn, "123-45-6789")

      expect(token.length).to eq(11)
    end
  end

  describe "supported PII types" do
    %i[email phone ssn credit_card api_key ip_address name address date_of_birth].each do |type|
      it "supports #{type} type" do
        token = described_class.create(type, "test value")

        expect(token.pii_type).to eq(type)
        expect(token.placeholder).to include(type.to_s.upcase)
      end
    end
  end

  describe "immutability" do
    it "is a frozen Data object" do
      token = described_class.create(:email, "user@example.com")

      expect(token).to be_frozen
    end

    it "raises error when trying to modify" do
      token = described_class.create(:email, "user@example.com")

      expect { token.instance_variable_set(:@original, "new") }.to raise_error(FrozenError)
    end
  end

  describe "unique IDs" do
    it "generates unique IDs for each token" do
      tokens = Array.new(10) { described_class.create(:email, "user@example.com") }
      ids = tokens.map(&:id)

      expect(ids.uniq.size).to eq(10)
    end
  end
end
