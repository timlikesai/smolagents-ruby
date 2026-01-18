require_relative "anthropic/message_formatter"
require_relative "anthropic/request_builder"
require_relative "anthropic/response_parser"
require_relative "anthropic/streaming"

module Smolagents
  module Models
    # Model implementation for Anthropic's Claude API.
    #
    # AnthropicModel provides a native integration with Anthropic's Messages API,
    # supporting all Claude models including Claude 4.5 Opus, Sonnet, and Haiku.
    #
    # Key features:
    # - Chat completion with system/user/assistant messages
    # - Tool calling with Anthropic's native tool_use format
    # - Streaming responses for real-time output
    # - Vision support for image analysis
    # - Automatic system message extraction (Anthropic uses separate parameter)
    #
    # Note: Anthropic's API differs from OpenAI in several ways:
    # - max_tokens is required (default: 4096)
    # - System messages are passed as a separate parameter, not in messages
    # - response_format is not supported (emits warning if used)
    #
    # @example Basic usage with API key
    #   model = AnthropicModel.new(
    #     model_id: "claude-opus-4-5-20251101",
    #     api_key: ENV["ANTHROPIC_API_KEY"]
    #   )
    #   response = model.generate([ChatMessage.user("Hello!")])
    #   puts response.content
    #
    # @example With ModelBuilder DSL
    #   model = Smolagents.model(:anthropic)
    #     .id("claude-sonnet-4-5-20251101")
    #     .temperature(0.5)
    #     .max_tokens(8192)
    #     .build
    #
    # @example With tool calling
    #   tools = [SearchTool.new, CalculatorTool.new]
    #   response = model.generate(messages, tools_to_call_from: tools)
    #   if response.tool_calls.any?
    #     tool_call = response.tool_calls.first
    #     puts "Claude wants to use: #{tool_call.name}"
    #   end
    #
    # @example Streaming response
    #   model.generate_stream(messages) do |chunk|
    #     print chunk.content
    #   end
    #
    # @see Model Base class documentation
    # @see OpenAIModel For OpenAI-compatible APIs
    # @see LiteLLMModel For multi-provider routing
    class AnthropicModel < Model
      include Concerns::GemLoader
      include Concerns::Api
      include Concerns::ToolSchema
      include Concerns::MessageFormatting
      include Anthropic::MessageFormatter
      include Anthropic::RequestBuilder
      include Anthropic::ResponseParser
      include Anthropic::Streaming

      # @return [Integer] Default maximum tokens for responses. Anthropic requires
      #   max_tokens to be specified explicitly (unlike OpenAI which has model defaults).
      DEFAULT_MAX_TOKENS = 4096

      # Creates a new Anthropic Claude model instance.
      #
      # Supports two initialization patterns:
      # 1. Config-based: Pass a ModelConfig object via the config: parameter
      # 2. Keyword-based: Pass individual parameters (model_id:, api_key:, etc.)
      #
      # @param model_id [String] Claude model identifier. Available models:
      #   - "claude-opus-4-5-20251101" - Most capable, best for complex tasks
      #   - "claude-sonnet-4-5-20251101" - Balanced performance and speed
      #   - "claude-haiku-3-5-20241022" - Fastest, best for simple tasks
      # @param config [Types::ModelConfig, nil] Unified configuration object
      # @param api_key [String, nil] Anthropic API key. Falls back to ANTHROPIC_API_KEY
      #   environment variable if not provided.
      # @param api_base [String, nil] Custom API endpoint URL (not used by Anthropic, included for consistency)
      # @param temperature [Float] Sampling temperature controlling randomness (0.0-1.0).
      #   Anthropic recommends lower values than OpenAI. Default: 0.7
      # @param max_tokens [Integer] Maximum tokens in response. Required by Anthropic API.
      #   Default: 4096. Increase for longer responses.
      # @param client [Anthropic::Client, nil] Pre-configured ruby-anthropic client for
      #   dependency injection in tests or advanced configuration.
      # @param kwargs [Hash] Additional options passed to parent Model class
      #
      # @raise [Smolagents::GemLoadError] When ruby-anthropic gem is not installed
      #
      # @example Config-based initialization
      #   config = ModelConfig.create(model_id: "claude-sonnet-4-5-20251101", api_key: "sk-...")
      #   model = AnthropicModel.new(config:)
      #
      # @example Basic instantiation
      #   model = AnthropicModel.new(
      #     model_id: "claude-sonnet-4-5-20251101",
      #     api_key: ENV["ANTHROPIC_API_KEY"]
      #   )
      #
      # @example With custom settings
      #   model = AnthropicModel.new(
      #     model_id: "claude-opus-4-5-20251101",
      #     temperature: 0.3,     # More deterministic
      #     max_tokens: 8192      # Longer responses
      #   )
      #
      # @see Types::ModelConfig
      # @see Model#initialize Base class initialization
      def initialize(model_id: nil, config: nil, api_key: nil, api_base: nil,
                     temperature: 0.7, max_tokens: nil, client: nil, **)
        require_gem "anthropic", install_name: "ruby-anthropic", version: "~> 0.4",
                                 description: "ruby-anthropic gem required for Anthropic models"
        # Apply Anthropic-specific default for max_tokens
        effective_max_tokens = max_tokens || config&.max_tokens || DEFAULT_MAX_TOKENS
        super(model_id:, config:, api_key:, api_base:, temperature:, max_tokens: effective_max_tokens, **)
        @api_key ||= ENV.fetch("ANTHROPIC_API_KEY", nil)
        @client = client || ::Anthropic::Client.new(access_token: @api_key)
      end

      # Generates a response from the Anthropic Claude API.
      #
      # Makes a messages request to Claude. Handles the Anthropic-specific
      # formatting including system message extraction and tool_use blocks.
      #
      # @param messages [Array<ChatMessage>] The conversation history. System messages
      #   are automatically extracted and passed as a separate parameter per Anthropic's API.
      # @param stop_sequences [Array<String>, nil] Sequences that should stop generation.
      #   Anthropic calls these "stop_sequences".
      # @param temperature [Float, nil] Override the default temperature for this request.
      #   Range: 0.0-1.0 (Anthropic's range is tighter than OpenAI's)
      # @param max_tokens [Integer, nil] Override the default max_tokens for this request.
      #   Required by Anthropic API if not set at initialization.
      # @param tools_to_call_from [Array<Tool>, nil] Available tools for function calling.
      #   Converted to Anthropic's tool_use format automatically.
      # @param response_format [Hash, nil] Not supported by Anthropic API. If provided,
      #   a warning is emitted and the parameter is ignored.
      #
      # @return [ChatMessage] The assistant's response with:
      #   - content: The text response
      #   - tool_calls: Array of ToolCall objects if Claude requested tool_use
      #   - token_usage: TokenUsage with input/output token counts
      #   - raw: The original API response hash
      #
      # @raise [AgentGenerationError] When the API returns an error
      # @raise [Faraday::Error] When a network error occurs
      #
      # @example Basic generation
      #   response = model.generate([ChatMessage.user("Explain quantum computing")])
      #   puts response.content
      #
      # @example With system message
      #   messages = [
      #     ChatMessage.system("You are a helpful coding assistant."),
      #     ChatMessage.user("Write a Ruby method to reverse a string")
      #   ]
      #   response = model.generate(messages)
      #
      # @example With tools
      #   tools = [SearchTool.new, CalculatorTool.new]
      #   response = model.generate(messages, tools_to_call_from: tools)
      #   response.tool_calls.each do |call|
      #     puts "Tool: #{call.name}, Args: #{call.arguments}"
      #   end
      #
      # @see Model#generate Base class definition
      def generate(messages, stop_sequences: nil, temperature: nil, max_tokens: nil,
                   tools_to_call_from: nil, response_format: nil, **)
        Smolagents::Instrumentation.instrument("smolagents.model.generate", model_id:, model_class: self.class.name) do
          warn "[AnthropicModel] response_format is not supported by Anthropic API" if response_format
          params = build_params(messages, stop_sequences, temperature, max_tokens, tools_to_call_from)
          response = api_call(service: "anthropic", operation: "messages",
                              retryable_errors: [Faraday::Error, ::Anthropic::Error]) do
            @client.messages(parameters: params)
          end
          parse_response(response)
        end
      end

      # Generates a streaming response from the Anthropic Claude API.
      #
      # Opens a streaming connection and yields ChatMessage chunks as they arrive.
      # Uses Anthropic's server-sent events (SSE) streaming format.
      #
      # @param messages [Array<ChatMessage>] The conversation history
      # @param options [Hash] Additional options (temperature, max_tokens, etc.)
      #
      # @yield [ChatMessage] Each streaming chunk as a partial ChatMessage with
      #   content containing the delta text
      #
      # @return [Enumerator<ChatMessage>] When no block given, returns an Enumerator
      #   for lazy evaluation and chaining
      #
      # @example Streaming with a block
      #   model.generate_stream(messages) do |chunk|
      #     print chunk.content
      #   end
      #
      # @example Collecting the full response
      #   chunks = model.generate_stream(messages).to_a
      #   full_text = chunks.map(&:content).compact.join
      #
      # @see Model#generate_stream Base class definition
      # @see #generate For non-streaming generation
      def generate_stream(messages, **, &)
        return enum_for(:generate_stream, messages, **) unless block_given?

        params = build_stream_params(messages)
        with_circuit_breaker("anthropic_api") { stream_messages(params, &) }
      end
    end
  end
end
