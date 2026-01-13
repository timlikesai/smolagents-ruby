module Smolagents
  # Model implementation for OpenAI and OpenAI-compatible APIs.
  #
  # OpenAIModel provides integration with any API that follows the OpenAI
  # chat completion format. This includes local inference servers like
  # LM Studio, Ollama, llama.cpp, and vLLM, as well as cloud providers.
  #
  # Features:
  # - Full chat completion support with tool/function calling
  # - Streaming responses via {#generate_stream}
  # - Vision support for multimodal models
  # - Automatic retry with circuit breaker protection
  # - First-class local model support
  #
  # @example Local model with LM Studio (recommended)
  #   model = OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0")
  #   response = model.generate([ChatMessage.user("Hello!")])
  #
  # @example Local model with llama.cpp
  #   model = OpenAIModel.llama_cpp("gpt-oss-20b-mxfp4")
  #   # Equivalent to:
  #   model = OpenAIModel.new(
  #     model_id: "gpt-oss-20b-mxfp4",
  #     api_base: "http://localhost:8080/v1",
  #     api_key: "not-needed"
  #   )
  #
  # @example Large local model
  #   model = OpenAIModel.lm_studio("gpt-oss-120b-mxfp4")
  #
  # @example Nvidia Nemotron via ik_llama
  #   model = OpenAIModel.llama_cpp("nemotron-3-nano-30b-a3b-iq4_nl")
  #
  # @example With ModelBuilder DSL
  #   model = Smolagents.model(:lm_studio)
  #     .id("gemma-3n-e4b-it-q8_0")
  #     .temperature(0.7)
  #     .with_retry(max_attempts: 3)
  #     .build
  #
  # @see Model Base class documentation
  # @see LiteLLMModel For multi-provider routing
  class OpenAIModel < Model
    include Concerns::GemLoader
    include Concerns::Api
    include Concerns::ToolSchema
    include Concerns::MessageFormatting

    # Default ports for popular local inference servers.
    # @return [Hash{Symbol => Integer}] Server name to port mapping
    LOCAL_SERVERS = {
      lm_studio: 1234,
      ollama: 11_434,
      llama_cpp: 8080,
      mlx_lm: 8080,
      vllm: 8000,
      text_generation_webui: 5000
    }.freeze

    # @!method self.lm_studio(model_id, host: "localhost", port: 1234, **kwargs)
    #   Creates a model configured for LM Studio.
    #   @param model_id [String] The model identifier
    #   @param host [String] Server hostname (default: "localhost")
    #   @param port [Integer] Server port (default: 1234)
    #   @return [OpenAIModel] Configured model instance

    # @!method self.ollama(model_id, host: "localhost", port: 11434, **kwargs)
    #   Creates a model configured for Ollama.
    #   @param model_id [String] The model identifier
    #   @param host [String] Server hostname (default: "localhost")
    #   @param port [Integer] Server port (default: 11434)
    #   @return [OpenAIModel] Configured model instance

    # @!method self.llama_cpp(model_id, host: "localhost", port: 8080, **kwargs)
    #   Creates a model configured for llama.cpp server.
    #   @param model_id [String] The model identifier
    #   @param host [String] Server hostname (default: "localhost")
    #   @param port [Integer] Server port (default: 8080)
    #   @return [OpenAIModel] Configured model instance

    # @!method self.vllm(model_id, host: "localhost", port: 8000, **kwargs)
    #   Creates a model configured for vLLM server.
    #   @param model_id [String] The model identifier
    #   @param host [String] Server hostname (default: "localhost")
    #   @param port [Integer] Server port (default: 8000)
    #   @return [OpenAIModel] Configured model instance

    LOCAL_SERVERS.each do |name, default_port|
      define_singleton_method(name) do |model_id, host: "localhost", port: default_port, **kwargs|
        new(model_id: model_id, api_base: "http://#{host}:#{port}/v1", api_key: "not-needed", **kwargs)
      end
    end

    # Creates a new OpenAI model instance.
    #
    # @param model_id [String] The model identifier (e.g., "gemma-3n-e4b-it-q8_0", "gpt-oss-20b-mxfp4")
    # @param api_key [String, nil] API key (defaults to OPENAI_API_KEY env var)
    # @param api_base [String, nil] Base URL for API calls (for custom endpoints)
    # @param temperature [Float] Sampling temperature (0.0-2.0, default: 0.7)
    # @param max_tokens [Integer, nil] Maximum tokens in response
    # @param azure_api_version [String, nil] Azure API version (enables Azure mode)
    # @param kwargs [Hash] Additional options (e.g., timeout)
    # @raise [Smolagents::GemLoadError] When ruby-openai gem is not installed
    def initialize(model_id:, api_key: nil, api_base: nil, temperature: 0.7, max_tokens: nil, azure_api_version: nil, **kwargs)
      require_gem "openai", install_name: "ruby-openai", version: "~> 7.0", description: "ruby-openai gem required for OpenAI models"
      super(model_id: model_id, **kwargs)
      @api_key = api_key || ENV.fetch("OPENAI_API_KEY", nil)
      @temperature = temperature
      @max_tokens = max_tokens
      @azure_api_version = azure_api_version
      @client = build_client(api_base, kwargs[:timeout])
    end

    # Generates a response from the OpenAI API.
    #
    # @param messages [Array<ChatMessage>] The conversation history
    # @param stop_sequences [Array<String>, nil] Sequences that stop generation
    # @param temperature [Float, nil] Override default temperature for this call
    # @param max_tokens [Integer, nil] Override default max_tokens for this call
    # @param tools_to_call_from [Array<Tool>, nil] Available tools for function calling
    # @param response_format [Hash, nil] Structured output format (e.g., { type: "json_object" })
    # @return [ChatMessage] The assistant's response with optional tool_calls
    # @raise [AgentGenerationError] When the API returns an error
    def generate(messages, stop_sequences: nil, temperature: nil, max_tokens: nil, tools_to_call_from: nil, response_format: nil, **)
      Instrumentation.instrument("smolagents.model.generate", model_id: model_id, model_class: self.class.name) do
        params = build_params(messages, stop_sequences, temperature, max_tokens, tools_to_call_from, response_format)
        response = api_call(service: "openai", operation: "chat_completion", retryable_errors: [Faraday::Error, OpenAI::Error]) do
          @client.chat(parameters: params)
        end
        parse_response(response)
      end
    end

    # Generates a streaming response from the OpenAI API.
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

      params = { model: model_id, messages: format_messages(messages), temperature: @temperature, stream: true }
      with_circuit_breaker("openai_api") do
        @client.chat(parameters: params) do |chunk, _|
          delta = chunk.dig("choices", 0, "delta")
          yield ChatMessage.assistant(delta["content"], tool_calls: delta["tool_calls"], raw: chunk) if delta
        rescue StandardError
          nil
        end
      end
    end

    private

    def build_client(api_base, timeout)
      client_opts = {
        access_token: @api_key,
        uri_base: api_base,
        request_timeout: timeout
      }.compact

      if @azure_api_version
        client_opts[:extra_headers] = { "api-key" => @api_key }
        client_opts[:uri_base] = "#{api_base}?api-version=#{@azure_api_version}"
      end

      OpenAI::Client.new(**client_opts)
    end

    def build_params(messages, stop_sequences, temperature, max_tokens, tools, response_format)
      {
        model: model_id,
        messages: format_messages(messages),
        temperature: temperature || @temperature,
        max_tokens: max_tokens || @max_tokens,
        stop: stop_sequences,
        tools: tools && format_tools(tools),
        response_format: response_format
      }.compact
    end

    def parse_response(response)
      error = response["error"]
      raise AgentGenerationError, "OpenAI error: #{error["message"]}" if error

      message = response.dig("choices", 0, "message")
      return ChatMessage.assistant("") unless message

      usage = response["usage"]
      token_usage = usage && TokenUsage.new(input_tokens: usage["prompt_tokens"], output_tokens: usage["completion_tokens"])
      tool_calls = parse_tool_calls(message["tool_calls"])
      ChatMessage.assistant(message["content"], tool_calls: tool_calls, raw: response, token_usage: token_usage)
    end

    def parse_tool_calls(raw_calls)
      raw_calls&.map do |call|
        args = call.dig("function", "arguments")
        parsed_args = if args.is_a?(Hash)
                        args
                      else
                        begin
                          JSON.parse(args)
                        rescue StandardError
                          {}
                        end
                      end
        ToolCall.new(id: call["id"], name: call.dig("function", "name"), arguments: parsed_args)
      end
    end

    def format_tools(tools)
      tools.map do |tool|
        {
          type: "function",
          function: {
            name: tool.name,
            description: tool.description,
            parameters: {
              type: "object",
              properties: tool_properties(tool, type_mapper: ->(type) { json_schema_type(type) }),
              required: tool_required_fields(tool)
            }
          }
        }
      end
    end

    def format_messages(messages)
      messages.map do |msg|
        {
          role: msg.role.to_s,
          content: msg.images? ? build_content_with_images(msg) : msg.content,
          tool_calls: msg.tool_calls&.any? ? format_message_tool_calls(msg.tool_calls) : nil
        }.compact
      end
    end

    def build_content_with_images(msg)
      [{ type: "text", text: msg.content || "" }] + msg.images.map { |img| ChatMessage.image_to_content_block(img) }
    end

    def format_message_tool_calls(tool_calls)
      tool_calls.map do |call|
        { id: call.id, type: "function", function: { name: call.name, arguments: call.arguments.is_a?(String) ? call.arguments : call.arguments.to_json } }
      end
    end
  end
end
