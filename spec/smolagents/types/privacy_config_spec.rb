require "spec_helper"

RSpec.describe Smolagents::Types::PrivacyConfig do
  describe ".default" do
    subject(:config) { described_class.default }

    it "is enabled" do
      expect(config.enabled?).to be true
    end

    it "detects common PII types" do
      expect(config.pii_types).to contain_exactly(:email, :phone, :ssn, :credit_card, :api_key)
    end

    it "uses tokenization strategy" do
      expect(config.strategy).to eq(:tokenize)
      expect(config.tokenize?).to be true
    end

    it "preserves format by default" do
      expect(config.preserve_format).to be true
    end

    it "enables audit detections" do
      expect(config.audit_detections).to be true
    end
  end

  describe ".strict" do
    subject(:config) { described_class.strict }

    it "is enabled" do
      expect(config.enabled?).to be true
    end

    it "detects all PII types" do
      expect(config.pii_types).to contain_exactly(
        :email, :phone, :ssn, :credit_card, :api_key,
        :ip_address, :name, :address, :date_of_birth
      )
    end

    it "uses tokenization strategy" do
      expect(config.tokenize?).to be true
    end
  end

  describe ".disabled" do
    subject(:config) { described_class.disabled }

    it "is not enabled" do
      expect(config.enabled?).to be false
    end

    it "has empty PII types" do
      expect(config.pii_types).to be_empty
    end

    it "does not audit detections" do
      expect(config.audit_detections).to be false
    end
  end

  describe ".create" do
    it "creates custom config with specified types" do
      config = described_class.create(types: %i[email phone])

      expect(config.pii_types).to contain_exactly(:email, :phone)
    end

    it "creates custom config with specified strategy" do
      config = described_class.create(strategy: :mask)

      expect(config.mask?).to be true
    end

    it "validates types" do
      expect { described_class.create(types: [:invalid_type]) }
        .to raise_error(ArgumentError, /Invalid PII types/)
    end

    it "validates strategy" do
      expect { described_class.create(strategy: :invalid) }
        .to raise_error(ArgumentError, /strategy must be one of/)
    end

    it "allows all valid PII types" do
      described_class.all_types.each do |type|
        expect { described_class.create(types: [type]) }.not_to raise_error
      end
    end

    it "allows all valid strategies" do
      described_class.valid_strategies.each do |strategy|
        expect { described_class.create(strategy:) }.not_to raise_error
      end
    end
  end

  describe "#enabled?" do
    it "returns true for default config" do
      expect(described_class.default.enabled?).to be true
    end

    it "returns false for disabled config" do
      expect(described_class.disabled.enabled?).to be false
    end
  end

  describe "strategy predicates" do
    describe "#tokenize?" do
      it "returns true for tokenize strategy" do
        config = described_class.create(strategy: :tokenize)

        expect(config.tokenize?).to be true
        expect(config.mask?).to be false
        expect(config.remove?).to be false
      end
    end

    describe "#mask?" do
      it "returns true for mask strategy" do
        config = described_class.create(strategy: :mask)

        expect(config.mask?).to be true
        expect(config.tokenize?).to be false
        expect(config.remove?).to be false
      end
    end

    describe "#remove?" do
      it "returns true for remove strategy" do
        config = described_class.create(strategy: :remove)

        expect(config.remove?).to be true
        expect(config.tokenize?).to be false
        expect(config.mask?).to be false
      end
    end
  end

  describe "#detects?" do
    subject(:config) { described_class.create(types: %i[email phone]) }

    it "returns true for detected types" do
      expect(config).to be_detects(:email)
      expect(config).to be_detects(:phone)
    end

    it "returns false for non-detected types" do
      expect(config.detects?(:ssn)).to be false
      expect(config.detects?(:credit_card)).to be false
    end
  end

  describe ".common_types" do
    it "includes high-frequency PII types" do
      expect(described_class.common_types).to contain_exactly(
        :email, :phone, :ssn, :credit_card, :api_key
      )
    end
  end

  describe ".all_types" do
    it "includes all supported PII types" do
      expect(described_class.all_types).to contain_exactly(
        :email, :phone, :ssn, :credit_card, :api_key,
        :ip_address, :name, :address, :date_of_birth
      )
    end
  end

  describe ".valid_strategies" do
    it "includes all protection strategies" do
      expect(described_class.valid_strategies).to contain_exactly(:tokenize, :mask, :remove)
    end
  end

  describe "immutability" do
    it "is a frozen Data object" do
      config = described_class.default

      expect(config).to be_frozen
    end
  end
end
