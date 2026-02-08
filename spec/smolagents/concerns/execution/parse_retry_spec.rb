RSpec.describe Smolagents::Concerns::ParseRetry do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ParseRetry

      # Expose private methods for testing
      public :can_retry_parse?, :reset_parse_retries
    end
  end
  let(:instance) { test_class.new }

  let(:builder) do
    Smolagents::ActionStepBuilder.new(step_number: 1)
  end

  # Format drift: model returned prose without any code tags
  let(:prose_result) do
    Smolagents::Types::ExtractionResult.no_code(original: "I think the answer is 42")
  end

  let(:empty_result) do
    Smolagents::Types::ExtractionResult.empty(original: "")
  end

  # Code tags present but content not recognized as Ruby
  let(:code_tag_result) do
    Smolagents::Types::ExtractionResult.no_code(original: "<code>\nnot ruby\n</code>")
  end

  let(:fence_result) do
    Smolagents::Types::ExtractionResult.no_code(original: "```\nnot ruby\n```")
  end

  describe "#can_retry_parse?" do
    it "allows retry when model returns prose without code tags" do
      expect(instance.can_retry_parse?(builder, prose_result)).to be true
    end

    it "allows retry on empty response" do
      expect(instance.can_retry_parse?(builder, empty_result)).to be true
    end

    it "does not retry when code tags are present" do
      expect(instance.can_retry_parse?(builder, code_tag_result)).to be false
    end

    it "does not retry when code fences are present" do
      expect(instance.can_retry_parse?(builder, fence_result)).to be false
    end

    it "sets observations with parse error guidance" do
      instance.can_retry_parse?(builder, prose_result)

      expect(builder.observations).to include("Parse error")
      expect(builder.observations).to include("```ruby code block")
    end

    it "clears previous error on retry" do
      builder.error = "previous error"

      instance.can_retry_parse?(builder, prose_result)

      expect(builder.error).to be_nil
    end

    it "denies retry when budget exhausted" do
      instance.can_retry_parse?(builder, prose_result)

      second_builder = Smolagents::ActionStepBuilder.new(step_number: 2)
      expect(instance.can_retry_parse?(second_builder, prose_result)).to be false
    end

    it "respects MAX_PARSE_RETRIES constant" do
      expect(Smolagents::Concerns::ParseRetry::MAX_PARSE_RETRIES).to eq(1)
    end
  end

  describe "#reset_parse_retries" do
    it "allows retry again after reset" do
      instance.can_retry_parse?(builder, prose_result)
      expect(instance.can_retry_parse?(builder, prose_result)).to be false

      instance.reset_parse_retries

      new_builder = Smolagents::ActionStepBuilder.new(step_number: 3)
      expect(instance.can_retry_parse?(new_builder, prose_result)).to be true
    end
  end
end
