RSpec.describe Smolagents::Utilities::PatternMatching::ErrorCategorization do
  describe ".categorize" do
    context "with exception objects" do
      it "categorizes timeout errors" do
        error = StandardError.new("Request timeout after 30 seconds")
        result = described_class.categorize(error)

        expect(result).to eq(:timeout)
      end

      it "categorizes rate limit errors" do
        error = StandardError.new("Rate limit exceeded: 429")
        result = described_class.categorize(error)

        expect(result).to eq(:rate_limit)
      end

      it "categorizes authentication errors" do
        error = StandardError.new("Unauthorized access")
        result = described_class.categorize(error)

        expect(result).to eq(:authentication)
      end

      it "categorizes errors with invalid key messages" do
        error = StandardError.new("Invalid API key provided")
        result = described_class.categorize(error)

        expect(result).to eq(:authentication)
      end

      it "returns unknown for unrecognized errors" do
        error = StandardError.new("Some completely new error type")
        result = described_class.categorize(error)

        expect(result).to eq(:unknown)
      end

      it "handles case-insensitive matching" do
        error = StandardError.new("REQUEST TIMEOUT")
        result = described_class.categorize(error)

        expect(result).to eq(:timeout)
      end
    end

    context "with Faraday errors" do
      it "categorizes by class name for TooManyRequestsError", skip: "requires Faraday gem" do
        # Would need Faraday loaded
      end

      it "categorizes by class name for TimeoutError", skip: "requires Faraday gem" do
        # Would need Faraday loaded
      end

      it "categorizes by class name for UnauthorizedError", skip: "requires Faraday gem" do
        # Would need Faraday loaded
      end
    end
  end

  describe "PATTERNS constant" do
    it "contains rate_limit pattern" do
      patterns = described_class::PATTERNS

      expect(patterns).to have_key(:rate_limit)
      expect(patterns[:rate_limit]).to be_a(Regexp)
    end

    it "contains timeout pattern" do
      patterns = described_class::PATTERNS

      expect(patterns).to have_key(:timeout)
      expect(patterns[:timeout]).to be_a(Regexp)
    end

    it "contains authentication pattern" do
      patterns = described_class::PATTERNS

      expect(patterns).to have_key(:authentication)
      expect(patterns[:authentication]).to be_a(Regexp)
    end

    it "is frozen to prevent modification" do
      expect(described_class::PATTERNS).to be_frozen
    end
  end

  describe "CLASSES constant" do
    it "maps Faraday error classes to categories" do
      classes = described_class::CLASSES

      expect(classes).to have_key("Faraday::TooManyRequestsError")
      expect(classes).to have_key("Faraday::TimeoutError")
      expect(classes).to have_key("Faraday::UnauthorizedError")
    end

    it "is frozen to prevent modification" do
      expect(described_class::CLASSES).to be_frozen
    end
  end
end
