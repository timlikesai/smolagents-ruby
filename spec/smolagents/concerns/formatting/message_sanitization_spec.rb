require "spec_helper"

RSpec.describe Smolagents::Concerns::MessageSanitization do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::MessageSanitization
    end
  end

  let(:sanitizer) { test_class.new }

  describe "#sanitize_message_roles" do
    it "returns empty array for nil input" do
      expect(sanitizer.sanitize_message_roles(nil)).to eq([])
    end

    it "returns empty array for empty input" do
      expect(sanitizer.sanitize_message_roles([])).to eq([])
    end

    it "filters out nil messages" do
      messages = [
        Smolagents::ChatMessage.user("Hello"),
        nil,
        Smolagents::ChatMessage.assistant("Hi")
      ]
      result = sanitizer.sanitize_message_roles(messages)
      expect(result.size).to eq(2)
    end

    it "preserves empty-content messages as valid placeholders" do
      # Empty content messages are preserved (not filtered) - only consecutive same-role merges
      messages = [
        Smolagents::ChatMessage.user("Hello"),
        Smolagents::ChatMessage.assistant(""),
        Smolagents::ChatMessage.user("World")
      ]
      result = sanitizer.sanitize_message_roles(messages)
      # All three preserved - alternation is valid
      expect(result.size).to eq(3)
    end

    it "merges even if content is empty" do
      messages = [
        Smolagents::ChatMessage.user("Hello"),
        Smolagents::ChatMessage.assistant("Response"),
        Smolagents::ChatMessage.assistant(""),  # Empty but same role as previous
        Smolagents::ChatMessage.user("Follow-up")
      ]
      result = sanitizer.sanitize_message_roles(messages)
      # Two consecutive assistants get merged
      expect(result.size).to eq(3)
      expect(result[0].role).to eq(:user)
      expect(result[1].role).to eq(:assistant)
      expect(result[1].content).to include("Response")
      expect(result[2].role).to eq(:user)
    end

    it "merges consecutive user messages" do
      messages = [
        Smolagents::ChatMessage.user("First"),
        Smolagents::ChatMessage.user("Second")
      ]
      result = sanitizer.sanitize_message_roles(messages)
      expect(result.size).to eq(1)
      expect(result.first.content).to eq("First\n\nSecond")
      expect(result.first.role).to eq(:user)
    end

    it "merges consecutive assistant messages" do
      messages = [
        Smolagents::ChatMessage.assistant("Response one"),
        Smolagents::ChatMessage.assistant("Response two")
      ]
      result = sanitizer.sanitize_message_roles(messages)
      expect(result.size).to eq(1)
      expect(result.first.content).to include("Response one")
      expect(result.first.content).to include("Response two")
    end

    it "preserves alternating messages" do
      messages = [
        Smolagents::ChatMessage.user("Question"),
        Smolagents::ChatMessage.assistant("Answer"),
        Smolagents::ChatMessage.user("Follow-up")
      ]
      result = sanitizer.sanitize_message_roles(messages)
      expect(result.size).to eq(3)
    end

    it "treats tool_response as user-equivalent" do
      messages = [
        Smolagents::ChatMessage.user("Task"),
        Smolagents::ChatMessage.tool_response("Result")
      ]
      result = sanitizer.sanitize_message_roles(messages)
      expect(result.size).to eq(1)
      expect(result.first.content).to include("Task")
      expect(result.first.content).to include("Result")
    end

    it "preserves system messages separately" do
      messages = [
        Smolagents::ChatMessage.system("You are helpful"),
        Smolagents::ChatMessage.user("Hello")
      ]
      result = sanitizer.sanitize_message_roles(messages)
      expect(result.size).to eq(2)
      expect(result.first.role).to eq(:system)
    end

    it "handles complex alternation with planning steps" do
      # Simulates: system -> user (task) -> assistant (plan) -> assistant (action)
      messages = [
        Smolagents::ChatMessage.system("System prompt"),
        Smolagents::ChatMessage.user("Do the task"),
        Smolagents::ChatMessage.assistant("Here is my plan..."),
        Smolagents::ChatMessage.assistant("Code: result = calculate()")
      ]
      result = sanitizer.sanitize_message_roles(messages)
      expect(result.size).to eq(3)
      expect(result[2].content).to include("plan")
      expect(result[2].content).to include("Code:")
    end
  end

  describe "#valid_role_alternation?" do
    it "returns true for empty messages" do
      expect(sanitizer.valid_role_alternation?([])).to be true
    end

    it "returns true for single message" do
      messages = [Smolagents::ChatMessage.user("Hello")]
      expect(sanitizer.valid_role_alternation?(messages)).to be true
    end

    it "returns true for proper alternation" do
      messages = [
        Smolagents::ChatMessage.user("Q"),
        Smolagents::ChatMessage.assistant("A"),
        Smolagents::ChatMessage.user("Q2")
      ]
      expect(sanitizer.valid_role_alternation?(messages)).to be true
    end

    it "returns false for consecutive user messages" do
      messages = [
        Smolagents::ChatMessage.user("First"),
        Smolagents::ChatMessage.user("Second")
      ]
      expect(sanitizer.valid_role_alternation?(messages)).to be false
    end

    it "returns false for consecutive assistant messages" do
      messages = [
        Smolagents::ChatMessage.assistant("A1"),
        Smolagents::ChatMessage.assistant("A2")
      ]
      expect(sanitizer.valid_role_alternation?(messages)).to be false
    end

    it "treats user and tool_response as same role" do
      messages = [
        Smolagents::ChatMessage.user("Task"),
        Smolagents::ChatMessage.tool_response("Result")
      ]
      expect(sanitizer.valid_role_alternation?(messages)).to be false
    end
  end

  describe "#effective_role" do
    it "returns :system for system messages" do
      msg = Smolagents::ChatMessage.system("Prompt")
      expect(sanitizer.effective_role(msg)).to eq(:system)
    end

    it "returns :user for user messages" do
      msg = Smolagents::ChatMessage.user("Hello")
      expect(sanitizer.effective_role(msg)).to eq(:user)
    end

    it "returns :user for tool_response messages" do
      msg = Smolagents::ChatMessage.tool_response("Result")
      expect(sanitizer.effective_role(msg)).to eq(:user)
    end

    it "returns :assistant for assistant messages" do
      msg = Smolagents::ChatMessage.assistant("Response")
      expect(sanitizer.effective_role(msg)).to eq(:assistant)
    end
  end
end
