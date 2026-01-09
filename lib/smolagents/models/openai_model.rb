# frozen_string_literal: true

require "openai"

module Smolagents
  # OpenAI model implementation using the ruby-openai gem.
  # Supports GPT-4, GPT-3.5, and other OpenAI models.
  #
  # @example Basic usage
  #   model = OpenAIModel.new(model_id: "gpt-4")
  #   response = model.generate([
  #     ChatMessage.user("What is 2+2?")
  #   ])
  #
  # @example With tools
  #   model = OpenAIModel.new(model_id: "gpt-4")
  #   response = model.generate(
  #     messages,
  #     tools_to_call_from: [search_tool, calculator_tool]
  #   )
  #
  # @example With custom endpoint
  #   model = OpenAIModel.new(
  #     model_id: "llama-3",
  #     api_base: "http://localhost:1234/v1"
  #   )
  class OpenAIModel < Model
    include Concerns::MessageFormatting
    include Concerns::Retryable

    # =============================================================================
    # Convenience Methods for Local Models
    # =============================================================================

    # Create a model for LM Studio (default port: 1234).
    #
    # @param model_id [String] model identifier
    # @param host [String] host (default: "localhost")
    # @param port [Integer] port (default: 1234)
    # @param kwargs [Hash] additional parameters
    # @return [OpenAIModel]
    #
    # @example
    #   model = OpenAIModel.lm_studio("local-model")
    #   model = OpenAIModel.lm_studio("local-model", host: "192.168.1.100")
    def self.lm_studio(model_id, host: "localhost", port: 1234, **kwargs)
      new(
        model_id: model_id,
        api_base: "http://#{host}:#{port}/v1",
        api_key: "not-needed",
        **kwargs
      )
    end

    # Create a model for vLLM (default port: 8000).
    #
    # @param model_id [String] model identifier
    # @param host [String] host (default: "localhost")
    # @param port [Integer] port (default: 8000)
    # @param kwargs [Hash] additional parameters
    # @return [OpenAIModel]
    #
    # @example
    #   model = OpenAIModel.vllm("meta-llama/Llama-3-8b")
    #   model = OpenAIModel.vllm("llama-3", host: "vllm-server.local")
    def self.vllm(model_id, host: "localhost", port: 8000, **kwargs)
      new(
        model_id: model_id,
        api_base: "http://#{host}:#{port}/v1",
        api_key: "not-needed",
        **kwargs
      )
    end

    # Create a model for llama.cpp server (default port: 8080).
    #
    # @param model_id [String] model identifier
    # @param host [String] host (default: "localhost")
    # @param port [Integer] port (default: 8080)
    # @param kwargs [Hash] additional parameters
    # @return [OpenAIModel]
    #
    # @example
    #   model = OpenAIModel.llama_cpp("llama-3")
    #   model = OpenAIModel.llama_cpp("llama-3", port: 8081)
    def self.llama_cpp(model_id, host: "localhost", port: 8080, **kwargs)
      new(
        model_id: model_id,
        api_base: "http://#{host}:#{port}/v1",
        api_key: "not-needed",
        **kwargs
      )
    end

    # Create a model for Ollama (default port: 11434).
    #
    # @param model_id [String] model identifier
    # @param host [String] host (default: "localhost")
    # @param port [Integer] port (default: 11434)
    # @param kwargs [Hash] additional parameters
    # @return [OpenAIModel]
    #
    # @example
    #   model = OpenAIModel.ollama("llama3")
    #   model = OpenAIModel.ollama("llama3", host: "ollama-server")
    def self.ollama(model_id, host: "localhost", port: 11434, **kwargs)
      new(
        model_id: model_id,
        api_base: "http://#{host}:#{port}/v1",
        api_key: "not-needed",
        **kwargs
      )
    end

    # Create a model for text-generation-webui (default port: 5000).
    #
    # @param model_id [String] model identifier
    # @param host [String] host (default: "localhost")
    # @param port [Integer] port (default: 5000)
    # @param kwargs [Hash] additional parameters
    # @return [OpenAIModel]
    #
    # @example
    #   model = OpenAIModel.text_generation_webui("local-model")
    def self.text_generation_webui(model_id, host: "localhost", port: 5000, **kwargs)
      new(
        model_id: model_id,
        api_base: "http://#{host}:#{port}/v1",
        api_key: "not-needed",
        **kwargs
      )
    end

    # Initialize OpenAI model.
    #
    # @param model_id [String] model identifier (e.g., "gpt-4", "gpt-3.5-turbo")
    # @param api_key [String, nil] OpenAI API key (defaults to ENV['OPENAI_API_KEY'])
    # @param api_base [String, nil] custom API base URL (for OpenAI-compatible APIs)
    # @param temperature [Float] sampling temperature (0.0-2.0)
    # @param max_tokens [Integer, nil] maximum tokens to generate
    # @param kwargs [Hash] additional configuration
    def initialize(
      model_id:,
      api_key: nil,
      api_base: nil,
      temperature: 0.7,
      max_tokens: nil,
      **kwargs
    )
      super(model_id: model_id, **kwargs)

      @api_key = api_key || ENV["OPENAI_API_KEY"]
      @temperature = temperature
      @max_tokens = max_tokens

      # Build OpenAI client
      client_params = { access_token: @api_key }
      client_params[:uri_base] = api_base if api_base
      client_params[:request_timeout] = kwargs[:timeout] if kwargs[:timeout]

      @client = OpenAI::Client.new(**client_params)
    end

    # Generate a response.
    #
    # @param messages [Array<ChatMessage>] conversation messages
    # @param stop_sequences [Array<String>, nil] stop sequences
    # @param temperature [Float, nil] override default temperature
    # @param max_tokens [Integer, nil] override default max tokens
    # @param tools_to_call_from [Array<Tool>, nil] available tools
    # @param response_format [Hash, nil] structured output format
    # @param kwargs [Hash] additional parameters
    # @return [ChatMessage] model response
    def generate(
      messages,
      stop_sequences: nil,
      temperature: nil,
      max_tokens: nil,
      tools_to_call_from: nil,
      response_format: nil,
      **kwargs
    )
      # Build parameters
      parameters = build_parameters(
        messages: messages,
        temperature: temperature,
        max_tokens: max_tokens,
        stop_sequences: stop_sequences,
        tools: tools_to_call_from,
        response_format: response_format,
        **kwargs
      )

      # Call API with retry
      response = with_retry(
        max_attempts: 3,
        base_delay: 1.0,
        on: [Faraday::Error, OpenAI::Error]
      ) do
        @client.chat(parameters: parameters)
      end

      # Parse response
      parse_openai_response(response)
    end

    # Stream responses.
    #
    # @param messages [Array<ChatMessage>] conversation messages
    # @param kwargs [Hash] generation parameters
    # @yield [delta] each response chunk
    # @yieldparam delta [ChatMessage] partial response
    # @return [Enumerator, nil]
    def generate_stream(messages, **kwargs)
      return enum_for(:generate_stream, messages, **kwargs) unless block_given?

      parameters = build_parameters(messages: messages, stream: true, **kwargs)

      @client.chat(parameters: parameters) do |chunk, _bytesize|
        delta = parse_stream_chunk(chunk)
        yield delta if delta
      end
    end

    private

    # Build API parameters.
    #
    # @param messages [Array<ChatMessage>] messages
    # @param temperature [Float, nil] temperature
    # @param max_tokens [Integer, nil] max tokens
    # @param stop_sequences [Array<String>, nil] stop sequences
    # @param tools [Array<Tool>, nil] tools
    # @param response_format [Hash, nil] response format
    # @param stream [Boolean] enable streaming
    # @param kwargs [Hash] additional parameters
    # @return [Hash] API parameters
    def build_parameters(
      messages:,
      temperature: nil,
      max_tokens: nil,
      stop_sequences: nil,
      tools: nil,
      response_format: nil,
      stream: false,
      **kwargs
    )
      params = {
        model: @model_id,
        messages: format_messages_for_api(messages),
        temperature: temperature || @temperature
      }

      params[:max_tokens] = max_tokens || @max_tokens if max_tokens || @max_tokens
      params[:stop] = stop_sequences if stop_sequences
      params[:tools] = format_tools_for_api(tools) if tools
      params[:response_format] = response_format if response_format
      params[:stream] = stream if stream

      params.merge!(kwargs)
      params
    end

    # Parse OpenAI API response to ChatMessage.
    #
    # @param response [Hash] API response
    # @return [ChatMessage] parsed message
    def parse_openai_response(response)
      # Handle errors
      if response["error"]
        raise AgentGenerationError, "OpenAI error: #{response['error']['message']}"
      end

      choice = response.dig("choices", 0)
      return ChatMessage.assistant("") unless choice

      message = choice["message"]
      content = message["content"]
      raw_tool_calls = message["tool_calls"]

      # Parse token usage
      usage_data = response["usage"]
      token_usage = if usage_data
                      TokenUsage.new(
                        input_tokens: usage_data["prompt_tokens"],
                        output_tokens: usage_data["completion_tokens"]
                      )
                    end

      # Parse tool calls
      tool_calls = if raw_tool_calls
                     raw_tool_calls.map do |tc|
                       ToolCall.new(
                         id: tc["id"],
                         name: tc.dig("function", "name"),
                         arguments: parse_json_safely(tc.dig("function", "arguments"))
                       )
                     end
                   end

      ChatMessage.assistant(
        content,
        tool_calls: tool_calls,
        raw: response,
        token_usage: token_usage
      )
    end

    # Parse streaming chunk.
    #
    # @param chunk [String] JSON chunk
    # @return [ChatMessage, nil] parsed delta
    def parse_stream_chunk(chunk)
      data = JSON.parse(chunk)
      delta = data.dig("choices", 0, "delta")
      return nil unless delta

      ChatMessage.assistant(
        delta["content"],
        tool_calls: delta["tool_calls"],
        raw: data
      )
    rescue JSON::ParserError
      nil
    end

    # Safely parse JSON arguments.
    #
    # @param json_string [String, Hash] JSON or parsed hash
    # @return [Hash] parsed arguments
    def parse_json_safely(json_string)
      return json_string if json_string.is_a?(Hash)
      return {} if json_string.nil? || json_string.empty?

      JSON.parse(json_string)
    rescue JSON::ParserError => e
      logger&.warn("Failed to parse tool arguments: #{e.message}")
      {}
    end

    # Format tools for OpenAI API function calling.
    #
    # @param tools [Array<Tool>] tools to format
    # @return [Array<Hash>] OpenAI function schema format
    def format_tools_for_api(tools)
      tools.map do |tool|
        {
          type: "function",
          function: {
            name: tool.name,
            description: tool.description,
            parameters: {
              type: "object",
              properties: tool.inputs.transform_values do |spec|
                {
                  type: map_type_to_json_schema(spec["type"]),
                  description: spec["description"]
                }.tap do |prop|
                  prop[:enum] = spec["enum"] if spec["enum"]
                end
              end,
              required: tool.inputs.reject { |_, spec| spec["nullable"] }.keys
            }
          }
        }
      end
    end

    # Map smolagents types to JSON Schema types.
    #
    # @param type [String] smolagents type
    # @return [String] JSON Schema type
    def map_type_to_json_schema(type)
      case type
      when "string", "image", "audio" then "string"
      when "integer" then "integer"
      when "number" then "number"
      when "boolean" then "boolean"
      when "array" then "array"
      when "object" then "object"
      else "string"
      end
    end

    # Format messages for OpenAI API.
    # Override from MessageFormatting concern.
    #
    # @param messages [Array<ChatMessage>] our messages
    # @return [Array<Hash>] OpenAI format
    def format_messages_for_api(messages)
      messages.map do |msg|
        formatted = { role: msg.role.to_s }

        # Handle content with images (vision)
        if msg.images?
          # Create multimodal content array
          content_parts = [{ type: "text", text: msg.content || "" }]

          msg.images.each do |image|
            content_parts << ChatMessage.image_to_content_block(image)
          end

          formatted[:content] = content_parts
        else
          formatted[:content] = msg.content
        end

        # Add tool calls if present
        if msg.tool_calls&.any?
          formatted[:tool_calls] = msg.tool_calls.map do |tc|
            {
              id: tc.id,
              type: "function",
              function: {
                name: tc.name,
                arguments: tc.arguments.is_a?(String) ? tc.arguments : tc.arguments.to_json
              }
            }
          end
        end

        formatted
      end
    end
  end
end
