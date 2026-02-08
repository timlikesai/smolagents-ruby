require "spec_helper"
require "smolagents/types/mini_context"
require "smolagents/types/chat_message"

RSpec.describe Smolagents::Types::MiniContext do
  describe ".empty" do
    it "creates context with empty messages" do
      context = described_class.empty
      expect(context.messages).to eq([])
    end

    it "uses default budget of 500" do
      context = described_class.empty
      expect(context.budget).to eq(500)
    end

    it "uses default purpose of :validation" do
      context = described_class.empty
      expect(context.purpose).to eq(:validation)
    end

    it "starts with zero estimated tokens" do
      context = described_class.empty
      expect(context.estimated_tokens).to eq(0)
    end

    it "accepts custom budget" do
      context = described_class.empty(budget: 1000)
      expect(context.budget).to eq(1000)
    end

    it "accepts custom purpose" do
      context = described_class.empty(purpose: :extraction)
      expect(context.purpose).to eq(:extraction)
    end
  end

  describe "#headroom" do
    it "returns full budget when empty" do
      context = described_class.empty(budget: 500)
      expect(context.headroom).to eq(500)
    end

    it "returns remaining budget after adding tokens" do
      context = described_class.empty(budget: 500)
      context = context.with(estimated_tokens: 200)
      expect(context.headroom).to eq(300)
    end

    it "returns zero when at budget" do
      context = described_class.empty(budget: 500)
      context = context.with(estimated_tokens: 500)
      expect(context.headroom).to eq(0)
    end

    it "returns zero when over budget (never negative)" do
      context = described_class.empty(budget: 500)
      context = context.with(estimated_tokens: 600)
      expect(context.headroom).to eq(0)
    end
  end

  describe "#over_budget?" do
    it "returns false when under budget" do
      context = described_class.empty(budget: 500)
      context = context.with(estimated_tokens: 400)
      expect(context.over_budget?).to be false
    end

    it "returns false when exactly at budget" do
      context = described_class.empty(budget: 500)
      context = context.with(estimated_tokens: 500)
      expect(context.over_budget?).to be false
    end

    it "returns true when over budget" do
      context = described_class.empty(budget: 500)
      context = context.with(estimated_tokens: 501)
      expect(context.over_budget?).to be true
    end
  end

  describe "#can_fit?" do
    let(:context) do
      described_class.empty(budget: 500).with(estimated_tokens: 400)
    end

    it "returns true when tokens fit" do
      expect(context.can_fit?(50)).to be true
    end

    it "returns true at exact remaining" do
      expect(context.can_fit?(100)).to be true
    end

    it "returns false when tokens exceed remaining" do
      expect(context.can_fit?(101)).to be false
    end

    it "handles zero tokens" do
      expect(context.can_fit?(0)).to be true
    end
  end

  describe "#add_message" do
    let(:context) { described_class.empty(budget: 500) }
    let(:message) { Smolagents::Types::ChatMessage.user("Hello world") }

    it "returns new context with message added" do
      updated = context.add_message(message)
      expect(updated.messages).to eq([message])
    end

    it "preserves original context (immutable)" do
      context.add_message(message)
      expect(context.messages).to eq([])
    end

    it "estimates tokens from message content" do
      updated = context.add_message(message)
      # "Hello world" = 11 chars / 4 = 2.75 -> 3 tokens
      expect(updated.estimated_tokens).to eq(3)
    end

    it "accepts explicit token count" do
      updated = context.add_message(message, tokens: 10)
      expect(updated.estimated_tokens).to eq(10)
    end

    it "accumulates tokens across multiple messages" do
      msg1 = Smolagents::Types::ChatMessage.user("1234") # 1 token
      msg2 = Smolagents::Types::ChatMessage.user("5678") # 1 token
      updated = context.add_message(msg1).add_message(msg2)
      expect(updated.estimated_tokens).to eq(2)
    end

    it "freezes the messages array" do
      updated = context.add_message(message)
      expect(updated.messages).to be_frozen
    end
  end

  describe "#to_messages" do
    it "returns empty array for empty context" do
      context = described_class.empty
      expect(context.to_messages).to eq([])
    end

    it "returns messages array" do
      context = described_class.empty
      msg = Smolagents::Types::ChatMessage.user("test")
      updated = context.add_message(msg)
      expect(updated.to_messages).to eq([msg])
    end

    it "returns same array as messages" do
      context = described_class.empty
      msg = Smolagents::Types::ChatMessage.user("test")
      updated = context.add_message(msg)
      expect(updated.to_messages).to equal(updated.messages)
    end
  end

  describe "immutability" do
    it "is frozen by default" do
      context = described_class.empty
      expect(context).to be_frozen
    end

    it "with method returns new frozen instance" do
      context = described_class.empty
      updated = context.with(budget: 1000)
      expect(updated).to be_frozen
      expect(context.budget).to eq(500)
    end
  end

  describe "edge cases" do
    it "handles empty message content" do
      context = described_class.empty
      msg = Smolagents::Types::ChatMessage.user("")
      updated = context.add_message(msg)
      expect(updated.estimated_tokens).to eq(0)
    end

    it "handles nil message content" do
      context = described_class.empty
      msg = Smolagents::Types::ChatMessage.new(
        role: Smolagents::Types::MessageRole::USER,
        content: nil,
        tool_calls: nil,
        raw: nil,
        token_usage: nil,
        images: nil,
        reasoning_content: nil
      )
      updated = context.add_message(msg)
      expect(updated.estimated_tokens).to eq(0)
    end

    it "handles zero budget" do
      context = described_class.empty(budget: 0)
      expect(context.headroom).to eq(0)
      expect(context.can_fit?(0)).to be true
      expect(context.can_fit?(1)).to be false
    end
  end
end
