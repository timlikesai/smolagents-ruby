module Smolagents
  module Models
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

      # @return [Integer] Default maximum tokens for Anthropic responses (4096).
      #   Anthropic requires max_tokens to be explicitly set, unlike some other providers.
      #   Can be overridden per request in the generate method.
      DEFAULT_MAX_TOKENS = 4096

      # @return [Hash{String => String}] File extension to MIME type mapping for vision/image support.
      #   Used when processing image files for Claude's vision capabilities.
      #   Supported formats: .jpg, .jpeg, .png, .gif, .webp
      #   Example: {".jpg" => "image/jpeg", ".png" => "image/png", ...}
      MIME_TYPES = { ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg", ".png" => "image/png", ".gif" => "image/gif", ".webp" => "image/webp" }.freeze

      # Creates a new Anthropic model instance.
      #
      # Initializes a model adapter for Anthropic's Claude API with support for
      # the latest Claude models (Opus 4.5, Sonnet, Haiku). Automatically loads the
      # ruby-anthropic gem if not already loaded.
      #
      # Anthropic API differs from OpenAI in several ways:
      # - max_tokens is REQUIRED (default: 4096, no unlimited option)
      # - System messages are separated from user/assistant messages
      # - Vision support uses different content block format
      # - response_format is not supported
      # - stop_sequences is named directly (not stop)
      #
      # @param model_id [String] The Claude model identifier:
      #   - Latest: "claude-opus-4-5-20251101"
      #   - Sonnet: "claude-3-5-sonnet-20241022"
      #   - Haiku: "claude-3-5-haiku-20241022"
      # @param api_key [String, nil] Anthropic API key (defaults to ANTHROPIC_API_KEY env var).
      #   Get from https://console.anthropic.com
      # @param temperature [Float] Sampling temperature between 0.0 and 1.0
      #   (default: 0.7). Anthropic uses 0.0-1.0 range (more restrictive than OpenAI).
      # @param max_tokens [Integer] Maximum tokens in response (default: 4096).
      #   Anthropic requires this to be explicitly set (no unlimited option).
      # @param kwargs [Hash] Additional options passed to parent initializer
      #
      # @raise [Smolagents::GemLoadError] When ruby-anthropic gem is not installed.
      #   Install with: `gem install ruby-anthropic`
      # @raise [ArgumentError] When API key is not provided and ANTHROPIC_API_KEY not set
      #
      # @example Basic usage
      #   model = AnthropicModel.new(
      #     model_id: "claude-opus-4-5-20251101",
      #     api_key: ENV["ANTHROPIC_API_KEY"]
      #   )
      #
      # @example With custom max_tokens
      #   model = AnthropicModel.new(
      #     model_id: "claude-opus-4-5-20251101",
      #     api_key: ENV["ANTHROPIC_API_KEY"],
      #     max_tokens: 8192,
      #     temperature: 0.5
      #   )
      #
      # @example Using ModelBuilder DSL
      #   model = Smolagents.model(:anthropic)
      #     .id("claude-opus-4-5-20251101")
      #     .api_key(ENV["ANTHROPIC_API_KEY"])
      #     .temperature(0.7)
      #     .max_tokens(8192)
      #     .build
      #
      # @see #generate For generating responses
      # @see #generate_stream For streaming responses
      # @see Model#initialize Parent class initialization
      def initialize(model_id:, api_key: nil, temperature: 0.7, max_tokens: DEFAULT_MAX_TOKENS, **)
        require_gem "anthropic", install_name: "ruby-anthropic", version: "~> 0.4", description: "ruby-anthropic gem required for Anthropic models"
        super(model_id:, **)
        @api_key = api_key || ENV.fetch("ANTHROPIC_API_KEY", nil)
        @temperature = temperature
        @max_tokens = max_tokens
        @client = Anthropic::Client.new(access_token: @api_key)
      end

      # Generates a response from the Anthropic Claude API.
      #
      # Sends a messages request to Anthropic's API with conversation history
      # and optional tools. Handles message formatting (extracting system messages),
      # tool definition, and response parsing with automatic error handling and retry.
      #
      # The response includes the assistant's message, any tool calls requested,
      # and token usage metrics.
      #
      # Important differences from OpenAI:
      # - System messages are passed separately in the `system` parameter
      # - max_tokens is required (no unlimited option)
      # - response_format is not supported
      # - Tool use content blocks have different structure
      #
      # @param messages [Array<ChatMessage>] The conversation history.
      #   System messages are automatically extracted and passed separately.
      # @param stop_sequences [Array<String>, nil] Sequence(s) that will stop generation
      # @param temperature [Float, nil] Override default temperature for this call.
      #   Valid range: 0.0-1.0 (more restrictive than OpenAI's 0.0-2.0)
      # @param max_tokens [Integer, nil] Override max_tokens for this call
      #   (must be positive, no unlimited option)
      # @param tools_to_call_from [Array<Tool>, nil] Tools available for tool use.
      #   Model can request these tools via tool_calls in response.
      # @param response_format [Hash, nil] NOT SUPPORTED by Anthropic API.
      #   Will emit a warning if provided.
      # @param kwargs [Hash] Additional options (ignored, for compatibility)
      #
      # @return [ChatMessage] The assistant's response message, potentially including:
      #   - content [String] The text response
      #   - tool_calls [Array<ToolCall>] Requested tool uses (if any)
      #   - token_usage [TokenUsage] Input/output token counts
      #   - raw [Hash] Raw API response for debugging
      #
      # @raise [AgentGenerationError] When API returns an error (invalid key, rate limit, etc.)
      # @raise [Faraday::Error] When network error occurs (no retry available)
      # @raise [Anthropic::Error] When Anthropic-specific errors occur
      #
      # @example Basic text generation
      #   messages = [ChatMessage.user("What is the capital of France?")]
      #   response = model.generate(messages)
      #   puts response.content  # "The capital of France is Paris."
      #
      # @example Tool calling
      #   tools = [WeatherTool.new, LocationTool.new]
      #   messages = [ChatMessage.user("What's the weather in Tokyo?")]
      #   response = model.generate(messages, tools_to_call_from: tools)
      #   response.tool_calls&.each do |call|
      #     puts "Tool: #{call.name}, Input: #{call.arguments}"
      #   end
      #
      # @example With system message
      #   messages = [
      #     ChatMessage.system("You are a helpful assistant."),
      #     ChatMessage.user("Hello!")
      #   ]
      #   response = model.generate(messages)
      #   # System message is automatically extracted and passed separately
      #
      # @example Multi-turn conversation
      #   messages = [
      #     ChatMessage.user("What's 2+2?"),
      #     ChatMessage.assistant("2+2 equals 4"),
      #     ChatMessage.user("And 3+3?")
      #   ]
      #   response = model.generate(messages)
      #
      # @see #generate_stream For streaming responses
      # @see Model#generate Base class definition
      # @see ChatMessage for message construction
      # @see Tool for tool/function calling
      def generate(messages, stop_sequences: nil, temperature: nil, max_tokens: nil, tools_to_call_from: nil, response_format: nil, **)
        Smolagents::Instrumentation.instrument("smolagents.model.generate", model_id:, model_class: self.class.name) do
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
      # Establishes a server-sent events (SSE) connection and yields ChatMessage
      # chunks as they arrive from the server. Useful for real-time display and
      # reducing perceived latency of Anthropic API calls.
      #
      # Each yielded chunk contains partial text content that should be concatenated
      # to build the full response. The stream handles connection resilience via
      # circuit breaker protection.
      #
      # Note: System messages are automatically extracted and handled separately,
      # consistent with Anthropic's API requirements.
      #
      # @param messages [Array<ChatMessage>] The conversation history.
      #   System messages are automatically extracted and passed separately.
      # @param kwargs [Hash] Additional options (currently ignored for streaming)
      #
      # @yield [ChatMessage] Each streaming chunk as a partial assistant message
      #   with delta content field containing the streamed text
      #
      # @return [Enumerator<ChatMessage>] When no block given, returns an Enumerator
      #   for lazy evaluation and composition
      #
      # @example Streaming with real-time display
      #   model.generate_stream(messages) do |chunk|
      #     print chunk.content
      #   end
      #
      # @example Streaming with collection
      #   full_response = model.generate_stream(messages)
      #     .map(&:content)
      #     .join
      #
      # @example Streaming with progress indicator
      #   stream = model.generate_stream(messages)
      #   stream.each_with_index do |chunk, i|
      #     print "\r[#{i}] #{chunk.content}"
      #   end
      #
      # @see #generate For non-streaming generation
      # @see Model#generate_stream Base class definition
      def generate_stream(messages, **)
        return enum_for(:generate_stream, messages, **) unless block_given?

        system_content, user_messages = extract_system_message(messages)
        params = { model: model_id, messages: format_messages(user_messages), max_tokens: @max_tokens, temperature: @temperature, stream: true }
        params[:system] = system_content if system_content
        with_circuit_breaker("anthropic_api") do
          @client.messages(parameters: params) do |chunk|
            next unless chunk.is_a?(Hash) && chunk["type"] == "content_block_delta"

            delta = chunk["delta"]
            yield Smolagents::ChatMessage.assistant(delta["text"], raw: chunk) if delta&.[]("type") == "text_delta"
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
          stop_sequences:,
          tools: tools && format_tools(tools)
        }.compact
      end

      def extract_system_message(messages)
        system_msgs, user_msgs = messages.partition { |msg| msg.role.to_sym == :system }
        [system_msgs.any? ? system_msgs.map(&:content).join("\n\n") : nil, user_msgs]
      end

      def parse_response(response)
        error = response["error"]
        raise Smolagents::AgentGenerationError, "Anthropic error: #{error["message"]}" if error

        blocks = response["content"] || []
        text = blocks.filter_map { |block| block["text"] if block["type"] == "text" }.join("\n")
        tool_calls = blocks.filter_map { |block| Smolagents::ToolCall.new(id: block["id"], name: block["name"], arguments: block["input"] || {}) if block["type"] == "tool_use" }
        usage = response["usage"]
        token_usage = usage && Smolagents::TokenUsage.new(input_tokens: usage["input_tokens"], output_tokens: usage["output_tokens"])
        Smolagents::ChatMessage.assistant(text, tool_calls: tool_calls.any? ? tool_calls : nil, raw: response, token_usage:)
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
end
