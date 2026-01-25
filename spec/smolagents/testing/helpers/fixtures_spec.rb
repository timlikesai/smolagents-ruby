RSpec.describe Smolagents::Testing::Helpers::Fixtures do
  describe ".chat_message" do
    it "creates a ChatMessage with default parameters" do
      message = described_class.chat_message

      expect(message).to be_a(Smolagents::Types::ChatMessage)
      expect(message.role).to eq(Smolagents::Types::MessageRole::ASSISTANT)
      expect(message.content).to eq("Test message")
    end

    it "accepts custom role" do
      message = described_class.chat_message(role: :user)

      expect(message.role).to eq(Smolagents::Types::MessageRole::USER)
    end

    it "accepts custom content" do
      message = described_class.chat_message(content: "Custom content")

      expect(message.content).to eq("Custom content")
    end

    it "accepts system role" do
      message = described_class.chat_message(role: :system)

      expect(message.role).to eq(Smolagents::Types::MessageRole::SYSTEM)
    end

    it "accepts assistant role" do
      message = described_class.chat_message(role: :assistant)

      expect(message.role).to eq(Smolagents::Types::MessageRole::ASSISTANT)
    end

    it "accepts additional attributes" do
      usage = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      message = described_class.chat_message(token_usage: usage)

      expect(message.token_usage).to equal(usage)
    end

    it "creates multiple independent instances" do
      msg1 = described_class.chat_message(content: "msg1")
      msg2 = described_class.chat_message(content: "msg2")

      expect(msg1.content).to eq("msg1")
      expect(msg2.content).to eq("msg2")
    end
  end

  describe ".action_step" do
    it "creates an ActionStep with default parameters" do
      step = described_class.action_step

      expect(step).to be_a(Smolagents::Types::ActionStep)
      expect(step.step_number).to eq(1)
    end

    it "accepts custom step_number" do
      step = described_class.action_step(step_number: 5)

      expect(step.step_number).to eq(5)
    end

    it "initializes timing" do
      step = described_class.action_step

      expect(step.timing).to be_a(Smolagents::Types::Timing)
    end

    it "timing is started" do
      step = described_class.action_step

      # Timing should have start_time set
      expect(step.timing.start_time).not_to be_nil
    end

    it "accepts additional attributes" do
      code_action = "result = add(a: 1, b: 2)"
      step = described_class.action_step(code_action:)

      expect(step.code_action).to eq(code_action)
    end

    it "can set multiple attributes" do
      observations = "Tool returned 42"
      step = described_class.action_step(step_number: 3, observations:)

      expect(step.step_number).to eq(3)
      expect(step.observations).to eq(observations)
    end

    it "creates independent instances" do
      step1 = described_class.action_step(step_number: 1)
      step2 = described_class.action_step(step_number: 2)

      expect(step1.step_number).to eq(1)
      expect(step2.step_number).to eq(2)
    end
  end

  describe ".tool_call" do
    it "creates a ToolCall with default parameters" do
      tool_call = described_class.tool_call

      expect(tool_call).to be_a(Smolagents::Types::ToolCall)
      expect(tool_call.name).to eq("test_tool")
      expect(tool_call.arguments).to eq({})
    end

    it "accepts custom name" do
      tool_call = described_class.tool_call(name: "search")

      expect(tool_call.name).to eq("search")
    end

    it "accepts custom arguments" do
      args = { query: "test", limit: 10 }
      tool_call = described_class.tool_call(arguments: args)

      expect(tool_call.arguments).to eq(args)
    end

    it "accepts custom id" do
      custom_id = "my-custom-id-123"
      tool_call = described_class.tool_call(id: custom_id)

      expect(tool_call.id).to eq(custom_id)
    end

    it "auto-generates unique id by default" do
      tool_call = described_class.tool_call

      expect(tool_call.id).to be_a(String)
      expect(tool_call.id).not_to be_empty
    end

    it "generates different ids each time" do
      call1 = described_class.tool_call
      call2 = described_class.tool_call

      expect(call1.id).not_to eq(call2.id)
    end

    it "combines name and arguments" do
      tool_call = described_class.tool_call(name: "add", arguments: { a: 5, b: 3 })

      expect(tool_call.name).to eq("add")
      expect(tool_call.arguments[:a]).to eq(5)
      expect(tool_call.arguments[:b]).to eq(3)
    end

    it "creates independent instances" do
      call1 = described_class.tool_call(name: "tool1")
      call2 = described_class.tool_call(name: "tool2")

      expect(call1.name).to eq("tool1")
      expect(call2.name).to eq("tool2")
    end
  end

  describe ".token_usage" do
    it "creates a TokenUsage with default parameters" do
      usage = described_class.token_usage

      expect(usage).to be_a(Smolagents::Types::TokenUsage)
      expect(usage.input_tokens).to eq(100)
      expect(usage.output_tokens).to eq(50)
    end

    it "accepts custom input tokens" do
      usage = described_class.token_usage(input: 200)

      expect(usage.input_tokens).to eq(200)
      expect(usage.output_tokens).to eq(50)
    end

    it "accepts custom output tokens" do
      usage = described_class.token_usage(output: 100)

      expect(usage.input_tokens).to eq(100)
      expect(usage.output_tokens).to eq(100)
    end

    it "accepts both custom values" do
      usage = described_class.token_usage(input: 500, output: 250)

      expect(usage.input_tokens).to eq(500)
      expect(usage.output_tokens).to eq(250)
    end

    it "creates independent instances" do
      usage1 = described_class.token_usage(input: 100)
      usage2 = described_class.token_usage(input: 200)

      expect(usage1.input_tokens).to eq(100)
      expect(usage2.input_tokens).to eq(200)
    end

    it "supports total_tokens calculation" do
      usage = described_class.token_usage(input: 100, output: 50)

      expect(usage.total_tokens).to eq(150)
    end
  end

  describe "fixture reuse" do
    it "can create multiple messages for a conversation" do
      messages = [
        described_class.chat_message(role: :user, content: "Hello"),
        described_class.chat_message(role: :assistant, content: "Hi there"),
        described_class.chat_message(role: :user, content: "How are you?")
      ]

      expect(messages.size).to eq(3)
      expect(messages[0].content).to eq("Hello")
      expect(messages[1].content).to eq("Hi there")
      expect(messages[2].content).to eq("How are you?")
    end

    it "can build a complete step with sub-fixtures" do
      step = described_class.action_step(step_number: 1)
      tool_call = described_class.tool_call(name: "search")
      message = described_class.chat_message(role: :assistant)

      expect(step.step_number).to eq(1)
      expect(tool_call.name).to eq("search")
      expect(message.role).to eq(Smolagents::Types::MessageRole::ASSISTANT)
    end

    it "can create fixtures with varying token usage" do
      small_usage = described_class.token_usage(input: 10, output: 5)
      large_usage = described_class.token_usage(input: 1000, output: 500)

      expect(small_usage.total_tokens).to eq(15)
      expect(large_usage.total_tokens).to eq(1500)
    end
  end

  describe "fixture composition" do
    it "chat_message and tool_call work together" do
      message = described_class.chat_message(role: :assistant)
      tool_call = described_class.tool_call(name: "search")

      # Both can be created independently
      expect(message.role).to eq(Smolagents::Types::MessageRole::ASSISTANT)
      expect(tool_call.name).to eq("search")
    end

    it "action_step and token_usage combine" do
      step = described_class.action_step(step_number: 2)
      usage = described_class.token_usage(input: 50, output: 25)

      # Can use together in tests
      expect(step.step_number).to eq(2)
      expect(usage.total_tokens).to eq(75)
    end
  end

  describe "fixture stability" do
    it "returns consistent structure for repeated calls" do
      msg1 = described_class.chat_message
      msg2 = described_class.chat_message

      expect(msg1.class).to eq(msg2.class)
      expect(msg1.role).to eq(msg2.role)
    end

    it "default values remain constant" do
      usage1 = described_class.token_usage
      usage2 = described_class.token_usage

      expect(usage1.input_tokens).to eq(usage2.input_tokens)
      expect(usage1.output_tokens).to eq(usage2.output_tokens)
    end
  end

  describe "module functionality" do
    it "is a module" do
      expect(described_class).to be_a(Module)
    end

    it "responds to all fixture methods" do
      expect(described_class).to respond_to(:chat_message)
      expect(described_class).to respond_to(:action_step)
      expect(described_class).to respond_to(:tool_call)
      expect(described_class).to respond_to(:token_usage)
    end

    it "can be included in test classes" do
      test_class = Class.new do
        include Smolagents::Testing::Helpers::Fixtures
      end

      # module_function makes methods private instance methods when included
      instance = test_class.new
      # Private methods are accessible via send
      expect { instance.send(:chat_message) }.not_to raise_error
    end
  end
end
