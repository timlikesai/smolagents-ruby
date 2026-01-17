# Shared examples for model interface specs.
# Models are adapters to LLM providers with a common interface.

RSpec.shared_examples "a model" do
  describe "interface" do
    describe "#model_id" do
      it "returns the model identifier" do
        expect(model.model_id).to be_a(String)
        expect(model.model_id).not_to be_empty
      end
    end

    describe "#generate" do
      it "accepts messages and returns a ChatMessage" do
        response = model.generate(messages)

        expect(response).to be_a(Smolagents::ChatMessage)
      end
    end
  end
end

RSpec.shared_examples "a streaming model" do
  describe "#generate_stream" do
    it "returns an Enumerator when no block given" do
      result = model.generate_stream(messages)
      expect(result).to be_a(Enumerator)
    end
  end
end

RSpec.shared_examples "a chat model" do
  describe "chat completion" do
    it "generates assistant role responses" do
      response = model.generate(messages)

      expect(response.role).to eq(:assistant)
    end

    it "generates responses with content" do
      response = model.generate(messages)

      expect(response.content).to be_a(String)
    end

    it "includes token usage in response" do
      response = model.generate(messages)

      expect(response.token_usage).to be_a(Smolagents::TokenUsage)
      expect(response.token_usage.input_tokens).to be_a(Integer)
      expect(response.token_usage.output_tokens).to be_a(Integer)
    end
  end
end

RSpec.shared_examples "a model with tool calling" do
  describe "tool calling" do
    it "parses tool calls from response" do
      response = model.generate(messages_with_tool_response)

      expect(response.tool_calls).to be_an(Array)
      expect(response.tool_calls.first).to respond_to(:name)
      expect(response.tool_calls.first).to respond_to(:arguments)
    end
  end
end

RSpec.shared_examples "a model with message formatting" do
  describe "message formatting" do
    it "formats user messages" do
      messages = [Smolagents::ChatMessage.user("Hello")]
      response = model.generate(messages)

      expect(response).to be_a(Smolagents::ChatMessage)
    end

    it "formats system messages" do
      messages = [
        Smolagents::ChatMessage.system("You are helpful"),
        Smolagents::ChatMessage.user("Hello")
      ]
      response = model.generate(messages)

      expect(response).to be_a(Smolagents::ChatMessage)
    end

    it "formats assistant messages in conversation history" do
      messages = [
        Smolagents::ChatMessage.user("Hello"),
        Smolagents::ChatMessage.assistant("Hi there"),
        Smolagents::ChatMessage.user("How are you?")
      ]
      response = model.generate(messages)

      expect(response).to be_a(Smolagents::ChatMessage)
    end
  end
end
