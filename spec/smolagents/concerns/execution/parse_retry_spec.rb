RSpec.describe Smolagents::Concerns::ParseRetry do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Events::Consumer
      include Smolagents::Concerns::ParseRetry

      # Expose private methods for testing
      public :can_retry_parse?, :reset_parse_retries, :initialize_parse_retry
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
      # Default is 2 retries
      2.times do |i|
        b = Smolagents::ActionStepBuilder.new(step_number: i + 1)
        expect(instance.can_retry_parse?(b, prose_result)).to be true
      end

      final_builder = Smolagents::ActionStepBuilder.new(step_number: 3)
      expect(instance.can_retry_parse?(final_builder, prose_result)).to be false
    end

    it "has DEFAULT_MAX_RETRIES of 2" do
      expect(described_class::DEFAULT_MAX_RETRIES).to eq(2)
    end

    it "emits ParseRetryAttempted event on retry" do
      queue = Queue.new
      instance.connect_to(queue)

      instance.can_retry_parse?(builder, prose_result)

      event = queue.pop
      expect(event).to be_a(Smolagents::Events::ParseRetryAttempted)
      expect(event.retry_number).to eq(1)
      expect(event.max_retries).to eq(2)
      expect(event.reason).to eq(prose_result.reason)
      expect(event.message).to eq(prose_result.message)
    end

    it "does not emit event when retry denied" do
      queue = Queue.new
      instance.connect_to(queue)

      instance.can_retry_parse?(builder, code_tag_result)

      expect(queue.size).to eq(0)
    end

    it "emits events with incrementing retry numbers" do
      instance.initialize_parse_retry(max_retries: 3)
      queue = Queue.new
      instance.connect_to(queue)

      3.times do |i|
        b = Smolagents::ActionStepBuilder.new(step_number: i + 1)
        instance.can_retry_parse?(b, prose_result)
      end

      events = Array.new(3) { queue.pop }
      expect(events.map(&:retry_number)).to eq([1, 2, 3])
    end
  end

  describe "#reset_parse_retries" do
    it "allows retry again after reset" do
      2.times do |i|
        b = Smolagents::ActionStepBuilder.new(step_number: i + 1)
        instance.can_retry_parse?(b, prose_result)
      end
      expect(instance.can_retry_parse?(builder, prose_result)).to be false

      instance.reset_parse_retries

      new_builder = Smolagents::ActionStepBuilder.new(step_number: 3)
      expect(instance.can_retry_parse?(new_builder, prose_result)).to be true
    end
  end

  describe "#initialize_parse_retry" do
    it "allows configuring max retries" do
      instance.initialize_parse_retry(max_retries: 3)

      3.times do |i|
        b = Smolagents::ActionStepBuilder.new(step_number: i + 1)
        expect(instance.can_retry_parse?(b, prose_result)).to be true
      end

      b = Smolagents::ActionStepBuilder.new(step_number: 4)
      expect(instance.can_retry_parse?(b, prose_result)).to be false
    end

    it "disables retries when set to 0" do
      instance.initialize_parse_retry(max_retries: 0)

      expect(instance.can_retry_parse?(builder, prose_result)).to be false
    end

    it "defaults to 2 when nil" do
      instance.initialize_parse_retry(max_retries: nil)

      2.times do |i|
        b = Smolagents::ActionStepBuilder.new(step_number: i + 1)
        expect(instance.can_retry_parse?(b, prose_result)).to be true
      end

      third = Smolagents::ActionStepBuilder.new(step_number: 3)
      expect(instance.can_retry_parse?(third, prose_result)).to be false
    end
  end
end
