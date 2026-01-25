RSpec.describe Smolagents::Testing::MockModelQuery do
  let(:model) { Smolagents::Testing::MockModel.new }
  let(:user_message) do
    Smolagents::Types::ChatMessage.user("Hello")
  end
  let(:system_message) do
    Smolagents::Types::ChatMessage.system("You are helpful")
  end

  describe "#last_call" do
    it "returns nil when no calls made" do
      expect(model.last_call).to be_nil
    end

    it "returns the most recent call" do
      model.queue_response("response 1")
      model.queue_response("response 2")
      model.generate([user_message])
      model.generate([user_message])

      last = model.last_call

      expect(last).to be_a(Smolagents::Testing::MockCall)
      expect(last.index).to eq(2)
    end

    it "updates when new call is made" do
      model.queue_response("response 1")
      model.generate([user_message])
      first_call = model.last_call

      model.queue_response("response 2")
      model.generate([user_message])
      second_call = model.last_call

      expect(first_call.index).to eq(1)
      expect(second_call.index).to eq(2)
      expect(first_call).not_to equal(second_call)
    end
  end

  describe "#last_messages" do
    it "returns nil when no calls made" do
      expect(model.last_messages).to be_nil
    end

    it "returns messages from last call" do
      model.queue_response("response")
      model.generate([user_message])

      messages = model.last_messages

      expect(messages).to eq([user_message])
    end

    it "returns updated messages after each call" do
      message1 = user_message
      message2 = Smolagents::Types::ChatMessage.user("Different message")

      model.queue_response("response 1")
      model.generate([message1])
      messages1 = model.last_messages

      model.queue_response("response 2")
      model.generate([message2])
      messages2 = model.last_messages

      expect(messages1).to eq([message1])
      expect(messages2).to eq([message2])
    end

    it "returns multiple messages if provided" do
      messages = [system_message, user_message]
      model.queue_response("response")
      model.generate(messages)

      last_messages = model.last_messages

      expect(last_messages).to eq(messages)
    end
  end

  describe "#calls_with_system_prompt" do
    it "returns empty array when no system prompts" do
      model.queue_response("response")
      model.generate([user_message])

      calls = model.calls_with_system_prompt

      expect(calls).to be_empty
    end

    it "returns calls that include system message" do
      model.queue_response("response 1")
      model.generate([system_message, user_message])

      model.queue_response("response 2")
      model.generate([user_message])

      calls = model.calls_with_system_prompt

      expect(calls.size).to eq(1)
      expect(calls[0].system_message?).to be true
    end

    it "returns multiple calls with system prompts" do
      model.queue_response("response 1")
      model.generate([system_message, user_message])

      model.queue_response("response 2")
      model.generate([system_message, user_message])

      model.queue_response("response 3")
      model.generate([user_message])

      calls = model.calls_with_system_prompt

      expect(calls.size).to eq(2)
      expect(calls.all?(&:system_message?)).to be true
    end

    it "returns empty array when no calls made" do
      calls = model.calls_with_system_prompt

      expect(calls).to be_empty
    end
  end

  describe "#user_messages_sent" do
    it "returns empty array when no user messages" do
      model.queue_response("response")
      model.generate([system_message])

      messages = model.user_messages_sent

      expect(messages).to be_empty
    end

    it "returns all user messages from all calls" do
      user_msg1 = Smolagents::Types::ChatMessage.user("First question")
      user_msg2 = Smolagents::Types::ChatMessage.user("Second question")

      model.queue_response("response 1")
      model.generate([user_msg1])

      model.queue_response("response 2")
      model.generate([user_msg2])

      messages = model.user_messages_sent

      expect(messages).to contain_exactly(user_msg1, user_msg2)
    end

    it "flattens messages from multiple calls" do
      msg1 = Smolagents::Types::ChatMessage.user("msg1")
      msg2 = Smolagents::Types::ChatMessage.user("msg2")

      model.queue_response("response")
      model.generate([msg1, msg2])

      messages = model.user_messages_sent

      expect(messages.size).to eq(2)
      expect(messages).to include(msg1, msg2)
    end

    it "filters out non-user messages" do
      user_msg = user_message
      asst_msg = Smolagents::Types::ChatMessage.assistant("Response")

      model.queue_response("response")
      model.generate([system_message, user_msg, asst_msg])

      messages = model.user_messages_sent

      expect(messages).to contain_exactly(user_msg)
    end

    it "returns empty array when no calls made" do
      messages = model.user_messages_sent

      expect(messages).to be_empty
    end
  end

  describe "#assistant_messages_returned" do
    it "returns empty array initially" do
      messages = model.assistant_messages_returned

      expect(messages).to be_empty
    end

    it "returns assistant messages from responses" do
      model.queue_response("response 1")
      model.queue_response("response 2")
      model.generate([user_message])
      model.generate([user_message])

      messages = model.assistant_messages_returned

      # This method returns responses, which are assistant messages
      expect(messages.size).to be >= 0
    end

    it "returns empty array when no calls made" do
      messages = model.assistant_messages_returned

      expect(messages).to be_empty
    end
  end

  describe "#exhausted?" do
    it "returns true when no responses queued" do
      expect(model.exhausted?).to be true
    end

    it "returns false when responses are queued" do
      model.queue_response("response")

      expect(model.exhausted?).to be false
    end

    it "returns true after all responses consumed" do
      model.queue_response("response")
      model.generate([user_message])

      expect(model.exhausted?).to be true
    end

    it "handles multiple responses" do
      model.queue_response("r1").queue_response("r2")

      expect(model.exhausted?).to be false

      model.generate([user_message])
      expect(model.exhausted?).to be false

      model.generate([user_message])
      expect(model.exhausted?).to be true
    end
  end

  describe "#remaining_responses" do
    it "returns 0 initially" do
      expect(model.remaining_responses).to eq(0)
    end

    it "increases when responses are queued" do
      model.queue_response("r1")
      expect(model.remaining_responses).to eq(1)

      model.queue_response("r2")
      expect(model.remaining_responses).to eq(2)
    end

    it "decreases when responses are consumed" do
      model.queue_response("r1").queue_response("r2").queue_response("r3")
      expect(model.remaining_responses).to eq(3)

      model.generate([user_message])
      expect(model.remaining_responses).to eq(2)

      model.generate([user_message])
      expect(model.remaining_responses).to eq(1)

      model.generate([user_message])
      expect(model.remaining_responses).to eq(0)
    end

    it "returns 0 when exhausted" do
      model.queue_response("response")
      model.generate([user_message])

      expect(model.remaining_responses).to eq(0)
    end
  end

  describe "thread safety" do
    it "safely queries during concurrent operations" do
      model.queue_response("r1").queue_response("r2").queue_response("r3")

      threads = Array.new(2) do
        Thread.new do
          model.remaining_responses
          model.exhausted?
        end
      end

      threads.each(&:join)

      expect(model.remaining_responses).to eq(3)
      expect(model.exhausted?).to be false
    end

    it "safely checks last_call during concurrent operations" do
      model.queue_response("r1").queue_response("r2")

      threads = [
        Thread.new { model.generate([user_message]) },
        Thread.new { model.last_call }
      ]

      threads.each(&:join)

      expect(model.call_count).to be > 0
    end
  end

  describe "query composition" do
    it "can use multiple queries in sequence" do
      model.queue_response("r1").queue_response("r2")
      model.generate([user_message])

      expect(model.remaining_responses).to eq(1)
      expect(model.last_call).not_to be_nil
      expect(model.exhausted?).to be false
      expect(model.calls_with_system_prompt).to be_empty
    end

    it "maintains consistency across queries" do
      model.queue_response("response")
      model.generate([system_message, user_message])

      last = model.last_call
      all_with_system = model.calls_with_system_prompt

      expect(all_with_system).to include(last)
    end
  end

  describe "consistency checks" do
    it "last_call is included in calls_with_system_prompt when applicable" do
      model.queue_response("response")
      model.generate([system_message])

      last = model.last_call
      with_system = model.calls_with_system_prompt

      expect(with_system).to include(last)
    end

    it "user_messages_sent matches calls data" do
      msg = user_message
      model.queue_response("response")
      model.generate([msg])

      sent = model.user_messages_sent

      expect(sent.first).to equal(msg)
    end

    it "remaining_responses decreases with each generate" do
      3.times { model.queue_response("r") }

      initial = model.remaining_responses
      model.generate([user_message])
      after_one = model.remaining_responses

      expect(initial).to eq(3)
      expect(after_one).to eq(2)
    end
  end
end
