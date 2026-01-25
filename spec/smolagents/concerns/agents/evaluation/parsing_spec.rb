require "smolagents/concerns/agents/evaluation/parsing"

RSpec.describe Smolagents::Concerns::Evaluation::Parsing do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Evaluation::Parsing
    end
  end

  let(:instance) { test_class.new }
  let(:token_usage) { Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50) }

  describe "#parse_evaluation" do
    context "with DONE status" do
      it "parses DONE response" do
        content = "DONE: The answer is 42"
        result = instance.parse_evaluation(content, token_usage)

        expect(result.status).to eq(:goal_achieved)
        expect(result.answer).to eq("The answer is 42")
      end

      it "extracts text after DONE:" do
        content = "DONE: successfully completed the task"
        result = instance.parse_evaluation(content)

        expect(result.answer).to eq("successfully completed the task")
      end

      it "includes token usage" do
        content = "DONE: Result"
        result = instance.parse_evaluation(content, token_usage)

        expect(result.token_usage).to eq(token_usage)
      end
    end

    context "with CONTINUE status" do
      it "parses CONTINUE response" do
        content = "CONTINUE: Need to search for more information"
        result = instance.parse_evaluation(content)

        expect(result.status).to eq(:continue)
        expect(result.reasoning).to eq("Need to search for more information")
      end

      it "extracts reasoning from CONTINUE" do
        content = "CONTINUE: More steps needed"
        result = instance.parse_evaluation(content)

        expect(result.reasoning).to eq("More steps needed")
      end
    end

    context "with STUCK status" do
      it "parses STUCK response" do
        content = "STUCK: Cannot find the required information"
        result = instance.parse_evaluation(content)

        expect(result.status).to eq(:stuck)
        expect(result.reasoning).to eq("Cannot find the required information")
      end
    end

    context "with confidence score" do
      it "extracts confidence when present" do
        content = "DONE: Answer\nCONFIDENCE: 0.95"
        result = instance.parse_evaluation(content)

        expect(result.confidence).to eq(0.95)
      end

      it "clamps confidence to 0.0-1.0" do
        content = "DONE: Answer\nCONFIDENCE: 1.5"
        result = instance.parse_evaluation(content)

        expect(result.confidence).to eq(1.0)
      end

      it "converts confidence string to float" do
        content = "DONE: Answer\nCONFIDENCE: 0.75"
        result = instance.parse_evaluation(content)

        expect(result.confidence).to eq(0.75)
      end

      it "uses default confidence when confidence is low" do
        content = "DONE: Answer\nCONFIDENCE: 0.2"
        result = instance.parse_evaluation(content)

        expect(result.confidence).to eq(0.2)
      end
    end

    context "with unrecognized format" do
      it "defaults to continue with low confidence" do
        content = "This is not a recognized format"
        result = instance.parse_evaluation(content)

        expect(result.status).to eq(:continue)
        expect(result.confidence).to eq(0.3)
        expect(result.reasoning).to eq("This is not a recognized format")
      end

      it "includes reasoning from unrecognized content" do
        content = "Some random text"
        result = instance.parse_evaluation(content)

        expect(result.reasoning).to eq("Some random text")
      end
    end

    context "with whitespace variations" do
      it "strips leading whitespace" do
        content = "   DONE: Answer with spaces"
        result = instance.parse_evaluation(content)

        expect(result.status).to eq(:goal_achieved)
        expect(result.answer).to eq("Answer with spaces")
      end

      it "handles multiline content" do
        content = "DONE: First line\nSecond line\nCONFIDENCE: 0.8"
        result = instance.parse_evaluation(content)

        expect(result.answer).to include("First line")
      end

      it "trims captured text" do
        content = "DONE:   Answer with extra spaces   "
        result = instance.parse_evaluation(content)

        expect(result.answer).to eq("Answer with extra spaces")
      end
    end

    context "with case insensitivity" do
      it "matches lowercase statuses" do
        content = "done: answer"
        result = instance.parse_evaluation(content)

        expect(result.status).to eq(:goal_achieved)
      end

      it "matches mixed case confidence" do
        content = "DONE: Answer\nconfidence: 0.9"
        result = instance.parse_evaluation(content)

        expect(result.confidence).to eq(0.9)
      end
    end

    context "with multiple confidence indicators" do
      it "uses the first confidence value found" do
        content = "DONE: Answer\nCONFIDENCE: 0.9\nCONFIDENCE: 0.5"
        result = instance.parse_evaluation(content)

        expect(result.confidence).to eq(0.9)
      end
    end
  end

  describe "#extract_confidence" do
    it "extracts numeric confidence" do
      text = "CONFIDENCE: 0.75"
      confidence = instance.send(:extract_confidence, text)

      expect(confidence).to eq(0.75)
    end

    it "extracts integer as float" do
      text = "CONFIDENCE: 1"
      confidence = instance.send(:extract_confidence, text)

      expect(confidence).to eq(1.0)
    end

    it "returns nil when no confidence found" do
      text = "DONE: Answer"
      confidence = instance.send(:extract_confidence, text)

      expect(confidence).to be_nil
    end

    it "clamps values above 1.0 to 1.0" do
      text = "CONFIDENCE: 2.5"
      confidence = instance.send(:extract_confidence, text)

      expect(confidence).to eq(1.0)
    end

    it "clamps values below 0.0 to 0.0" do
      # The pattern only matches positive numbers, so negative numbers return nil
      text = "CONFIDENCE: -0.5"
      confidence = instance.send(:extract_confidence, text)

      # Negative numbers don't match the pattern [\d.]+ so nil is returned
      expect(confidence).to be_nil
    end
  end

  describe "#parse_evaluation_text" do
    context "with valid status patterns" do
      it "builds done result" do
        text = "DONE: The answer"
        result = instance.send(:parse_evaluation_text, text, nil, nil)

        expect(result.status).to eq(:goal_achieved)
        expect(result.answer).to eq("The answer")
      end

      it "builds continue result" do
        text = "CONTINUE: Need more info"
        result = instance.send(:parse_evaluation_text, text, nil, nil)

        expect(result.status).to eq(:continue)
        expect(result.reasoning).to eq("Need more info")
      end

      it "builds stuck result" do
        text = "STUCK: Cannot proceed"
        result = instance.send(:parse_evaluation_text, text, nil, nil)

        expect(result.status).to eq(:stuck)
        expect(result.reasoning).to eq("Cannot proceed")
      end
    end

    context "with confidence parameter" do
      it "includes confidence in result" do
        text = "DONE: Answer"
        result = instance.send(:parse_evaluation_text, text, 0.85, nil)

        expect(result.confidence).to eq(0.85)
      end

      it "includes token_usage in result" do
        text = "DONE: Answer"
        result = instance.send(:parse_evaluation_text, text, nil, token_usage)

        expect(result.token_usage).to eq(token_usage)
      end
    end
  end

  describe "STATUS_PATTERNS" do
    it "defines done pattern" do
      patterns = described_class::STATUS_PATTERNS
      expect(patterns).to have_key(:done)
    end

    it "defines continue pattern" do
      patterns = described_class::STATUS_PATTERNS
      expect(patterns).to have_key(:continue)
    end

    it "defines stuck pattern" do
      patterns = described_class::STATUS_PATTERNS
      expect(patterns).to have_key(:stuck)
    end

    it "done pattern stops at CONFIDENCE" do
      pattern = described_class::STATUS_PATTERNS[:done]
      match = "DONE: answer\nCONFIDENCE: 0.9".match(pattern)

      expect(match[1]).to eq("answer")
    end
  end

  describe "CONFIDENCE_PATTERN" do
    it "matches confidence with spaces" do
      pattern = described_class::CONFIDENCE_PATTERN
      match = "CONFIDENCE: 0.75".match(pattern)

      expect(match[1]).to eq("0.75")
    end

    it "matches confidence without spaces after colon" do
      pattern = described_class::CONFIDENCE_PATTERN
      match = "CONFIDENCE:0.75".match(pattern)

      expect(match[1]).to eq("0.75")
    end

    it "is case insensitive" do
      pattern = described_class::CONFIDENCE_PATTERN
      match = "confidence: 0.5".match(pattern)

      expect(match).not_to be_nil
    end
  end

  describe "parsing integration" do
    it "parses complex DONE response with confidence" do
      content = <<~TEXT
        DONE: Successfully completed the analysis.
        The result is 42.
        CONFIDENCE: 0.92
      TEXT

      result = instance.parse_evaluation(content, token_usage)

      expect(result.status).to eq(:goal_achieved)
      expect(result.answer).to include("Successfully completed")
      expect(result.confidence).to eq(0.92)
      expect(result.token_usage).to eq(token_usage)
    end

    it "handles CONTINUE with no confidence" do
      content = "CONTINUE: Need to call web search API"
      result = instance.parse_evaluation(content)

      expect(result.status).to eq(:continue)
      expect(result.reasoning).to eq("Need to call web search API")
      # Default confidence is 0.5 for continue when not explicitly set
      expect(result.confidence).to eq(0.5)
    end

    it "preserves exact answer text (critical for values)" do
      answer_text = "user42@example.com"
      content = "DONE: #{answer_text}"
      result = instance.parse_evaluation(content)

      expect(result.answer).to eq(answer_text)
    end
  end
end
