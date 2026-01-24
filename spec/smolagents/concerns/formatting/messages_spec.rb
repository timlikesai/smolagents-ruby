require "spec_helper"
require "smolagents/concerns/formatting/messages"

RSpec.describe Smolagents::Concerns::MessageFormatting do
  let(:test_class) do
    Class.new { include Smolagents::Concerns::MessageFormatting }
  end
  let(:formatter) { test_class.new }

  describe "#inject_before_last_user" do
    let(:system_msg) { Smolagents::Types::ChatMessage.system("System prompt") }
    let(:user_msg) { Smolagents::Types::ChatMessage.user("Hello") }
    let(:assistant_msg) { Smolagents::Types::ChatMessage.assistant("Hi there") }
    let(:context_msg) { Smolagents::Types::ChatMessage.system("[CONTEXT] Step 1") }

    context "with messages ending in user message" do
      let(:messages) { [system_msg, user_msg] }

      it "injects before the last user message" do
        result = formatter.inject_before_last_user(messages, context_msg)
        expect(result.size).to eq(3)
        expect(result[0]).to eq(system_msg)
        expect(result[1]).to eq(context_msg)
        expect(result[2]).to eq(user_msg)
      end

      it "does not modify original array" do
        original_size = messages.size
        formatter.inject_before_last_user(messages, context_msg)
        expect(messages.size).to eq(original_size)
      end
    end

    context "with multiple user messages" do
      let(:user_msg2) { Smolagents::Types::ChatMessage.user("Follow-up") }
      let(:messages) { [system_msg, user_msg, assistant_msg, user_msg2] }

      it "injects before the LAST user message only" do
        result = formatter.inject_before_last_user(messages, context_msg)
        expect(result.size).to eq(5)
        expect(result[3]).to eq(context_msg)
        expect(result[4]).to eq(user_msg2)
      end
    end

    context "with no user messages" do
      let(:messages) { [system_msg, assistant_msg] }

      it "appends to end" do
        result = formatter.inject_before_last_user(messages, context_msg)
        expect(result.size).to eq(3)
        expect(result.last).to eq(context_msg)
      end
    end

    context "with empty messages" do
      it "returns array with just the injected message" do
        result = formatter.inject_before_last_user([], context_msg)
        expect(result).to eq([context_msg])
      end
    end
  end
end
