require "smolagents/models/model"
require "smolagents/models/anthropic_model"

begin
  require "anthropic"
rescue LoadError
end

RSpec.describe Smolagents::AnthropicModel do
  let(:api_key) { "test-api-key" }
  let(:model_id) { "claude-3-5-sonnet-20241022" }

  describe "#initialize" do
    it "creates a model with required parameters" do
      model = described_class.new(model_id: model_id, api_key: api_key)
      expect(model.model_id).to eq(model_id)
    end

    it "raises LoadError with helpful message when ruby-anthropic gem is not installed" do
      allow_any_instance_of(described_class).to receive(:require).with("anthropic").and_raise(LoadError)

      expect do
        described_class.new(model_id: model_id, api_key: api_key)
      end.to raise_error(LoadError, /ruby-anthropic gem required for Anthropic models/)
    end

    it "uses ENV['ANTHROPIC_API_KEY'] if no api_key provided" do
      ENV["ANTHROPIC_API_KEY"] = "env-key"
      model = described_class.new(model_id: model_id)
      expect(model.model_id).to eq(model_id)
      ENV.delete("ANTHROPIC_API_KEY")
    end

    it "accepts temperature and max_tokens" do
      model = described_class.new(
        model_id: model_id,
        api_key: api_key,
        temperature: 0.5,
        max_tokens: 100
      )
      expect(model.model_id).to eq(model_id)
    end
  end

  describe "#generate" do
    let(:model) { described_class.new(model_id: model_id, api_key: api_key) }
    let(:messages) { [Smolagents::ChatMessage.user("Hello")] }

    let(:mock_response) do
      {
        "id" => "msg_123",
        "type" => "message",
        "role" => "assistant",
        "content" => [
          {
            "type" => "text",
            "text" => "Hello! How can I help you?"
          }
        ],
        "model" => "claude-3-5-sonnet-20241022",
        "stop_reason" => "end_turn",
        "usage" => {
          "input_tokens" => 10,
          "output_tokens" => 20
        }
      }
    end

    before do
      allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(mock_response)
    end

    it "generates a response" do
      response = model.generate(messages)

      expect(response).to be_a(Smolagents::ChatMessage)
      expect(response.role).to eq(:assistant)
      expect(response.content).to eq("Hello! How can I help you?")
    end

    it "includes token usage" do
      response = model.generate(messages)

      expect(response.token_usage).to be_a(Smolagents::TokenUsage)
      expect(response.token_usage.input_tokens).to eq(10)
      expect(response.token_usage.output_tokens).to eq(20)
      expect(response.token_usage.total_tokens).to eq(30)
    end

    it "handles tool calls" do
      mock_response_with_tools = mock_response.dup
      mock_response_with_tools["content"] << {
        "type" => "tool_use",
        "id" => "toolu_123",
        "name" => "search",
        "input" => { "query" => "test" }
      }

      allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(mock_response_with_tools)

      response = model.generate(messages)

      expect(response.tool_calls).to be_an(Array)
      expect(response.tool_calls.size).to eq(1)
      expect(response.tool_calls.first.name).to eq("search")
      expect(response.tool_calls.first.arguments).to eq({ "query" => "test" })
    end

    it "extracts system messages separately" do
      messages_with_system = [
        Smolagents::ChatMessage.system("You are helpful"),
        Smolagents::ChatMessage.user("Hello")
      ]

      expect_any_instance_of(Anthropic::Client).to receive(:messages) do |_, parameters:|
        expect(parameters[:system]).to eq("You are helpful")
        expect(parameters[:messages].size).to eq(1)
        expect(parameters[:messages].first[:role]).to eq("user")
        mock_response
      end

      model.generate(messages_with_system)
    end

    it "passes stop sequences" do
      expect_any_instance_of(Anthropic::Client).to receive(:messages) do |_, parameters:|
        expect(parameters[:stop_sequences]).to eq(["STOP"])
        mock_response
      end

      model.generate(messages, stop_sequences: ["STOP"])
    end

    it "formats tools when provided" do
      search_tool = Class.new(Smolagents::Tool) do
        self.tool_name = "search"
        self.description = "Search for information"
        self.inputs = { query: { type: "string", description: "Search query" } }
        self.output_type = "string"
      end.new

      expect_any_instance_of(Anthropic::Client).to receive(:messages) do |_, parameters:|
        expect(parameters[:tools]).to be_an(Array)
        expect(parameters[:tools].first[:name]).to eq("search")
        expect(parameters[:tools].first[:input_schema]).to be_a(Hash)
        mock_response
      end

      model.generate(messages, tools_to_call_from: [search_tool])
    end

    it "handles API errors" do
      error_response = { "error" => { "message" => "Rate limit exceeded" } }
      allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(error_response)

      expect do
        model.generate(messages)
      end.to raise_error(Smolagents::AgentGenerationError, /Rate limit exceeded/)
    end

    it "retries on Faraday errors" do
      call_count = 0
      allow_any_instance_of(Anthropic::Client).to receive(:messages) do
        call_count += 1
        raise Faraday::ConnectionFailed, "Connection failed" if call_count < 3

        mock_response
      end

      response = model.generate(messages)
      expect(response.content).to eq("Hello! How can I help you?")
      expect(call_count).to eq(3)
    end

    it "retries on Anthropic::Error" do
      call_count = 0
      allow_any_instance_of(Anthropic::Client).to receive(:messages) do
        call_count += 1
        raise Anthropic::Error, "API error" if call_count < 2

        mock_response
      end

      response = model.generate(messages)
      expect(response.content).to eq("Hello! How can I help you?")
      expect(call_count).to eq(2)
    end

    it "does not retry on AgentGenerationError" do
      call_count = 0
      allow_any_instance_of(Anthropic::Client).to receive(:messages) do
        call_count += 1
        raise Smolagents::AgentGenerationError, "Logic error"
      end

      expect do
        model.generate(messages)
      end.to raise_error(Smolagents::AgentGenerationError, /Logic error/)
      expect(call_count).to eq(1)
    end

    it "does not retry on InterpreterError" do
      call_count = 0
      allow_any_instance_of(Anthropic::Client).to receive(:messages) do
        call_count += 1
        raise Smolagents::InterpreterError, "Interpreter error"
      end

      expect do
        model.generate(messages)
      end.to raise_error(Smolagents::InterpreterError, /Interpreter error/)
      expect(call_count).to eq(1)
    end
  end

  describe "#extract_system_message" do
    let(:model) { described_class.new(model_id: model_id, api_key: api_key) }

    it "separates system from user messages" do
      messages = [
        Smolagents::ChatMessage.system("System prompt"),
        Smolagents::ChatMessage.user("Hello"),
        Smolagents::ChatMessage.assistant("Hi")
      ]

      system, user_messages = model.send(:extract_system_message, messages)

      expect(system).to eq("System prompt")
      expect(user_messages.size).to eq(2)
      expect(user_messages.map(&:role)).to eq(%i[user assistant])
    end

    it "combines multiple system messages" do
      messages = [
        Smolagents::ChatMessage.system("First"),
        Smolagents::ChatMessage.system("Second"),
        Smolagents::ChatMessage.user("Hello")
      ]

      system, user_messages = model.send(:extract_system_message, messages)

      expect(system).to eq("First\n\nSecond")
      expect(user_messages.size).to eq(1)
    end

    it "returns nil if no system messages" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      system, user_messages = model.send(:extract_system_message, messages)

      expect(system).to be_nil
      expect(user_messages.size).to eq(1)
    end
  end

  describe "circuit breaker integration" do
    let(:model) { described_class.new(model_id: model_id, api_key: api_key) }
    let(:messages) { [Smolagents::ChatMessage.user("Hello")] }

    before do
      Stoplight.default_notifiers = []
    end

    it "opens circuit after multiple API failures" do
      allow_any_instance_of(Anthropic::Client).to receive(:messages).and_raise(Faraday::ConnectionFailed, "Connection failed")

      3.times do
        expect { model.generate(messages) }.to raise_error(Faraday::ConnectionFailed)
      end

      expect { model.generate(messages) }.to raise_error(Smolagents::AgentGenerationError, /Service unavailable.*circuit open.*anthropic_api/)
    end

    it "allows successful calls through" do
      mock_response = {
        "id" => "msg_123",
        "content" => [{ "type" => "text", "text" => "Hello!" }],
        "usage" => { "input_tokens" => 10, "output_tokens" => 5 }
      }
      allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(mock_response)

      5.times do
        response = model.generate(messages)
        expect(response.content).to eq("Hello!")
      end
    end
  end

  describe "#generate_stream" do
    let(:model) { described_class.new(model_id: model_id, api_key: api_key) }
    let(:messages) { [Smolagents::ChatMessage.user("Hello")] }

    it "returns an enumerator when no block given" do
      result = model.generate_stream(messages)
      expect(result).to be_a(Enumerator)
    end

    it "yields chunks as they arrive" do
      # rubocop:disable Lint/UnusedBlockArgument
      allow_any_instance_of(Anthropic::Client).to receive(:messages) do |_instance, parameters: nil, &block|
        block&.call({ "type" => "content_block_delta", "delta" => { "type" => "text_delta", "text" => "Hello " } })
        block&.call({ "type" => "content_block_delta", "delta" => { "type" => "text_delta", "text" => "world" } })
        block&.call({ "type" => "message_stop" })
      end
      # rubocop:enable Lint/UnusedBlockArgument

      yielded_content = []
      model.generate_stream(messages) do |chunk|
        yielded_content << chunk.content
      end

      expect(yielded_content).to eq(["Hello ", "world"])
    end

    it "skips non-text-delta chunks" do
      # rubocop:disable Lint/UnusedBlockArgument
      allow_any_instance_of(Anthropic::Client).to receive(:messages) do |_instance, parameters: nil, &block|
        block&.call({ "type" => "content_block_start" })
        block&.call({ "type" => "content_block_delta", "delta" => { "type" => "text_delta", "text" => "Hello" } })
        block&.call({ "type" => "message_stop" })
      end
      # rubocop:enable Lint/UnusedBlockArgument

      yielded_content = []
      model.generate_stream(messages) do |chunk|
        yielded_content << chunk.content
      end

      expect(yielded_content).to eq(["Hello"])
    end

    it "extracts system message for streaming" do
      messages_with_system = [
        Smolagents::ChatMessage.system("System prompt"),
        Smolagents::ChatMessage.user("Hello")
      ]

      expect_any_instance_of(Anthropic::Client).to receive(:messages) do |_, parameters:|
        expect(parameters[:system]).to eq("System prompt")
        expect(parameters[:messages].size).to eq(1)
      end

      model.generate_stream(messages_with_system) { |_chunk| }
    end

    it "passes temperature and max_tokens for streaming" do
      expect_any_instance_of(Anthropic::Client).to receive(:messages) do |_, parameters:|
        expect(parameters[:temperature]).to eq(0.7)
        expect(parameters[:max_tokens]).to eq(4096)
      end

      model.generate_stream(messages) { |_chunk| }
    end
  end

  describe "#format_messages" do
    let(:model) { described_class.new(model_id: model_id, api_key: api_key) }

    it "formats user messages" do
      messages = [Smolagents::ChatMessage.user("Hello")]
      formatted = model.send(:format_messages, messages)

      expect(formatted.size).to eq(1)
      expect(formatted[0][:role]).to eq("user")
      expect(formatted[0][:content]).to eq("Hello")
    end

    it "formats assistant messages" do
      messages = [Smolagents::ChatMessage.assistant("Hi there")]
      formatted = model.send(:format_messages, messages)

      expect(formatted.size).to eq(1)
      expect(formatted[0][:role]).to eq("assistant")
      expect(formatted[0][:content]).to eq("Hi there")
    end

    it "handles messages with empty content" do
      messages = [Smolagents::ChatMessage.user("")]
      formatted = model.send(:format_messages, messages)

      expect(formatted.first[:content]).to eq("")
    end

    it "handles nil content in messages" do
      messages = [Smolagents::ChatMessage.assistant(nil)]
      formatted = model.send(:format_messages, messages)

      expect(formatted.first[:content]).to eq("")
    end
  end

  describe "#format_tools" do
    let(:model) { described_class.new(model_id: model_id, api_key: api_key) }

    it "formats tool schema correctly" do
      search_tool = Class.new(Smolagents::Tool) do
        self.tool_name = "search"
        self.description = "Search the web"
        self.inputs = {
          query: { type: "string", description: "Search query" },
          limit: { type: "integer", description: "Number of results", default: 10 }
        }
        self.output_type = "string"
      end.new

      formatted = model.send(:format_tools, [search_tool])

      expect(formatted.size).to eq(1)
      tool_spec = formatted[0]
      expect(tool_spec[:name]).to eq("search")
      expect(tool_spec[:description]).to eq("Search the web")
      expect(tool_spec[:input_schema][:type]).to eq("object")
      expect(tool_spec[:input_schema][:properties]).to be_a(Hash)
      expect(tool_spec[:input_schema][:required]).to be_an(Array)
    end

    it "formats multiple tools" do
      tool1 = Class.new(Smolagents::Tool) do
        self.tool_name = "search"
        self.description = "Search"
        self.inputs = { query: { type: "string", description: "Search query" } }
        self.output_type = "string"
      end.new

      tool2 = Class.new(Smolagents::Tool) do
        self.tool_name = "read"
        self.description = "Read"
        self.inputs = { path: { type: "string", description: "File path" } }
        self.output_type = "string"
      end.new

      formatted = model.send(:format_tools, [tool1, tool2])

      expect(formatted.size).to eq(2)
      expect(formatted[0][:name]).to eq("search")
      expect(formatted[1][:name]).to eq("read")
    end
  end

  describe "#build_params" do
    let(:model) { described_class.new(model_id: model_id, api_key: api_key, temperature: 0.5, max_tokens: 2000) }
    let(:messages) { [Smolagents::ChatMessage.user("Test")] }

    it "includes model and messages" do
      params = model.send(:build_params, messages, nil, nil, nil, nil)

      expect(params[:model]).to eq(model_id)
      expect(params[:messages]).to be_an(Array)
    end

    it "uses default temperature and max_tokens" do
      params = model.send(:build_params, messages, nil, nil, nil, nil)

      expect(params[:temperature]).to eq(0.5)
      expect(params[:max_tokens]).to eq(2000)
    end

    it "overrides temperature and max_tokens when provided" do
      params = model.send(:build_params, messages, nil, 0.9, 8000, nil)

      expect(params[:temperature]).to eq(0.9)
      expect(params[:max_tokens]).to eq(8000)
    end

    it "includes stop_sequences when provided" do
      params = model.send(:build_params, messages, ["STOP"], nil, nil, nil)

      expect(params[:stop_sequences]).to eq(["STOP"])
    end

    it "omits nil values from params" do
      params = model.send(:build_params, messages, nil, nil, nil, nil)

      expect(params).not_to be_key(:stop_sequences)
    end

    it "includes system message when present" do
      messages_with_system = [
        Smolagents::ChatMessage.system("Context"),
        Smolagents::ChatMessage.user("Test")
      ]

      params = model.send(:build_params, messages_with_system, nil, nil, nil, nil)

      expect(params[:system]).to eq("Context")
    end

    it "formats tools when provided" do
      search_tool = Class.new(Smolagents::Tool) do
        self.tool_name = "search"
        self.description = "Search"
        self.inputs = { query: { type: "string", description: "Search query" } }
        self.output_type = "string"
      end.new

      params = model.send(:build_params, messages, nil, nil, nil, [search_tool])

      expect(params[:tools]).to be_an(Array)
      expect(params[:tools][0][:name]).to eq("search")
    end
  end

  describe "#parse_response" do
    let(:model) { described_class.new(model_id: model_id, api_key: api_key) }

    it "parses text response" do
      response = {
        "id" => "msg_123",
        "content" => [{ "type" => "text", "text" => "Hello!" }],
        "usage" => { "input_tokens" => 5, "output_tokens" => 3 }
      }

      parsed = model.send(:parse_response, response)

      expect(parsed).to be_a(Smolagents::ChatMessage)
      expect(parsed.role).to eq(:assistant)
      expect(parsed.content).to eq("Hello!")
      expect(parsed.token_usage.input_tokens).to eq(5)
      expect(parsed.token_usage.output_tokens).to eq(3)
    end

    it "concatenates multiple text blocks" do
      response = {
        "content" => [
          { "type" => "text", "text" => "Hello " },
          { "type" => "text", "text" => "world" }
        ],
        "usage" => { "input_tokens" => 5, "output_tokens" => 3 }
      }

      parsed = model.send(:parse_response, response)

      expect(parsed.content).to eq("Hello \nworld")
    end

    it "parses tool calls" do
      response = {
        "content" => [
          { "type" => "text", "text" => "I'll search for that" },
          { "type" => "tool_use", "id" => "tool_123", "name" => "search", "input" => { "query" => "ruby" } }
        ],
        "usage" => { "input_tokens" => 5, "output_tokens" => 10 }
      }

      parsed = model.send(:parse_response, response)

      expect(parsed.tool_calls).to be_an(Array)
      expect(parsed.tool_calls.size).to eq(1)
      expect(parsed.tool_calls[0].id).to eq("tool_123")
      expect(parsed.tool_calls[0].name).to eq("search")
      expect(parsed.tool_calls[0].arguments).to eq({ "query" => "ruby" })
    end

    it "includes raw response" do
      response = {
        "id" => "msg_123",
        "content" => [{ "type" => "text", "text" => "Hi" }],
        "usage" => { "input_tokens" => 1, "output_tokens" => 1 }
      }

      parsed = model.send(:parse_response, response)

      expect(parsed.raw).to eq(response)
    end

    it "raises AgentGenerationError when response contains error" do
      response = {
        "error" => { "message" => "Invalid API key" }
      }

      expect do
        model.send(:parse_response, response)
      end.to raise_error(Smolagents::AgentGenerationError, /Invalid API key/)
    end

    it "handles empty content array" do
      response = {
        "content" => [],
        "usage" => { "input_tokens" => 5, "output_tokens" => 0 }
      }

      parsed = model.send(:parse_response, response)

      expect(parsed.content).to eq("")
      expect(parsed.tool_calls).to be_nil
    end

    it "handles missing usage info" do
      response = {
        "content" => [{ "type" => "text", "text" => "Hello" }]
      }

      parsed = model.send(:parse_response, response)

      expect(parsed.token_usage).to be_nil
    end
  end

  describe "#image_block" do
    let(:model) { described_class.new(model_id: model_id, api_key: api_key) }

    it "formats URL images" do
      image_url = "https://example.com/image.jpg"
      block = model.send(:image_block, image_url)

      expect(block[:type]).to eq("image")
      expect(block[:source][:type]).to eq("url")
      expect(block[:source][:url]).to eq(image_url)
    end

    it "formats HTTP URL images" do
      image_url = "http://example.com/image.png"
      block = model.send(:image_block, image_url)

      expect(block[:type]).to eq("image")
      expect(block[:source][:type]).to eq("url")
      expect(block[:source][:url]).to eq(image_url)
    end

    it "formats base64 images" do
      file_path = "image.jpg"
      file_content = "fake image data"

      allow(File).to receive(:binread).with(file_path).and_return(file_content)
      allow(File).to receive(:extname).with(file_path).and_return(".jpg")

      block = model.send(:image_block, file_path)

      expect(block[:type]).to eq("image")
      expect(block[:source][:type]).to eq("base64")
      expect(block[:source][:media_type]).to eq("image/jpeg")
      expect(block[:source][:data]).to be_a(String)
    end

    it "uses correct MIME type for PNG" do
      file_path = "image.png"
      allow(File).to receive_messages(binread: "fake", extname: ".png")

      block = model.send(:image_block, file_path)

      expect(block[:source][:media_type]).to eq("image/png")
    end

    it "uses correct MIME type for GIF" do
      file_path = "image.gif"
      allow(File).to receive_messages(binread: "fake", extname: ".gif")

      block = model.send(:image_block, file_path)

      expect(block[:source][:media_type]).to eq("image/gif")
    end

    it "uses correct MIME type for WebP" do
      file_path = "image.webp"
      allow(File).to receive_messages(binread: "fake", extname: ".webp")

      block = model.send(:image_block, file_path)

      expect(block[:source][:media_type]).to eq("image/webp")
    end

    it "defaults to image/png for unknown extensions" do
      file_path = "image.xyz"
      allow(File).to receive_messages(binread: "fake", extname: ".xyz")

      block = model.send(:image_block, file_path)

      expect(block[:source][:media_type]).to eq("image/png")
    end
  end

  describe "#build_content_with_images" do
    let(:model) { described_class.new(model_id: model_id, api_key: api_key) }

    it "includes text and image blocks" do
      message = Smolagents::ChatMessage.user("What's in this image?", images: ["https://example.com/image.jpg"])
      content = model.send(:build_content_with_images, message)

      expect(content.size).to eq(2)
      expect(content[0][:type]).to eq("text")
      expect(content[0][:text]).to eq("What's in this image?")
      expect(content[1][:type]).to eq("image")
    end

    it "handles multiple images" do
      message = Smolagents::ChatMessage.user("Compare these", images: ["image1.jpg", "image2.jpg"])

      allow(File).to receive_messages(binread: "fake", extname: ".jpg")

      content = model.send(:build_content_with_images, message)

      expect(content.size).to eq(3)
      expect(content[0][:type]).to eq("text")
      expect(content[1][:type]).to eq("image")
      expect(content[2][:type]).to eq("image")
    end

    it "handles empty message text" do
      message = Smolagents::ChatMessage.user("", images: ["https://example.com/image.jpg"])
      content = model.send(:build_content_with_images, message)

      expect(content[0][:text]).to eq("")
      expect(content[1][:type]).to eq("image")
    end

    it "handles nil message text" do
      message = Smolagents::ChatMessage.user(nil, images: ["https://example.com/image.jpg"])
      content = model.send(:build_content_with_images, message)

      expect(content[0][:text]).to eq("")
      expect(content[1][:type]).to eq("image")
    end
  end

  describe "response_format parameter" do
    let(:model) { described_class.new(model_id: model_id, api_key: api_key) }
    let(:messages) { [Smolagents::ChatMessage.user("Hello")] }

    let(:mock_response) do
      {
        "id" => "msg_123",
        "content" => [{ "type" => "text", "text" => "Response" }],
        "usage" => { "input_tokens" => 10, "output_tokens" => 5 }
      }
    end

    before do
      allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(mock_response)
    end

    it "emits warning when response_format is provided" do
      expect_any_instance_of(Object).to receive(:warn).with(/response_format parameter is not supported/)

      model.generate(messages, response_format: { type: "json_object" })
    end

    it "continues processing despite response_format" do
      expect_any_instance_of(Object).to receive(:warn)
      response = model.generate(messages, response_format: { type: "json_object" })

      expect(response.content).to eq("Response")
    end
  end

  describe "temperature validation" do
    let(:model) { described_class.new(model_id: model_id, api_key: api_key) }
    let(:messages) { [Smolagents::ChatMessage.user("Hello")] }

    let(:mock_response) do
      {
        "id" => "msg_123",
        "content" => [{ "type" => "text", "text" => "Response" }],
        "usage" => { "input_tokens" => 10, "output_tokens" => 5 }
      }
    end

    before do
      allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(mock_response)
    end

    it "accepts temperature 0.0" do
      response = model.generate(messages, temperature: 0.0)
      expect(response.content).to eq("Response")
    end

    it "accepts temperature 1.0" do
      response = model.generate(messages, temperature: 1.0)
      expect(response.content).to eq("Response")
    end

    it "accepts temperature 0.5" do
      response = model.generate(messages, temperature: 0.5)
      expect(response.content).to eq("Response")
    end
  end

  describe "default max_tokens" do
    it "sets DEFAULT_MAX_TOKENS to 4096" do
      expect(described_class::DEFAULT_MAX_TOKENS).to eq(4096)
    end

    it "uses default max_tokens when not specified" do
      model = described_class.new(model_id: model_id, api_key: api_key)
      mock_response = {
        "id" => "msg_123",
        "content" => [{ "type" => "text", "text" => "Response" }],
        "usage" => { "input_tokens" => 10, "output_tokens" => 5 }
      }

      allow_any_instance_of(Anthropic::Client).to receive(:messages) do |_, parameters:|
        expect(parameters[:max_tokens]).to eq(4096)
        mock_response
      end

      model.generate([Smolagents::ChatMessage.user("Hello")])
    end

    it "allows custom max_tokens in constructor" do
      model = described_class.new(model_id: model_id, api_key: api_key, max_tokens: 8192)
      mock_response = {
        "id" => "msg_123",
        "content" => [{ "type" => "text", "text" => "Response" }],
        "usage" => { "input_tokens" => 10, "output_tokens" => 5 }
      }

      allow_any_instance_of(Anthropic::Client).to receive(:messages) do |_, parameters:|
        expect(parameters[:max_tokens]).to eq(8192)
        mock_response
      end

      model.generate([Smolagents::ChatMessage.user("Hello")])
    end
  end

  describe "edge cases" do
    let(:model) { described_class.new(model_id: model_id, api_key: api_key) }

    it "handles very long content in response" do
      long_text = "a" * 10_000
      response = {
        "id" => "msg_123",
        "content" => [{ "type" => "text", "text" => long_text }],
        "usage" => { "input_tokens" => 1000, "output_tokens" => 1000 }
      }

      parsed = model.send(:parse_response, response)

      expect(parsed.content.length).to eq(10_000)
      expect(parsed.content).to eq(long_text)
    end

    it "handles response with no usage info gracefully" do
      response = {
        "id" => "msg_123",
        "content" => [{ "type" => "text", "text" => "Response" }]
      }

      parsed = model.send(:parse_response, response)

      expect(parsed.token_usage).to be_nil
      expect(parsed.content).to eq("Response")
    end

    it "handles tool call with empty input" do
      response = {
        "content" => [
          { "type" => "tool_use", "id" => "t1", "name" => "tool", "input" => {} }
        ],
        "usage" => { "input_tokens" => 5, "output_tokens" => 5 }
      }

      parsed = model.send(:parse_response, response)

      expect(parsed.tool_calls[0].arguments).to eq({})
    end

    it "handles tool call without input field" do
      response = {
        "content" => [
          { "type" => "tool_use", "id" => "t1", "name" => "tool" }
        ],
        "usage" => { "input_tokens" => 5, "output_tokens" => 5 }
      }

      parsed = model.send(:parse_response, response)

      expect(parsed.tool_calls[0].arguments).to eq({})
    end
  end
end
