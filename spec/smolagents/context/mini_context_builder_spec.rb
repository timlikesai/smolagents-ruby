require "spec_helper"
require "smolagents/context/mini_context_builder"

RSpec.describe Smolagents::Context::MiniContextBuilder do
  describe "#initialize" do
    it "creates builder with default budget" do
      builder = described_class.new
      expect(builder.estimated_tokens).to eq(0)
    end

    it "accepts custom budget" do
      builder = described_class.new(budget: 1000)
      context = builder.build
      expect(context.budget).to eq(1000)
    end

    it "accepts custom purpose" do
      builder = described_class.new(purpose: :extraction)
      context = builder.build
      expect(context.purpose).to eq(:extraction)
    end
  end

  describe "#system" do
    it "adds system message" do
      builder = described_class.new.system("Be helpful")
      messages = builder.to_messages
      expect(messages.size).to eq(1)
      expect(messages.first.role).to eq(Smolagents::Types::MessageRole::SYSTEM)
      expect(messages.first.content).to eq("Be helpful")
    end

    it "returns self for chaining" do
      builder = described_class.new
      result = builder.system("test")
      expect(result).to eq(builder)
    end

    it "ignores nil content" do
      builder = described_class.new.system(nil)
      expect(builder.to_messages).to be_empty
    end

    it "ignores empty content" do
      builder = described_class.new.system("")
      expect(builder.to_messages).to be_empty
    end

    it "truncates to 1/4 of budget" do
      long_content = "x" * 1000
      builder = described_class.new(budget: 100).system(long_content)
      # Budget 100 / 4 = 25 tokens * 4 chars = 100 chars max
      expect(builder.to_messages.first.content.length).to eq(100)
    end
  end

  describe "#user" do
    it "adds user message" do
      builder = described_class.new.user("What is this?")
      messages = builder.to_messages
      expect(messages.size).to eq(1)
      expect(messages.first.role).to eq(Smolagents::Types::MessageRole::USER)
      expect(messages.first.content).to eq("What is this?")
    end

    it "returns self for chaining" do
      builder = described_class.new
      result = builder.user("test")
      expect(result).to eq(builder)
    end

    it "truncates to fit budget minus reserve" do
      long_content = "x" * 10_000
      builder = described_class.new(budget: 200).user(long_content)
      # Budget 200 - 100 reserve = 100 tokens * 4 chars = 400 chars max
      expect(builder.to_messages.first.content.length).to eq(400)
    end
  end

  describe "#observation" do
    it "adds observation with prefix" do
      builder = described_class.new.observation("Result: 42")
      messages = builder.to_messages
      expect(messages.first.content).to eq("Observation: Result: 42")
    end

    it "returns self for chaining" do
      builder = described_class.new
      result = builder.observation("test")
      expect(result).to eq(builder)
    end

    it "uses half of headroom by default" do
      long_text = "x" * 10_000
      builder = described_class.new(budget: 200).observation(long_text)
      # Observation truncates to headroom/2 = 100 tokens = 400 chars
      # Then user truncates combined "Observation: "+text to (headroom-reserve)*4 = 400 chars
      content = builder.to_messages.first.content
      expect(content).to start_with("Observation: ")
      expect(content.length).to eq(400)
    end

    it "accepts custom max_tokens" do
      long_text = "x" * 1000
      builder = described_class.new.observation(long_text, max_tokens: 10)
      # 10 tokens * 4 chars = 40 chars + prefix
      content = builder.to_messages.first.content
      expect(content).to eq("Observation: #{"x" * 40}")
    end
  end

  describe "#yes_no_validation" do
    it "adds validation prompt with instructions" do
      builder = described_class.new.yes_no_validation("Is this correct?")
      content = builder.to_messages.first.content
      expect(content).to include("Is this correct?")
      expect(content).to include("Respond with only 'yes' or 'no'.")
    end

    it "returns self for chaining" do
      builder = described_class.new
      result = builder.yes_no_validation("test?")
      expect(result).to eq(builder)
    end
  end

  describe "#extract" do
    it "adds extraction prompt" do
      builder = described_class.new.extract("the main topic", from: "Ruby is great")
      content = builder.to_messages.first.content
      expect(content).to include("Extract the main topic")
      expect(content).to include("Ruby is great")
    end

    it "returns self for chaining" do
      builder = described_class.new
      result = builder.extract("data", from: "source")
      expect(result).to eq(builder)
    end

    it "truncates source text to fit budget" do
      long_source = "x" * 10_000
      builder = described_class.new(budget: 200).extract("data", from: long_source)
      content = builder.to_messages.first.content
      # Should be truncated
      expect(content.length).to be < 10_000
    end
  end

  describe "#build" do
    it "returns MiniContext" do
      builder = described_class.new
      context = builder.build
      expect(context).to be_a(Smolagents::Types::MiniContext)
    end

    it "returns frozen context" do
      builder = described_class.new.user("test")
      context = builder.build
      expect(context).to be_frozen
    end

    it "preserves purpose" do
      builder = described_class.new(purpose: :classification)
      context = builder.build
      expect(context.purpose).to eq(:classification)
    end

    it "tracks estimated tokens" do
      builder = described_class.new.user("Hello world") # 11 chars / 4 = 3 tokens
      context = builder.build
      expect(context.estimated_tokens).to eq(3)
    end
  end

  describe "#to_messages" do
    it "returns array of ChatMessage" do
      builder = described_class.new.system("sys").user("usr")
      messages = builder.to_messages
      expect(messages.size).to eq(2)
      expect(messages.all?(Smolagents::Types::ChatMessage)).to be true
    end

    it "returns empty array for empty builder" do
      builder = described_class.new
      expect(builder.to_messages).to eq([])
    end
  end

  describe "#can_fit?" do
    it "returns true when tokens fit" do
      builder = described_class.new(budget: 500)
      expect(builder.can_fit?(100)).to be true
    end

    it "returns false when tokens exceed budget" do
      builder = described_class.new(budget: 100)
      expect(builder.can_fit?(101)).to be false
    end

    it "accounts for already used tokens" do
      # Budget 500, user adds "x"*100 = 25 tokens
      builder = described_class.new(budget: 500).user("x" * 100)
      # Headroom = 500 - 25 = 475
      expect(builder.can_fit?(400)).to be true
      expect(builder.can_fit?(500)).to be false
    end
  end

  describe "#estimated_tokens" do
    it "returns zero for empty builder" do
      builder = described_class.new
      expect(builder.estimated_tokens).to eq(0)
    end

    it "returns accumulated token count" do
      builder = described_class.new
                               .system("1234") # 1 token
                               .user("5678")   # 1 token
      expect(builder.estimated_tokens).to eq(2)
    end
  end

  describe "fluent chaining" do
    it "supports full fluent workflow" do
      context = described_class.new(budget: 1000, purpose: :validation)
                               .system("Be precise")
                               .user("Check this")
                               .build

      expect(context.purpose).to eq(:validation)
      expect(context.messages.size).to eq(2)
      expect(context.budget).to eq(1000)
    end

    it "supports validation workflow" do
      messages = described_class.new
                                .system("Answer yes or no.")
                                .yes_no_validation("Is 2+2=4?")
                                .to_messages

      expect(messages.size).to eq(2)
      expect(messages.last.content).to include("yes")
      expect(messages.last.content).to include("no")
    end

    it "supports extraction workflow" do
      messages = described_class.new
                                .system("Extract precisely.")
                                .extract("the color", from: "The sky is blue.")
                                .to_messages

      expect(messages.size).to eq(2)
      expect(messages.last.content).to include("color")
      expect(messages.last.content).to include("blue")
    end
  end

  describe "budget enforcement" do
    it "truncates content to fit within budget" do
      huge_content = "x" * 100_000
      builder = described_class.new(budget: 100)
                               .system(huge_content)
                               .user(huge_content)

      messages = builder.to_messages
      # System truncated to budget/4 = 25 tokens = 100 chars
      expect(messages[0].content.length).to eq(100)
      # User has less headroom now
      expect(messages[1].content.length).to be < 100_000
    end
  end
end
