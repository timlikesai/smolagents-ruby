module Smolagents
  module Models
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
      #
      # Used by factory methods to automatically configure the correct API endpoint.
      # Each server type has a conventional default port that can be overridden.
      #
      # @return [Hash{Symbol => Integer}] Server name to default port mapping:
      #   - :lm_studio => 1234
      #   - :ollama => 11434
      #   - :llama_cpp => 8080
      #   - :mlx_lm => 8080
      #   - :vllm => 8000
      #   - :text_generation_webui => 5000
      LOCAL_SERVERS = {
        lm_studio: 1234,
        ollama: 11_434,
        llama_cpp: 8080,
        mlx_lm: 8080,
        vllm: 8000,
        text_generation_webui: 5000
      }.freeze

      # @!method self.lm_studio(model_id, host: "localhost", port: 1234, **kwargs)
      #   Creates a model configured for LM Studio inference server.
      #
      #   LM Studio is recommended for local model serving with good performance
      #   and easy model management. It provides an OpenAI-compatible API endpoint.
      #
      #   @param model_id [String] The model identifier as loaded in LM Studio
      #     (e.g., "gemma-3n-e4b-it-q8_0", "gpt-oss-120b-mxfp4")
      #   @param host [String] Server hostname (default: "localhost")
      #   @param port [Integer] Server port (default: 1234)
      #   @param kwargs [Hash] Additional options passed to initializer
      #   @return [OpenAIModel] Configured model instance ready for generation
      #
      #   @example
      #     model = OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0")
      #     response = model.generate([ChatMessage.user("Hello")])

      # @!method self.ollama(model_id, host: "localhost", port: 11434, **kwargs)
      #   Creates a model configured for Ollama local inference.
      #
      #   Ollama provides a lightweight inference server with model management.
      #   Supports pull, run, and service operations on multiple models.
      #
      #   @param model_id [String] The model name as installed in Ollama
      #     (e.g., "nemotron-3-nano-30b-a3b-iq4_nl", "llama2")
      #   @param host [String] Server hostname (default: "localhost")
      #   @param port [Integer] Server port (default: 11434)
      #   @param kwargs [Hash] Additional options passed to initializer
      #   @return [OpenAIModel] Configured model instance
      #
      #   @example
      #     model = OpenAIModel.ollama("nemotron-3-nano-30b-a3b-iq4_nl")

      # @!method self.llama_cpp(model_id, host: "localhost", port: 8080, **kwargs)
      #   Creates a model configured for llama.cpp server.
      #
      #   llama.cpp is a lightweight C++ inference engine optimized for performance
      #   on consumer hardware. Supports various quantization formats (Q4, Q5, Q8).
      #
      #   @param model_id [String] The model identifier (e.g., "gpt-oss-20b-mxfp4")
      #   @param host [String] Server hostname (default: "localhost")
      #   @param port [Integer] Server port (default: 8080)
      #   @param kwargs [Hash] Additional options passed to initializer
      #   @return [OpenAIModel] Configured model instance
      #
      #   @example
      #     model = OpenAIModel.llama_cpp("gpt-oss-20b-mxfp4")

      # @!method self.vllm(model_id, host: "localhost", port: 8000, **kwargs)
      #   Creates a model configured for vLLM inference server.
      #
      #   vLLM is a high-throughput inference server from UC Berkeley optimized
      #   for large-scale language model serving with features like paged attention.
      #
      #   @param model_id [String] The model identifier (e.g., "meta-llama/Llama-2-70b")
      #   @param host [String] Server hostname (default: "localhost")
      #   @param port [Integer] Server port (default: 8000)
      #   @param kwargs [Hash] Additional options passed to initializer
      #   @return [OpenAIModel] Configured model instance
      #
      #   @example
      #     model = OpenAIModel.vllm("meta-llama/Llama-2-70b")

      LOCAL_SERVERS.each do |name, default_port|
        define_singleton_method(name) do |model_id, host: "localhost", port: default_port, **kwargs|
          new(model_id:, api_base: "http://#{host}:#{port}/v1", api_key: "not-needed", **kwargs)
        end
      end

      # Creates a new OpenAI model instance.
      #
      # Initializes an OpenAI-compatible model adapter that handles API communication,
      # message formatting, and response parsing. Supports both cloud OpenAI API and
      # OpenAI-compatible local inference servers (LM Studio, Ollama, llama.cpp, vLLM).
      #
      # The API key is optional for local servers but required for cloud OpenAI API.
      # Automatically loads the ruby-openai gem if not already loaded.
      #
      # @param model_id [String] The model identifier:
      #   - OpenAI cloud: "gpt-4-turbo", "gpt-4o", "gpt-3.5-turbo"
      #   - Local models: "gemma-3n-e4b-it-q8_0", "gpt-oss-20b-mxfp4", etc.
      # @param api_key [String, nil] OpenAI API key (defaults to OPENAI_API_KEY env var,
      #   can be dummy value "not-needed" for local servers)
      # @param api_base [String, nil] Base URL for API endpoint (e.g.,
      #   "http://localhost:1234/v1", "https://api.openai.com/v1")
      # @param temperature [Float] Sampling temperature between 0.0 and 2.0
      #   (default: 0.7). Higher values produce more creative/diverse output.
      # @param max_tokens [Integer, nil] Maximum tokens in response (default: nil = unlimited)
      # @param azure_api_version [String, nil] When set, enables Azure OpenAI mode with
      #   specified API version (e.g., "2024-02-15-preview")
      # @param kwargs [Hash] Additional options:
      #   - timeout [Integer] Request timeout in seconds
      #   - Other options passed to parent initializer
      #
      # @raise [Smolagents::GemLoadError] When ruby-openai gem is not installed.
      #   Install with: `gem install ruby-openai`
      #
      # @example Cloud OpenAI API
      #   model = OpenAIModel.new(
      #     model_id: "gpt-4-turbo",
      #     api_key: ENV["OPENAI_API_KEY"]
      #   )
      #
      # @example Local LM Studio server
      #   model = OpenAIModel.new(
      #     model_id: "gemma-3n-e4b-it-q8_0",
      #     api_base: "http://localhost:1234/v1",
      #     api_key: "not-needed"
      #   )
      #
      # @example Using factory method (recommended)
      #   model = OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0")
      #
      # @example Azure OpenAI
      #   model = OpenAIModel.new(
      #     model_id: "gpt-4",
      #     api_key: ENV["AZURE_OPENAI_API_KEY"],
      #     api_base: "https://myresource.openai.azure.com",
      #     azure_api_version: "2024-02-15-preview"
      #   )
      #
      # @see #generate For generating responses
      # @see #generate_stream For streaming responses
      # @see Model#initialize Parent class initialization
      def initialize(model_id:, api_key: nil, api_base: nil, temperature: 0.7, max_tokens: nil, azure_api_version: nil, **kwargs)
        require_gem "openai", install_name: "ruby-openai", version: "~> 7.0", description: "ruby-openai gem required for OpenAI models"
        super(model_id:, **kwargs)
        @api_key = api_key || ENV.fetch("OPENAI_API_KEY", nil)
        @temperature = temperature
        @max_tokens = max_tokens
        @azure_api_version = azure_api_version
        @client = build_client(api_base, kwargs[:timeout])
      end

      # Generates a response from the OpenAI API.
      #
      # Sends a chat completion request to the OpenAI API (or compatible server)
      # with the provided messages and options. Handles message formatting, tool
      # definition, and response parsing with automatic error handling and retry.
      #
      # The response includes the assistant's message, any tool calls requested,
      # and token usage metrics for billing/monitoring.
      #
      # @param messages [Array<ChatMessage>] The conversation history to send to the API
      # @param stop_sequences [Array<String>, nil] Sequence(s) that will stop generation
      #   (e.g., ["<|user|>", "<|end|>"] for prompt-template compliance)
      # @param temperature [Float, nil] Override default temperature for this call.
      #   Use nil to use instance default.
      # @param max_tokens [Integer, nil] Override max_tokens for this call.
      #   Use nil to use instance default.
      # @param tools_to_call_from [Array<Tool>, nil] Tools available for function calling.
      #   Model can request to call these tools via tool_calls in response.
      # @param response_format [Hash, nil] Structured output format specification:
      #   - { type: "json_object" } - Forces JSON output (for gpt-4-turbo and above)
      #   - Other provider-specific formats
      # @param kwargs [Hash] Additional options (ignored, for compatibility)
      #
      # @return [ChatMessage] The assistant's response message, potentially including:
      #   - content [String] The text response
      #   - tool_calls [Array<ToolCall>] Requested function calls (if any)
      #   - token_usage [TokenUsage] Input/output token counts
      #   - raw [Hash] Raw API response for debugging
      #
      # @raise [AgentGenerationError] When API returns an error (invalid key, rate limit, etc.)
      # @raise [Faraday::Error] When network error occurs (no retry available)
      #
      # @example Basic text generation
      #   messages = [ChatMessage.user("What is 2+2?")]
      #   response = model.generate(messages)
      #   puts response.content  # "2 + 2 = 4"
      #
      # @example Function calling
      #   tools = [CalculatorTool.new, WeatherTool.new]
      #   messages = [ChatMessage.user("What's the weather and what is 15*23?")]
      #   response = model.generate(messages, tools_to_call_from: tools)
      #   response.tool_calls&.each do |call|
      #     puts "Tool: #{call.name}, Args: #{call.arguments}"
      #   end
      #
      # @example Structured output (JSON mode)
      #   messages = [
      #     ChatMessage.system("Extract as JSON: {name, age}"),
      #     ChatMessage.user("I'm Bob, 42 years old")
      #   ]
      #   response = model.generate(
      #     messages,
      #     response_format: { type: "json_object" }
      #   )
      #
      # @example With temperature override
      #   response = model.generate(messages, temperature: 0.2)  # More deterministic
      #
      # @see #generate_stream For streaming responses
      # @see Model#generate Base class definition
      # @see ChatMessage for message construction
      # @see Tool for tool/function calling
      def generate(messages, stop_sequences: nil, temperature: nil, max_tokens: nil, tools_to_call_from: nil, response_format: nil, **)
        Smolagents::Instrumentation.instrument("smolagents.model.generate", model_id:, model_class: self.class.name) do
          params = build_params(messages, stop_sequences, temperature, max_tokens, tools_to_call_from, response_format)
          response = api_call(service: "openai", operation: "chat_completion", retryable_errors: [Faraday::Error, OpenAI::Error]) do
            @client.chat(parameters: params)
          end
          parse_response(response)
        end
      end

      # Generates a streaming response from the OpenAI API.
      #
      # Establishes a server-sent events (SSE) connection and yields ChatMessage
      # chunks as they arrive from the server. Useful for real-time display and
      # reducing perceived latency.
      #
      # Each yielded chunk contains partial content that should be concatenated
      # to build the full response. The stream handles connection resilience via
      # circuit breaker protection.
      #
      # @param messages [Array<ChatMessage>] The conversation history
      # @param kwargs [Hash] Additional options (currently ignored for streaming)
      #
      # @yield [ChatMessage] Each streaming chunk as a partial assistant message
      #   with delta content field
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
      # @example Streaming with enumeration
      #   stream = model.generate_stream(messages)
      #   stream.each_with_index { |chunk, i| puts "[#{i}] #{chunk.content}" }
      #
      # @see #generate For non-streaming generation
      # @see Model#generate_stream Base class definition
      def generate_stream(messages, **)
        return enum_for(:generate_stream, messages, **) unless block_given?

        params = { model: model_id, messages: format_messages(messages), temperature: @temperature, stream: true }
        with_circuit_breaker("openai_api") do
          @client.chat(parameters: params) do |chunk, _|
            delta = chunk.dig("choices", 0, "delta")
            yield Smolagents::ChatMessage.assistant(delta["content"], tool_calls: delta["tool_calls"], raw: chunk) if delta
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
          response_format:
        }.compact
      end

      def parse_response(response)
        error = response["error"]
        raise Smolagents::AgentGenerationError, "OpenAI error: #{error["message"]}" if error

        message = response.dig("choices", 0, "message")
        return Smolagents::ChatMessage.assistant("") unless message

        usage = response["usage"]
        token_usage = usage && Smolagents::TokenUsage.new(input_tokens: usage["prompt_tokens"], output_tokens: usage["completion_tokens"])
        tool_calls = parse_tool_calls(message["tool_calls"])
        Smolagents::ChatMessage.assistant(message["content"], tool_calls:, raw: response, token_usage:)
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
          Smolagents::ToolCall.new(id: call["id"], name: call.dig("function", "name"), arguments: parsed_args)
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
            role: map_role(msg.role),
            content: msg.images? ? build_content_with_images(msg) : msg.content,
            tool_calls: msg.tool_calls&.any? ? format_message_tool_calls(msg.tool_calls) : nil
          }.compact
        end
      end

      # Maps internal message roles to OpenAI API roles.
      # - tool_response -> user (observations appear as user messages)
      # - tool_call -> assistant (tool calls are assistant messages)
      def map_role(role)
        case role.to_sym
        when :tool_response then "user"
        when :tool_call then "assistant"
        else role.to_s
        end
      end

      def build_content_with_images(msg)
        [{ type: "text", text: msg.content || "" }] + msg.images.map { |img| Smolagents::ChatMessage.image_to_content_block(img) }
      end

      def format_message_tool_calls(tool_calls)
        tool_calls.map do |call|
          { id: call.id, type: "function", function: { name: call.name, arguments: call.arguments.is_a?(String) ? call.arguments : call.arguments.to_json } }
        end
      end
    end
  end
end
