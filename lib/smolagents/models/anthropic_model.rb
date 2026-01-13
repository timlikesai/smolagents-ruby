module Smolagents
  # Model implementation for Anthropic's Claude API.
  #
  # AnthropicModel provides integration with Anthropic's Claude models,
  # supporting chat completion, tool calling, and vision capabilities.
  #
  # Features:
  # - Full chat completion with tool/function calling
  # - Streaming responses via {#generate_stream}
  # - Vision support for Claude 3+ models (images via URL or base64)
  # - Automatic retry with circuit breaker protection
  # - System message extraction (Anthropic uses separate system param)
  #
  # @example Basic usage
  #   model = AnthropicModel.new(
  #     model_id: "claude-opus-4-5-20251101",
  #     api_key: ENV["ANTHROPIC_API_KEY"]
  #   )
  #   response = model.generate([ChatMessage.user("Hello!")])
  #
  # @example With vision (Claude 4.5)
  #   message = ChatMessage.user("What's in this image?", images: ["photo.jpg"])
  #   response = model.generate([message])
  #
  # @example With ModelBuilder DSL
  #   model = Smolagents.model(:anthropic)
  #     .id("claude-sonnet-4-5-20251101")
  #     .api_key(ENV["ANTHROPIC_API_KEY"])
  #     .temperature(0.5)
  #     .max_tokens(8192)
  #     .build
  #
  # @note Anthropic requires max_tokens to be specified (default: 4096)
  # @note response_format parameter is not supported by Anthropic API
  #
  # @see Model Base class documentation
  # @see OpenAIModel For OpenAI-compatible APIs
  class AnthropicModel < Model
    include Concerns::GemLoader
    include Concerns::Api
    include Concerns::ToolSchema
    include Concerns::MessageFormatting

    # @return [Integer] Default maximum tokens for responses
    DEFAULT_MAX_TOKENS = 4096

    # @return [Hash{String => String}] File extension to MIME type mapping for images
    MIME_TYPES = { ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg", ".png" => "image/png", ".gif" => "image/gif", ".webp" => "image/webp" }.freeze

    # Creates a new Anthropic model instance.
    #
    # @param model_id [String] The Claude model identifier (e.g., "claude-opus-4-5-20251101")
    # @param api_key [String, nil] API key (defaults to ANTHROPIC_API_KEY env var)
    # @param temperature [Float] Sampling temperature (0.0-1.0, default: 0.7)
    # @param max_tokens [Integer] Maximum tokens in response (default: 4096)
    # @raise [Smolagents::GemLoadError] When ruby-anthropic gem is not installed
    def initialize(model_id:, api_key: nil, temperature: 0.7, max_tokens: DEFAULT_MAX_TOKENS, **)
      require_gem "anthropic", install_name: "ruby-anthropic", version: "~> 0.4", description: "ruby-anthropic gem required for Anthropic models"
      super(model_id: model_id, **)
      @api_key = api_key || ENV.fetch("ANTHROPIC_API_KEY", nil)
      @temperature = temperature
      @max_tokens = max_tokens
      @client = Anthropic::Client.new(access_token: @api_key)
    end

    # Generates a response from the Anthropic API.
    #
    # @param messages [Array<ChatMessage>] The conversation history
    # @param stop_sequences [Array<String>, nil] Sequences that stop generation
    # @param temperature [Float, nil] Override default temperature for this call
    # @param max_tokens [Integer, nil] Override default max_tokens for this call
    # @param tools_to_call_from [Array<Tool>, nil] Available tools for function calling
    # @param response_format [Hash, nil] Not supported - will emit warning if provided
    # @return [ChatMessage] The assistant's response with optional tool_calls
    # @raise [AgentGenerationError] When the API returns an error
    def generate(messages, stop_sequences: nil, temperature: nil, max_tokens: nil, tools_to_call_from: nil, response_format: nil, **)
      Instrumentation.instrument("smolagents.model.generate", model_id: model_id, model_class: self.class.name) do
        warn "[AnthropicModel] response_format parameter is not supported by Anthropic API" if response_format
        params = build_params(messages, stop_sequences, temperature, max_tokens, tools_to_call_from)
        response = api_call(service: "anthropic", operation: "messages", retryable_errors: [Faraday::Error, Anthropic::Error]) do
          @client.messages(parameters: params)
        end
        parse_response(response)
      end
    end

    # Generates a streaming response from the Anthropic API.
    #
    # Yields ChatMessage chunks as they arrive from the API. Each chunk
    # contains partial content from the assistant's response.
    #
    # @param messages [Array<ChatMessage>] The conversation history
    # @param kwargs [Hash] Additional options (ignored for streaming)
    # @yield [ChatMessage] Each chunk of the streaming response
    # @return [Enumerator<ChatMessage>] When no block given
    def generate_stream(messages, **)
      return enum_for(:generate_stream, messages, **) unless block_given?

      system_content, user_messages = extract_system_message(messages)
      params = { model: model_id, messages: format_messages(user_messages), max_tokens: @max_tokens, temperature: @temperature, stream: true }
      params[:system] = system_content if system_content
      with_circuit_breaker("anthropic_api") do
        @client.messages(parameters: params) do |chunk|
          next unless chunk.is_a?(Hash) && chunk["type"] == "content_block_delta"

          delta = chunk["delta"]
          yield ChatMessage.assistant(delta["text"], raw: chunk) if delta&.[]("type") == "text_delta"
        end
      end
    end

    private

    def build_params(messages, stop_sequences, temperature, max_tokens, tools)
      system_content, user_messages = extract_system_message(messages)
      {
        model: model_id,
        messages: format_messages(user_messages),
        max_tokens: max_tokens || @max_tokens,
        temperature: temperature || @temperature,
        system: system_content,
        stop_sequences: stop_sequences,
        tools: tools && format_tools(tools)
      }.compact
    end

    def extract_system_message(messages)
      system_msgs, user_msgs = messages.partition { |msg| msg.role.to_sym == :system }
      [system_msgs.any? ? system_msgs.map(&:content).join("\n\n") : nil, user_msgs]
    end

    def parse_response(response)
      error = response["error"]
      raise AgentGenerationError, "Anthropic error: #{error["message"]}" if error

      blocks = response["content"] || []
      text = blocks.filter_map { |block| block["text"] if block["type"] == "text" }.join("\n")
      tool_calls = blocks.filter_map { |block| ToolCall.new(id: block["id"], name: block["name"], arguments: block["input"] || {}) if block["type"] == "tool_use" }
      usage = response["usage"]
      token_usage = usage && TokenUsage.new(input_tokens: usage["input_tokens"], output_tokens: usage["output_tokens"])
      ChatMessage.assistant(text, tool_calls: tool_calls.any? ? tool_calls : nil, raw: response, token_usage: token_usage)
    end

    def format_tools(tools)
      tools.map do |tool|
        {
          name: tool.name,
          description: tool.description,
          input_schema: {
            type: "object",
            properties: tool_properties(tool),
            required: tool_required_fields(tool)
          }
        }
      end
    end

    def format_messages(messages)
      messages.map do |msg|
        {
          role: msg.role.to_sym == :assistant ? "assistant" : "user",
          content: msg.images? ? build_content_with_images(msg) : (msg.content || "")
        }
      end
    end

    def build_content_with_images(msg)
      [{ type: "text", text: msg.content || "" }] + msg.images.map { |img| image_block(img) }
    end

    def image_block(image)
      if image.start_with?("http://", "https://")
        { type: "image", source: { type: "url", url: image } }
      else
        { type: "image", source: { type: "base64", media_type: MIME_TYPES[File.extname(image).downcase] || "image/png", data: Base64.strict_encode64(File.binread(image)) } }
      end
    end
  end
end
