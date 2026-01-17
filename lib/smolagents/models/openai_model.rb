require_relative "openai/cloud_providers"
require_relative "openai/local_servers"
require_relative "openai/request_builder"
require_relative "openai/response_parser"
require_relative "openai/message_formatter"

module Smolagents
  module Models
    # Model implementation for OpenAI and OpenAI-compatible APIs.
    #
    # OpenAIModel is the most versatile model adapter, supporting:
    # - Cloud OpenAI (GPT-4, GPT-4 Turbo, o1, etc.)
    # - Cloud providers via OpenAI-compatible APIs (OpenRouter, Together, Groq, Fireworks, DeepInfra)
    # - Azure OpenAI Service
    # - Local servers (LM Studio, Ollama, llama.cpp, vLLM, MLX-LM)
    #
    # The adapter handles message formatting, tool/function calling, streaming,
    # and token usage tracking across all compatible backends.
    #
    # @example Local model with LM Studio (recommended for development)
    #   model = OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0")
    #   response = model.generate([ChatMessage.user("Hello!")])
    #   response.content  # => "Hello! How can I help you today?"
    #
    # @example Cloud OpenAI with API key
    #   model = OpenAIModel.new(
    #     model_id: "gpt-4-turbo",
    #     api_key: ENV["OPENAI_API_KEY"],
    #     temperature: 0.7
    #   )
    #
    # @example OpenRouter (100+ models via one API)
    #   model = OpenAIModel.openrouter("anthropic/claude-3.5-sonnet")
    #
    # @example Ollama local model
    #   model = OpenAIModel.ollama("llama3:latest")
    #
    # @example Custom local server
    #   model = OpenAIModel.new(
    #     model_id: "my-model",
    #     api_base: "http://localhost:8000/v1",
    #     api_key: "not-needed"
    #   )
    #
    # @example With tool calling
    #   tools = [MySearchTool.new, MyCalculatorTool.new]
    #   response = model.generate(messages, tools_to_call_from: tools)
    #   response.tool_calls.each do |call|
    #     result = tools.find { |t| t.name == call.name }&.call(**call.arguments)
    #   end
    #
    # @see Model Base class documentation
    # @see OpenAI::LocalServers Factory methods for local servers
    # @see OpenAI::CloudProviders Factory methods for cloud providers
    class OpenAIModel < Model
      include Concerns::GemLoader
      include Concerns::Api
      include Concerns::ToolSchema
      include OpenAI::CloudProviders
      include OpenAI::LocalServers
      include OpenAI::RequestBuilder
      include OpenAI::ResponseParser
      include OpenAI::MessageFormatter

      # Creates a new OpenAI model instance.
      #
      # Supports two initialization patterns:
      # 1. Config-based: Pass a ModelConfig object via the config: parameter
      # 2. Keyword-based: Pass individual parameters (model_id:, api_key:, etc.)
      #
      # For local servers or cloud providers, prefer the factory methods like
      # {.lm_studio}, {.ollama}, {.openrouter} for simpler configuration.
      #
      # @param model_id [String] Model identifier (e.g., "gpt-4-turbo", "gemma-3n-e4b-it-q8_0")
      # @param config [Types::ModelConfig, nil] Unified configuration object
      # @param api_key [String, nil] API key for authentication. Falls back to OPENAI_API_KEY
      #   environment variable if not provided. Use "not-needed" for local servers.
      # @param api_base [String, nil] Base URL for the API endpoint. Use for custom servers
      #   or providers. Examples: "http://localhost:1234/v1", "https://api.openai.com/v1"
      # @param temperature [Float] Sampling temperature controlling randomness (0.0-2.0).
      #   Lower values are more deterministic. Default: 0.7
      # @param max_tokens [Integer, nil] Maximum tokens in the response. If nil, uses
      #   provider default. Recommended to set for local models to prevent runaway generation.
      # @param azure_api_version [String, nil] Azure OpenAI API version for Azure deployments.
      #   Example: "2024-02-15-preview"
      # @param client [OpenAI::Client, nil] Pre-configured ruby-openai client for dependency
      #   injection in tests or advanced configuration.
      # @param kwargs [Hash] Additional options passed to parent Model class
      # @option kwargs [Integer] :timeout Request timeout in seconds
      #
      # @raise [Smolagents::GemLoadError] When ruby-openai gem is not installed
      #
      # @example Config-based initialization
      #   config = ModelConfig.create(model_id: "gpt-4", api_key: "sk-...")
      #   model = OpenAIModel.new(config:)
      #
      # @example Direct instantiation with OpenAI
      #   model = OpenAIModel.new(
      #     model_id: "gpt-4-turbo",
      #     api_key: ENV["OPENAI_API_KEY"],
      #     temperature: 0.5,
      #     max_tokens: 4096
      #   )
      #
      # @example With custom local server
      #   model = OpenAIModel.new(
      #     model_id: "my-local-model",
      #     api_base: "http://localhost:8080/v1",
      #     api_key: "not-needed",
      #     max_tokens: 2048
      #   )
      #
      # @see Types::ModelConfig
      # @see .lm_studio Factory method for LM Studio
      # @see .ollama Factory method for Ollama
      # @see .openrouter Factory method for OpenRouter
      def initialize(model_id: nil, config: nil, api_key: nil, api_base: nil, temperature: 0.7,
                     max_tokens: nil, azure_api_version: nil, client: nil, **kwargs)
        require_gem "openai", install_name: "ruby-openai", version: "~> 7.0",
                              description: "ruby-openai gem required for OpenAI models"
        super(model_id:, config:, api_key:, api_base:, temperature:, max_tokens:, **kwargs)
        @api_key ||= ENV.fetch("OPENAI_API_KEY", nil)
        @azure_api_version = config&.azure_api_version || azure_api_version
        timeout = config&.timeout || kwargs[:timeout]
        @client = client || build_client(@api_base, timeout)
      end

      # Generates a response from the OpenAI API.
      #
      # Makes a chat completion request to the configured OpenAI-compatible endpoint.
      # Handles tool/function calling, structured output, and token usage tracking.
      #
      # @param messages [Array<ChatMessage>] The conversation history including system,
      #   user, assistant, and tool response messages
      # @param stop_sequences [Array<String>, nil] Sequences that should stop generation.
      #   Maps to OpenAI's `stop` parameter.
      # @param temperature [Float, nil] Override the default temperature for this request.
      #   Range: 0.0-2.0
      # @param max_tokens [Integer, nil] Override the default max_tokens for this request
      # @param tools_to_call_from [Array<Tool>, nil] Available tools for function calling.
      #   Converted to OpenAI function schema format automatically.
      # @param response_format [Hash, nil] Structured output format specification.
      #   Example: { type: "json_object" } for JSON mode.
      #
      # @return [ChatMessage] The assistant's response with:
      #   - content: The text response (may be nil if tool calls present)
      #   - tool_calls: Array of ToolCall objects if the model requested tools
      #   - token_usage: TokenUsage with input/output token counts
      #   - raw: The original API response hash
      #
      # @raise [AgentGenerationError] When the API returns an error
      # @raise [Faraday::Error] When a network error occurs
      #
      # @example Basic generation
      #   response = model.generate([ChatMessage.user("Hello!")])
      #   puts response.content
      #
      # @example With tools
      #   tools = [SearchTool.new]
      #   response = model.generate(messages, tools_to_call_from: tools)
      #   if response.tool_calls.any?
      #     call = response.tool_calls.first
      #     puts "Model wants to call: #{call.name}"
      #   end
      #
      # @example With JSON mode
      #   response = model.generate(messages, response_format: { type: "json_object" })
      #   data = JSON.parse(response.content)
      #
      # @see Model#generate Base class definition
      def generate(messages, stop_sequences: nil, temperature: nil, max_tokens: nil,
                   tools_to_call_from: nil, response_format: nil, **)
        Smolagents::Instrumentation.instrument("smolagents.model.generate", model_id:, model_class: self.class.name) do
          params = build_params(messages:, stop_sequences:, temperature:, max_tokens:,
                                tools: tools_to_call_from, response_format:)
          response = api_call(service: "openai", operation: "chat_completion",
                              retryable_errors: [Faraday::Error, ::OpenAI::Error]) do
            @client.chat(parameters: params)
          end
          parse_response(response)
        end
      end

      # Generates a streaming response from the OpenAI API.
      #
      # Opens a streaming connection and yields ChatMessage chunks as they arrive.
      # Useful for real-time display and reducing perceived latency.
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
      #     print chunk.content  # Print tokens as they arrive
      #   end
      #
      # @example Collecting all chunks
      #   full_response = model.generate_stream(messages)
      #     .map(&:content)
      #     .compact
      #     .join
      #
      # @see Model#generate_stream Base class definition
      # @see #generate For non-streaming generation
      def generate_stream(messages, **, &block)
        return enum_for(:generate_stream, messages, **) unless block

        params = { model: model_id, messages: format_messages(messages), temperature: @temperature, stream: true }
        with_circuit_breaker("openai_api") do
          @client.chat(parameters: params) { |chunk, _| yield_stream_chunk(chunk, &block) }
        end
      end

      private

      def yield_stream_chunk(chunk)
        delta = chunk.dig("choices", 0, "delta")
        return unless delta

        yield Smolagents::ChatMessage.assistant(delta["content"], tool_calls: delta["tool_calls"], raw: chunk)
      rescue StandardError
        nil
      end
    end
  end
end
