RSpec.describe Smolagents::Testing::MockCall do
  let(:now) { Time.now }

  let(:user_message) do
    Smolagents::Types::ChatMessage.user("What is 2 + 2?")
  end

  let(:assistant_message) do
    Smolagents::Types::ChatMessage.assistant("The answer is 4")
  end

  let(:system_message) do
    Smolagents::Types::ChatMessage.system("You are a helpful assistant")
  end

  describe "initialization" do
    it "creates a MockCall with all attributes" do
      messages = [user_message, assistant_message]
      tools = [instance_double(Smolagents::Tools::Tool, name: "search")]
      timestamp = now

      call = described_class.new(
        index: 1,
        messages:,
        tools_to_call_from: tools,
        timestamp:
      )

      expect(call.index).to eq(1)
      expect(call.messages).to eq(messages)
      expect(call.tools_to_call_from).to eq(tools)
      expect(call.timestamp).to eq(timestamp)
    end

    it "allows nil tools_to_call_from" do
      messages = [user_message]

      call = described_class.new(
        index: 1,
        messages:,
        tools_to_call_from: nil,
        timestamp: now
      )

      expect(call.tools_to_call_from).to be_nil
    end
  end

  describe "#system_message?" do
    it "returns true when system message is present" do
      messages = [system_message, user_message]

      call = described_class.new(
        index: 1,
        messages:,
        tools_to_call_from: nil,
        timestamp: now
      )

      expect(call.system_message?).to be true
    end

    it "returns false when no system message" do
      messages = [user_message, assistant_message]

      call = described_class.new(
        index: 1,
        messages:,
        tools_to_call_from: nil,
        timestamp: now
      )

      expect(call.system_message?).to be false
    end

    it "returns false for empty messages" do
      call = described_class.new(
        index: 1,
        messages: [],
        tools_to_call_from: nil,
        timestamp: now
      )

      expect(call.system_message?).to be false
    end
  end

  describe "#user_messages" do
    it "returns only user messages" do
      messages = [system_message, user_message, assistant_message]

      call = described_class.new(
        index: 1,
        messages:,
        tools_to_call_from: nil,
        timestamp: now
      )

      user_msgs = call.user_messages

      expect(user_msgs).to contain_exactly(user_message)
      expect(user_msgs.all? { |m| m.role == Smolagents::Types::MessageRole::USER }).to be true
    end

    it "returns empty array when no user messages" do
      messages = [system_message, assistant_message]

      call = described_class.new(
        index: 1,
        messages:,
        tools_to_call_from: nil,
        timestamp: now
      )

      expect(call.user_messages).to be_empty
    end
  end

  describe "#assistant_messages" do
    it "returns only assistant messages" do
      messages = [system_message, user_message, assistant_message]

      call = described_class.new(
        index: 1,
        messages:,
        tools_to_call_from: nil,
        timestamp: now
      )

      asst_msgs = call.assistant_messages

      expect(asst_msgs).to contain_exactly(assistant_message)
      expect(asst_msgs.all? { |m| m.role == Smolagents::Types::MessageRole::ASSISTANT }).to be true
    end

    it "returns empty array when no assistant messages" do
      messages = [system_message, user_message]

      call = described_class.new(
        index: 1,
        messages:,
        tools_to_call_from: nil,
        timestamp: now
      )

      expect(call.assistant_messages).to be_empty
    end
  end

  describe "#last_user_content" do
    it "returns content of the last user message" do
      user_msg2 = Smolagents::Types::ChatMessage.user("Last question?")
      messages = [user_message, assistant_message, user_msg2]

      call = described_class.new(
        index: 1,
        messages:,
        tools_to_call_from: nil,
        timestamp: now
      )

      expect(call.last_user_content).to eq("Last question?")
    end

    it "returns nil when no user messages" do
      messages = [system_message, assistant_message]

      call = described_class.new(
        index: 1,
        messages:,
        tools_to_call_from: nil,
        timestamp: now
      )

      expect(call.last_user_content).to be_nil
    end

    it "returns nil for empty messages" do
      call = described_class.new(
        index: 1,
        messages: [],
        tools_to_call_from: nil,
        timestamp: now
      )

      expect(call.last_user_content).to be_nil
    end
  end

  describe "immutability" do
    it "is frozen after creation" do
      call = described_class.new(
        index: 1,
        messages: [user_message],
        tools_to_call_from: nil,
        timestamp: now
      )

      expect(call).to be_frozen
    end

    it "raises NoMethodError when attempting to modify (Data.define has no setters)" do
      call = described_class.new(
        index: 1,
        messages: [user_message],
        tools_to_call_from: nil,
        timestamp: now
      )

      expect { call.index = 2 }.to raise_error(NoMethodError)
    end
  end

  describe "Data.define behavior" do
    it "has all expected attributes" do
      call = described_class.new(
        index: 2,
        messages: [user_message],
        tools_to_call_from: nil,
        timestamp: now
      )

      expect(call.to_h).to include(
        index: 2,
        messages: [user_message],
        tools_to_call_from: nil,
        timestamp: now
      )
    end

    it "enables pattern matching" do
      messages = [user_message]
      call = described_class.new(
        index: 3,
        messages:,
        tools_to_call_from: nil,
        timestamp: now
      )

      result = case call
               in { index: 3, messages: msgs }
                 msgs
               else
                 nil
               end

      expect(result).to eq(messages)
    end
  end
end
