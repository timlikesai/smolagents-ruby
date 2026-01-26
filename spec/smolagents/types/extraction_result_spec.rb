RSpec.describe Smolagents::Types::ExtractionResult do
  describe ".success" do
    it "creates a successful extraction result" do
      result = described_class.success("final_answer(answer: 42)")

      expect(result.code).to eq("final_answer(answer: 42)")
      expect(result.reason).to be_nil
      expect(result.original).to be_nil
    end

    it "is frozen" do
      result = described_class.success("code")

      expect(result).to be_frozen
    end
  end

  describe ".empty" do
    it "creates a failed result for empty response" do
      result = described_class.empty

      expect(result.code).to be_nil
      expect(result.reason).to eq(:empty)
      expect(result.original).to be_nil
    end

    it "preserves original text" do
      result = described_class.empty(original: "   ")

      expect(result.original).to eq("   ")
    end
  end

  describe ".no_code" do
    it "creates a failed result for missing code" do
      result = described_class.no_code

      expect(result.code).to be_nil
      expect(result.reason).to eq(:no_code)
    end

    it "preserves original text" do
      result = described_class.no_code(original: "Just some text here")

      expect(result.original).to eq("Just some text here")
    end
  end

  describe ".prose_only" do
    it "creates a failed result for prose-only response" do
      result = described_class.prose_only

      expect(result.code).to be_nil
      expect(result.reason).to eq(:prose_only)
    end

    it "preserves original text" do
      result = described_class.prose_only(original: "Let me explain...")

      expect(result.original).to eq("Let me explain...")
    end
  end

  describe ".truncated" do
    it "creates a failed result for truncated code" do
      result = described_class.truncated

      expect(result.code).to be_nil
      expect(result.reason).to eq(:truncated)
    end

    it "preserves original text" do
      result = described_class.truncated(original: "```ruby\ndef incomplete")

      expect(result.original).to eq("```ruby\ndef incomplete")
    end
  end

  describe "#success?" do
    it "returns true when code is present and reason is nil" do
      result = described_class.success("puts 'hello'")

      expect(result.success?).to be_truthy
    end

    it "returns falsy when reason is present" do
      result = described_class.empty

      expect(result.success?).to be_falsy
    end

    it "returns falsy when code is nil" do
      result = described_class.no_code

      expect(result.success?).to be_falsy
    end
  end

  describe "#failure?" do
    it "returns true when reason is present" do
      result = described_class.empty

      expect(result.failure?).to be true
    end

    it "returns false for successful extraction" do
      result = described_class.success("code")

      expect(result.failure?).to be false
    end

    it "returns true for all failure factory methods" do
      %i[empty no_code prose_only truncated].each do |factory|
        result = described_class.send(factory)

        expect(result.failure?).to be true
      end
    end
  end

  describe "#message" do
    it "returns nil for success" do
      result = described_class.success("code")

      expect(result.message).to be_nil
    end

    it "returns appropriate message for :empty" do
      result = described_class.empty

      expect(result.message).to eq("Response was empty")
    end

    it "returns appropriate message for :no_code" do
      result = described_class.no_code

      expect(result.message).to eq("No code block found in response")
    end

    it "returns appropriate message for :prose_only" do
      result = described_class.prose_only

      expect(result.message).to eq("Response contained prose but no executable code")
    end

    it "returns appropriate message for :truncated" do
      result = described_class.truncated

      expect(result.message).to eq("Code block was truncated or incomplete")
    end
  end

  describe "#message" do
    it "covers all failure reasons" do
      # Test that #message works for all known failure types
      expect(described_class.empty.message).to eq("Response was empty")
      expect(described_class.no_code.message).to eq("No code block found in response")
      expect(described_class.prose_only.message).to eq("Response contained prose but no executable code")
      expect(described_class.truncated.message).to eq("Code block was truncated or incomplete")
    end
  end

  describe "pattern matching" do
    it "matches successful extraction" do
      result = described_class.success("final_answer(answer: 42)")

      matched = case result
                in Smolagents::Types::ExtractionResult[code:, reason: nil]
                  "success: #{code}"
                else
                  "failure"
                end

      expect(matched).to eq("success: final_answer(answer: 42)")
    end

    it "matches empty failure" do
      result = described_class.empty

      matched = case result
                in Smolagents::Types::ExtractionResult[reason: :empty]
                  "empty response"
                else
                  "other"
                end

      expect(matched).to eq("empty response")
    end

    it "matches any failure" do
      result = described_class.no_code(original: "some text")

      matched = case result
                in Smolagents::Types::ExtractionResult[reason:]
                  "failure: #{reason}"
                else
                  "success"
                end

      expect(matched).to eq("failure: no_code")
    end
  end

  describe "immutability" do
    it "creates frozen instances" do
      result = described_class.success("code")

      expect(result).to be_frozen
    end

    it "failure factory creates frozen instances" do
      result = described_class.empty

      expect(result).to be_frozen
    end
  end

  describe "default values" do
    it "allows creating with just code" do
      result = described_class.new(code: "test")

      expect(result.code).to eq("test")
      expect(result.reason).to be_nil
      expect(result.original).to be_nil
    end
  end
end
