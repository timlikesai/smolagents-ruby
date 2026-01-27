RSpec.describe Smolagents::Concerns::FailureClassification do
  describe ".classify" do
    context "with transient errors" do
      it "classifies timeout errors as transient" do
        error = Faraday::TimeoutError.new("request timed out")
        result = described_class.classify(error)

        expect(result.category).to eq(:transient)
        expect(result.subcategory).to eq(:network_timeout)
        expect(result.strategy).to eq(:exponential_backoff)
        expect(result.transient?).to be true
        expect(result.retriable?).to be true
      end

      it "classifies connection failures as transient" do
        error = Faraday::ConnectionFailed.new("connection refused")
        result = described_class.classify(error)

        expect(result.category).to eq(:transient)
        expect(result.subcategory).to eq(:connection_failed)
      end

      it "classifies rate limit errors as transient" do
        error = Smolagents::RateLimitError.new("rate limit exceeded")
        result = described_class.classify(error)

        expect(result.category).to eq(:transient)
        expect(result.subcategory).to eq(:rate_limit)
      end

      it "classifies server errors as transient" do
        error = Faraday::ServerError.new("500 internal server error")
        result = described_class.classify(error)

        expect(result.category).to eq(:transient)
        expect(result.subcategory).to eq(:server_error)
      end

      it "classifies errors with timeout pattern as transient" do
        error = StandardError.new("the request timed out after 30s")
        result = described_class.classify(error)

        expect(result.category).to eq(:transient)
        expect(result.subcategory).to eq(:network_timeout)
      end

      it "classifies errors with rate limit pattern as transient" do
        error = StandardError.new("Error 429: Too many requests")
        result = described_class.classify(error)

        expect(result.category).to eq(:transient)
        expect(result.subcategory).to eq(:rate_limit)
      end
    end

    context "with permanent errors" do
      it "classifies auth errors as permanent" do
        error = Faraday::UnauthorizedError.new("401 unauthorized")
        result = described_class.classify(error)

        expect(result.category).to eq(:permanent)
        expect(result.subcategory).to eq(:auth_failed)
        expect(result.strategy).to eq(:no_retry)
        expect(result.permanent?).to be true
        expect(result.retriable?).to be false
      end

      it "classifies argument errors as permanent" do
        error = ArgumentError.new("invalid argument")
        result = described_class.classify(error)

        expect(result.category).to eq(:permanent)
        expect(result.subcategory).to eq(:invalid_input)
      end

      it "classifies config errors as permanent" do
        error = Smolagents::AgentConfigurationError.new("bad config")
        result = described_class.classify(error)

        expect(result.category).to eq(:permanent)
        expect(result.subcategory).to eq(:invalid_input)
      end

      it "classifies errors with permission pattern as permanent" do
        error = StandardError.new("permission denied for resource")
        result = described_class.classify(error)

        expect(result.category).to eq(:permanent)
        expect(result.subcategory).to eq(:permission_denied)
      end

      it "classifies errors with not found pattern as permanent" do
        error = StandardError.new("resource not found")
        result = described_class.classify(error)

        expect(result.category).to eq(:permanent)
        expect(result.subcategory).to eq(:resource_not_found)
      end
    end

    context "with semantic failures" do
      it "classifies repetition results as semantic" do
        result_obj = double(:repetition_result, detected?: true, drifting?: false,
                                                to_h: { pattern: :tool_call })
        result = described_class.classify(result_obj)

        expect(result.category).to eq(:semantic)
        expect(result.subcategory).to eq(:loop_detected)
        expect(result.strategy).to eq(:alternative_approach)
        expect(result.semantic?).to be true
        expect(result.needs_alternative?).to be true
      end

      it "classifies drift results as semantic" do
        result_obj = double(:drift_result, detected?: false, drifting?: true, to_h: { level: :moderate })
        result = described_class.classify(result_obj)

        expect(result.category).to eq(:semantic)
        expect(result.subcategory).to eq(:goal_drift)
      end

      it "classifies hash semantic failures" do
        result_obj = { semantic_failure: true, subcategory: :confidence_decay, details: { score: 0.3 } }
        result = described_class.classify(result_obj)

        expect(result.category).to eq(:semantic)
        expect(result.subcategory).to eq(:confidence_decay)
        expect(result.details).to eq({ score: 0.3 })
      end
    end

    context "with unknown errors" do
      it "classifies unrecognized errors as unknown" do
        error = StandardError.new("something weird happened")
        result = described_class.classify(error)

        expect(result.category).to eq(:unknown)
        expect(result.subcategory).to eq(:unknown)
        expect(result.strategy).to eq(:limited_retry)
      end

      it "classifies non-error objects as unknown" do
        result = described_class.classify("not an error")

        expect(result.category).to eq(:unknown)
        expect(result.subcategory).to eq(:unclassified)
      end
    end
  end

  describe ".retriable?" do
    it "returns true for transient errors" do
      error = Faraday::TimeoutError.new("timeout")
      expect(described_class.retriable?(error)).to be true
    end

    it "returns false for permanent errors" do
      error = ArgumentError.new("invalid")
      expect(described_class.retriable?(error)).to be false
    end

    it "returns false for semantic failures" do
      result_obj = double(:repetition_result, detected?: true, drifting?: false, to_h: {})
      expect(described_class.retriable?(result_obj)).to be false
    end
  end

  describe ".strategy_for" do
    it "returns exponential_backoff for transient errors" do
      error = Faraday::TimeoutError.new("timeout")
      expect(described_class.strategy_for(error)).to eq(:exponential_backoff)
    end

    it "returns no_retry for permanent errors" do
      error = ArgumentError.new("invalid")
      expect(described_class.strategy_for(error)).to eq(:no_retry)
    end

    it "returns alternative_approach for semantic failures" do
      result_obj = double(:drift_result, detected?: false, drifting?: true, to_h: {})
      expect(described_class.strategy_for(result_obj)).to eq(:alternative_approach)
    end

    it "returns limited_retry for unknown failures" do
      error = StandardError.new("unknown")
      expect(described_class.strategy_for(error)).to eq(:limited_retry)
    end
  end

  describe "ClassificationResult" do
    let(:result) do
      described_class::ClassificationResult.new(
        category: :transient,
        subcategory: :network_timeout,
        strategy: :exponential_backoff,
        details: { message: "timeout" }
      )
    end

    it "provides predicate methods" do
      expect(result.transient?).to be true
      expect(result.permanent?).to be false
      expect(result.semantic?).to be false
      expect(result.retriable?).to be true
      expect(result.needs_alternative?).to be false
    end

    it "provides semantic predicates" do
      semantic = described_class::ClassificationResult.new(
        category: :semantic,
        subcategory: :loop_detected,
        strategy: :alternative_approach,
        details: {}
      )

      expect(semantic.semantic?).to be true
      expect(semantic.needs_alternative?).to be true
      expect(semantic.retriable?).to be false
    end
  end
end
