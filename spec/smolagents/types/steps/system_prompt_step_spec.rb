require "spec_helper"

RSpec.describe Smolagents::Types::SystemPromptStep do
  let(:step) { described_class.new(system_prompt: "You are a helpful Ruby assistant.") }

  it_behaves_like "a step type", message_count: 1 do
    let(:step) { described_class.new(system_prompt: "System prompt") }
  end

  describe ".new" do
    it "creates a system prompt step" do
      result = described_class.new(system_prompt: "Be helpful")
      expect(result.system_prompt).to eq("Be helpful")
    end

    it "accepts empty string" do
      result = described_class.new(system_prompt: "")
      expect(result.system_prompt).to eq("")
    end
  end

  describe "#to_h" do
    it "returns hash with system_prompt key" do
      expect(step.to_h).to eq({ system_prompt: "You are a helpful Ruby assistant." })
    end
  end

  describe "#to_messages" do
    it "returns array with single system message" do
      messages = step.to_messages
      expect(messages.size).to eq(1)
    end

    it "creates a system role ChatMessage" do
      message = step.to_messages.first
      expect(message).to be_a(Smolagents::ChatMessage)
      expect(message.role).to eq(Smolagents::MessageRole::SYSTEM)
    end

    it "includes the system prompt as content" do
      message = step.to_messages.first
      expect(message.content).to eq("You are a helpful Ruby assistant.")
    end

    it "ignores any options passed" do
      messages = step.to_messages(summary_mode: true)
      expect(messages.size).to eq(1)
      expect(messages.first.content).to eq("You are a helpful Ruby assistant.")
    end
  end

  describe "#deconstruct_keys" do
    it "returns hash for pattern matching" do
      expect(step.deconstruct_keys(nil)).to eq({ system_prompt: "You are a helpful Ruby assistant." })
    end

    it "ignores keys argument" do
      expect(step.deconstruct_keys([:system_prompt])).to eq({ system_prompt: "You are a helpful Ruby assistant." })
    end
  end

  describe "pattern matching" do
    it "matches on system_prompt" do
      result = case step
               in { system_prompt: s }
                 s
               end

      expect(result).to eq("You are a helpful Ruby assistant.")
    end

    it "allows conditional matching" do
      result = case step
               in { system_prompt: /Ruby/ } then "ruby prompt"
               in { system_prompt: /Python/ } then "python prompt"
               else "other"
               end

      expect(result).to eq("ruby prompt")
    end
  end
end
