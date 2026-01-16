RSpec.describe Smolagents::Testing::MockModel do
  subject(:model) { described_class.new }

  describe "#initialize" do
    it "creates with default model_id" do
      expect(model.model_id).to eq("mock-model")
    end

    it "accepts custom model_id" do
      custom = described_class.new(model_id: "custom-model")
      expect(custom.model_id).to eq("custom-model")
    end

    it "starts with zero calls" do
      expect(model.call_count).to eq(0)
      expect(model.calls).to be_empty
    end
  end

  describe "#queue_response" do
    it "accepts string content" do
      model.queue_response("Hello")
      result = model.generate([])
      expect(result.content).to eq("Hello")
    end

    it "accepts ChatMessage directly" do
      message = Smolagents::ChatMessage.assistant("Direct message")
      model.queue_response(message)
      result = model.generate([])
      expect(result.content).to eq("Direct message")
    end

    it "includes token usage" do
      model.queue_response("Test", input_tokens: 100, output_tokens: 50)
      result = model.generate([])
      expect(result.token_usage.input_tokens).to eq(100)
      expect(result.token_usage.output_tokens).to eq(50)
    end

    it "returns self for chaining" do
      expect(model.queue_response("a")).to eq(model)
    end
  end

  describe "#queue_code_action" do
    it "wraps code in tags" do
      model.queue_code_action("puts 'hello'")
      result = model.generate([])
      expect(result.content).to eq("<code>\nputs 'hello'\n</code>")
    end

    it "returns self for chaining" do
      expect(model.queue_code_action("code")).to eq(model)
    end
  end

  describe "#queue_final_answer" do
    it "creates final_answer code action" do
      model.queue_final_answer("The answer is 42")
      result = model.generate([])
      expect(result.content).to include('final_answer("The answer is 42")')
    end

    it "properly escapes strings" do
      model.queue_final_answer("Answer with \"quotes\"")
      result = model.generate([])
      expect(result.content).to include('final_answer("Answer with \\"quotes\\"")')
    end
  end

  describe "#queue_planning_response" do
    it "queues plain text response" do
      model.queue_planning_response("I will search first")
      result = model.generate([])
      expect(result.content).to eq("I will search first")
    end
  end

  describe "#queue_tool_call" do
    it "creates message with tool_calls" do
      model.queue_tool_call("search", query: "Ruby")
      result = model.generate([])
      expect(result.tool_calls).not_to be_empty
      expect(result.tool_calls.first.name).to eq("search")
      expect(result.tool_calls.first.arguments).to eq({ query: "Ruby" })
    end

    it "generates unique id by default" do
      model.queue_tool_call("tool")
      result = model.generate([])
      expect(result.tool_calls.first.id).not_to be_nil
    end

    it "accepts custom id" do
      model.queue_tool_call("tool", id: "custom-id")
      result = model.generate([])
      expect(result.tool_calls.first.id).to eq("custom-id")
    end
  end

  describe "#generate" do
    it "returns responses in FIFO order" do
      model.queue_response("first")
      model.queue_response("second")
      model.queue_response("third")

      expect(model.generate([]).content).to eq("first")
      expect(model.generate([]).content).to eq("second")
      expect(model.generate([]).content).to eq("third")
    end

    it "records calls" do
      messages = [Smolagents::ChatMessage.user("Hello")]
      model.queue_response("Hi")
      model.generate(messages)

      expect(model.calls.size).to eq(1)
      expect(model.calls.first[:messages]).to eq(messages)
    end

    it "increments call_count" do
      model.queue_response("a").queue_response("b")
      model.generate([])
      expect(model.call_count).to eq(1)
      model.generate([])
      expect(model.call_count).to eq(2)
    end

    it "raises when no responses queued" do
      expect { model.generate([]) }.to raise_error(/No more queued responses/)
    end

    it "includes helpful message when exhausted" do
      expect { model.generate([]) }.to raise_error(/queue_response\(\)/)
    end

    it "records tools_to_call_from" do
      mock_tool = double("Tool") # rubocop:disable RSpec/VerifiedDoubles
      model.queue_response("ok")
      model.generate([], tools_to_call_from: [mock_tool])

      expect(model.last_call[:tools_to_call_from]).to eq([mock_tool])
    end
  end

  describe "#last_call" do
    it "returns nil when no calls made" do
      expect(model.last_call).to be_nil
    end

    it "returns the most recent call" do
      model.queue_response("a").queue_response("b")
      model.generate([Smolagents::ChatMessage.user("first")])
      model.generate([Smolagents::ChatMessage.user("second")])

      expect(model.last_call[:messages].first.content).to eq("second")
    end
  end

  describe "#last_messages" do
    it "returns messages from last call" do
      messages = [Smolagents::ChatMessage.user("test")]
      model.queue_response("ok")
      model.generate(messages)

      expect(model.last_messages).to eq(messages)
    end
  end

  describe "#reset!" do
    it "clears all state" do
      model.queue_response("test")
      model.generate([])

      model.reset!

      expect(model.calls).to be_empty
      expect(model.call_count).to eq(0)
      expect(model.remaining_responses).to eq(0)
    end

    it "returns self for chaining" do
      expect(model.reset!).to eq(model)
    end
  end

  describe "#calls_with_system_prompt" do
    it "filters calls with system messages" do
      model.queue_response("a").queue_response("b")
      model.generate([Smolagents::ChatMessage.system("You are helpful")])
      model.generate([Smolagents::ChatMessage.user("Hi")])

      result = model.calls_with_system_prompt
      expect(result.size).to eq(1)
      expect(result.first[:messages].first.role).to eq(:system)
    end
  end

  describe "#user_messages_sent" do
    it "returns all user messages across calls" do
      model.queue_response("a").queue_response("b")
      model.generate([Smolagents::ChatMessage.user("first")])
      model.generate([Smolagents::ChatMessage.user("second")])

      messages = model.user_messages_sent
      expect(messages.map(&:content)).to eq(%w[first second])
    end

    it "filters out non-user messages" do
      model.queue_response("ok")
      model.generate([
                       Smolagents::ChatMessage.system("system"),
                       Smolagents::ChatMessage.user("user"),
                       Smolagents::ChatMessage.assistant("assistant")
                     ])

      messages = model.user_messages_sent
      expect(messages.size).to eq(1)
      expect(messages.first.content).to eq("user")
    end
  end

  describe "#exhausted?" do
    it "returns false when responses remain" do
      model.queue_response("test")
      expect(model).not_to be_exhausted
    end

    it "returns true when all responses consumed" do
      model.queue_response("test")
      model.generate([])
      expect(model).to be_exhausted
    end
  end

  describe "#remaining_responses" do
    it "counts unconsumed responses" do
      model.queue_response("a").queue_response("b").queue_response("c")
      expect(model.remaining_responses).to eq(3)

      model.generate([])
      expect(model.remaining_responses).to eq(2)
    end
  end

  describe "thread safety" do
    it "handles concurrent access", :slow do
      10.times { model.queue_response("ok") }

      threads = Array.new(10) do
        Thread.new { model.generate([]) }
      end

      results = threads.map(&:value)
      expect(results.size).to eq(10)
      expect(model).to be_exhausted
    end
  end

  describe "chaining" do
    it "supports fluent interface" do
      model
        .queue_code_action("search(query: 'test')")
        .queue_planning_response("Analyzing results...")
        .queue_final_answer("Found 5 results")

      expect(model.remaining_responses).to eq(3)
    end
  end
end
