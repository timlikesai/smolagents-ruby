require "spec_helper"

RSpec.describe Smolagents::Privacy::PIIProtection do
  describe "tokenization strategy (default)" do
    subject(:protection) { described_class.new }

    describe "#protect" do
      it "replaces PII with tokens" do
        protected_text = protection.protect("Email: user@example.com")

        expect(protected_text).not_to include("user@example.com")
        expect(protected_text).to match(/\[PII:EMAIL:[a-f0-9]{6}\]/)
      end

      it "preserves non-PII text" do
        protected_text = protection.protect("Hello user@example.com world")

        expect(protected_text).to start_with("Hello ")
        expect(protected_text).to end_with(" world")
      end

      it "handles multiple PII items" do
        protected_text = protection.protect("Email: user@example.com Phone: 555-123-4567")

        expect(protected_text).to match(/\[PII:EMAIL:[a-f0-9]{6}\]/)
        expect(protected_text).to match(/\[PII:PHONE:[a-f0-9]{6}\]/)
      end

      it "returns original text when no PII detected" do
        protected_text = protection.protect("Hello world")

        expect(protected_text).to eq("Hello world")
      end

      it "returns original text when protection is disabled" do
        config = Smolagents::Types::PrivacyConfig.disabled
        protection = described_class.new(config)

        protected_text = protection.protect("Secret: user@example.com")

        expect(protected_text).to eq("Secret: user@example.com")
      end
    end

    describe "#restore" do
      it "restores original PII values" do
        original = "Email: user@example.com"
        protected_text = protection.protect(original)
        restored = protection.restore(protected_text)

        expect(restored).to eq(original)
      end

      it "restores multiple PII items" do
        original = "Email: alice@example.com and bob@example.com"
        protected_text = protection.protect(original)
        restored = protection.restore(protected_text)

        expect(restored).to eq(original)
      end

      it "handles text with mixed PII types" do
        original = "Contact user@example.com or call 555-123-4567"
        protected_text = protection.protect(original)
        restored = protection.restore(protected_text)

        expect(restored).to eq(original)
      end

      it "returns text unchanged if no tokens present" do
        restored = protection.restore("Hello world")

        expect(restored).to eq("Hello world")
      end
    end

    describe "#clear_registry" do
      it "removes all stored tokens" do
        protection.protect("Email: user@example.com")

        expect(protection.registry_size).to be >= 1
        protection.clear_registry
        expect(protection.registry_size).to eq(0)
      end

      it "makes restore impossible after clearing" do
        protected_text = protection.protect("Email: user@example.com")
        protection.clear_registry
        restored = protection.restore(protected_text)

        expect(restored).to eq(protected_text)
      end
    end

    describe "#registry_size" do
      it "tracks number of registered tokens" do
        protection.protect("Email: user@example.com")

        expect(protection.registry_size).to eq(1)
      end

      it "tracks multiple tokens" do
        protection.protect("Email: alice@example.com, bob@example.com, charlie@example.com")

        expect(protection.registry_size).to eq(3)
      end

      it "starts at zero" do
        expect(protection.registry_size).to eq(0)
      end
    end
  end

  describe "masking strategy" do
    describe "with format preservation" do
      subject(:protection) do
        config = Smolagents::Types::PrivacyConfig.create(strategy: :mask, preserve_format: true)
        described_class.new(config)
      end

      it "preserves email format with asterisks" do
        masked = protection.protect("Email: user@example.com")

        expect(masked).to match(/Email: \*+@\*+\.\*+/)
      end

      it "preserves phone format" do
        masked = protection.protect("Phone: 555-123-4567")

        expect(masked).to include("***-***-****")
      end

      it "preserves SSN format" do
        masked = protection.protect("SSN: 123-45-6789")

        expect(masked).to include("***-**-****")
      end

      it "preserves credit card format" do
        masked = protection.protect("Card: 1234-5678-9012-3456")

        expect(masked).to include("****-****-****-****")
      end
    end

    describe "without format preservation" do
      subject(:protection) do
        config = Smolagents::Types::PrivacyConfig.create(strategy: :mask, preserve_format: false)
        described_class.new(config)
      end

      it "replaces entire value with asterisks" do
        masked = protection.protect("Email: user@example.com")

        expect(masked).to eq("Email: ****************")
      end

      it "masks by character count" do
        masked = protection.protect("SSN: 123-45-6789")

        expect(masked).to eq("SSN: ***********")
      end
    end

    describe "restore behavior" do
      it "returns text unchanged (masking is not reversible)" do
        config = Smolagents::Types::PrivacyConfig.create(strategy: :mask)
        protection = described_class.new(config)

        masked = protection.protect("Email: user@example.com")
        restored = protection.restore(masked)

        expect(restored).to eq(masked)
      end
    end
  end

  describe "removal strategy" do
    subject(:protection) do
      config = Smolagents::Types::PrivacyConfig.create(strategy: :remove)
      described_class.new(config)
    end

    it "removes PII entirely" do
      removed = protection.protect("Email: user@example.com here")

      expect(removed).to eq("Email:  here")
    end

    it "removes multiple PII items" do
      removed = protection.protect("From user@example.com to other@example.com")

      expect(removed).to eq("From  to ")
    end

    describe "restore behavior" do
      it "returns text unchanged (removal is not reversible)" do
        removed = protection.protect("Email: user@example.com")
        restored = protection.restore(removed)

        expect(restored).to eq(removed)
      end
    end
  end

  describe "thread safety" do
    subject(:protection) { described_class.new }

    it "handles concurrent protect calls safely" do
      threads = Array.new(10) do |i|
        Thread.new do
          protection.protect("Email#{i}: user#{i}@example.com")
        end
      end

      threads.each(&:join)

      expect(protection.registry_size).to eq(10)
    end

    it "handles concurrent protect and restore" do
      protected_texts = Queue.new
      results = Queue.new

      producer = Thread.new do
        10.times do |i|
          protected_texts << protection.protect("Email#{i}: user#{i}@example.com")
        end
      end

      consumer = Thread.new do
        10.times do
          text = protected_texts.pop
          results << protection.restore(text)
        end
      end

      [producer, consumer].each(&:join)

      expect(results.size).to eq(10)
    end
  end

  describe "position handling" do
    subject(:protection) { described_class.new }

    it "correctly handles adjacent PII" do
      protected_text = protection.protect("user1@example.com user2@example.com")

      expect(protected_text.scan("[PII:EMAIL").size).to eq(2)
    end

    it "correctly handles PII at start of text" do
      protected_text = protection.protect("user@example.com is the email")
      restored = protection.restore(protected_text)

      expect(restored).to eq("user@example.com is the email")
    end

    it "correctly handles PII at end of text" do
      protected_text = protection.protect("Contact user@example.com")
      restored = protection.restore(protected_text)

      expect(restored).to eq("Contact user@example.com")
    end
  end

  describe "config access" do
    it "exposes the configuration" do
      config = Smolagents::Types::PrivacyConfig.strict
      protection = described_class.new(config)

      expect(protection.config).to eq(config)
    end

    it "uses default config when not specified" do
      protection = described_class.new

      expect(protection.config).to eq(Smolagents::Types::PrivacyConfig.default)
    end
  end

  describe "protect/restore cycle" do
    subject(:protection) { described_class.new }

    it "is idempotent for tokenization" do
      original = "Email: user@example.com"
      protected1 = protection.protect(original)
      restored1 = protection.restore(protected1)

      protection.clear_registry

      protected2 = protection.protect(restored1)
      restored2 = protection.restore(protected2)

      expect(restored2).to eq(original)
    end

    it "handles complex text with multiple operations" do
      original = "Contact alice@example.com or bob@company.org. Call 555-123-4567."
      protected_text = protection.protect(original)
      restored = protection.restore(protected_text)

      expect(restored).to eq(original)
    end
  end
end
