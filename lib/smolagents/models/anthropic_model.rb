# frozen_string_literal: true

require "anthropic"  # ruby-anthropic gem, but require 'anthropic'

module Smolagents
  # Anthropic Claude model implementation using the anthropic gem.
  # Supports Claude 3 Opus, Sonnet, and Haiku.
  #
  # @example Basic usage
  #   model = AnthropicModel.new(model_id: "claude-3-5-sonnet-20241022")
  #   response = model.generate([
  #     ChatMessage.user("What is 2+2?")
  #   ])
  #
  # @example With tools
  #   model = AnthropicModel.new(model_id: "claude-3-5-sonnet-20241022")
  #   response = model.generate(
  #     messages,
  #     tools_to_call_from: [search_tool, calculator_tool]
  #   )
  #
  # @example With system prompt
  #   model = AnthropicModel.new(model_id: "claude-3-5-sonnet-20241022")
  #   response = model.generate([
  #     ChatMessage.system("You are a helpful assistant"),
  #     ChatMessage.user("Hello!")
  #   ])
  class AnthropicModel < Model
    include Concerns::MessageFormatting
    include Concerns::Retryable

    # Default max tokens for Claude models
    DEFAULT_MAX_TOKENS = 4096

    # Initialize Anthropic model.
    #
    # @param model_id [String] model identifier (e.g., "claude-3-5-sonnet-20241022")
    # @param api_key [String, nil] Anthropic API key (defaults to ENV['ANTHROPIC_API_KEY'])
    # @param temperature [Float] sampling temperature (0.0-1.0)
    # @param max_tokens [Integer] maximum tokens to generate
    # @param kwargs [Hash] additional configuration
    def initialize(
      model_id:,
      api_key: nil,
      temperature: 0.7,
      max_tokens: DEFAULT_MAX_TOKENS,
      **kwargs
    )
      super(model_id: model_id, **kwargs)

      @api_key = api_key || ENV["ANTHROPIC_API_KEY"]
      @temperature = temperature
      @max_tokens = max_tokens

      # Build Anthropic client
      @client = Anthropic::Client.new(access_token: @api_key)
    end

    # Generate a response.
    #
    # @param messages [Array<ChatMessage>] conversation messages
    # @param stop_sequences [Array<String>, nil] stop sequences
    # @param temperature [Float, nil] override default temperature
    # @param max_tokens [Integer, nil] override default max tokens
    # @param tools_to_call_from [Array<Tool>, nil] available tools
    # @param kwargs [Hash] additional parameters
    # @return [ChatMessage] model response
    def generate(
      messages,
      stop_sequences: nil,
      temperature: nil,
      max_tokens: nil,
      tools_to_call_from: nil,
      **kwargs
    )
      # Build parameters
      parameters = build_parameters(
        messages: messages,
        temperature: temperature,
        max_tokens: max_tokens,
        stop_sequences: stop_sequences,
        tools: tools_to_call_from,
        **kwargs
      )

      # Call API with retry
      response = with_retry(
        max_attempts: 3,
        base_delay: 1.0,
        on: [Faraday::Error, StandardError]
      ) do
        @client.messages(parameters: parameters)
      end

      # Parse response
      parse_anthropic_response(response)
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

      @client.messages(parameters: parameters) do |chunk|
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
    # @param stream [Boolean] enable streaming
    # @param kwargs [Hash] additional parameters
    # @return [Hash] API parameters
    def build_parameters(
      messages:,
      temperature: nil,
      max_tokens: nil,
      stop_sequences: nil,
      tools: nil,
      stream: false,
      **kwargs
    )
      # Extract system message if present
      system_message, user_messages = extract_system_message(messages)

      params = {
        model: @model_id,
        messages: format_messages_for_anthropic(user_messages),
        max_tokens: max_tokens || @max_tokens,
        temperature: temperature || @temperature
      }

      params[:system] = system_message if system_message
      params[:stop_sequences] = stop_sequences if stop_sequences
      params[:tools] = format_tools_for_anthropic(tools) if tools
      params[:stream] = stream if stream

      params.merge!(kwargs)
      params
    end

    # Extract system message from messages (Anthropic uses separate system parameter).
    #
    # @param messages [Array<ChatMessage>] all messages
    # @return [Array<String, Array<ChatMessage>>] system content and remaining messages
    def extract_system_message(messages)
      system_messages = messages.select { |m| m.role == :system || m.role == "system" }
      user_messages = messages.reject { |m| m.role == :system || m.role == "system" }

      system_content = if system_messages.any?
                         system_messages.map(&:content).join("\n\n")
                       end

      [system_content, user_messages]
    end

    # Format messages for Anthropic API.
    #
    # @param messages [Array<ChatMessage>] our messages
    # @return [Array<Hash>] Anthropic format
    def format_messages_for_anthropic(messages)
      messages.map do |msg|
        role = convert_role(msg.role)

        # Handle content with images (vision)
        if msg.images?
          content_parts = [{ type: "text", text: msg.content || "" }]

          msg.images.each do |image|
            content_parts << image_to_anthropic_block(image)
          end

          { role: role, content: content_parts }
        else
          { role: role, content: msg.content || "" }
        end
      end
    end

    # Convert an image to Anthropic's content block format.
    #
    # @param image [String] image path or URL
    # @return [Hash] Anthropic image content block
    def image_to_anthropic_block(image)
      if image.start_with?("http://", "https://")
        # For URLs, Anthropic requires base64 encoding (fetch and encode)
        # For simplicity, we'll use the URL source type if supported
        {
          type: "image",
          source: {
            type: "url",
            url: image
          }
        }
      else
        # File path - encode as base64
        data = File.binread(image)
        mime_type = detect_mime_type(image)
        base64_data = Base64.strict_encode64(data)
        {
          type: "image",
          source: {
            type: "base64",
            media_type: mime_type,
            data: base64_data
          }
        }
      end
    end

    # Detect MIME type from file extension.
    #
    # @param path [String] file path
    # @return [String] MIME type
    def detect_mime_type(path)
      case File.extname(path).downcase
      when ".jpg", ".jpeg" then "image/jpeg"
      when ".png" then "image/png"
      when ".gif" then "image/gif"
      when ".webp" then "image/webp"
      else "image/png"
      end
    end

    # Convert role to Anthropic format.
    #
    # @param role [Symbol, String] our role
    # @return [String] Anthropic role
    def convert_role(role)
      case role.to_sym
      when :assistant
        "assistant"
      when :user, :tool_response
        "user"
      else
        "user"
      end
    end

    # Format tools for Anthropic API.
    #
    # @param tools [Array<Tool>] our tools
    # @return [Array<Hash>] Anthropic tool format
    def format_tools_for_anthropic(tools)
      tools.map do |tool|
        {
          name: tool.name,
          description: tool.description,
          input_schema: {
            type: "object",
            properties: tool.inputs.transform_values { |spec|
              { type: spec["type"], description: spec["description"] }
            },
            required: tool.inputs.reject { |_, spec| spec["nullable"] }.keys
          }
        }
      end
    end

    # Parse Anthropic API response to ChatMessage.
    #
    # @param response [Hash] API response
    # @return [ChatMessage] parsed message
    def parse_anthropic_response(response)
      # Handle errors
      if response["error"]
        raise AgentGenerationError, "Anthropic error: #{response['error']['message']}"
      end

      content_blocks = response["content"] || []

      # Extract text content
      text_content = content_blocks
                     .select { |block| block["type"] == "text" }
                     .map { |block| block["text"] }
                     .join("\n")

      # Extract tool calls (Anthropic format: content blocks with type "tool_use")
      tool_calls = content_blocks
                   .select { |block| block["type"] == "tool_use" }
                   .map do |block|
        ToolCall.new(
          id: block["id"],
          name: block["name"],
          arguments: block["input"] || {}
        )
      end

      # Parse token usage
      usage_data = response["usage"]
      token_usage = if usage_data
                      TokenUsage.new(
                        input_tokens: usage_data["input_tokens"],
                        output_tokens: usage_data["output_tokens"]
                      )
                    end

      ChatMessage.assistant(
        text_content,
        tool_calls: tool_calls.any? ? tool_calls : nil,
        raw: response,
        token_usage: token_usage
      )
    end

    # Parse streaming chunk.
    #
    # @param chunk [Hash] stream event
    # @return [ChatMessage, nil] parsed delta
    def parse_stream_chunk(chunk)
      return nil unless chunk.is_a?(Hash)

      case chunk["type"]
      when "content_block_start"
        content_block = chunk.dig("content_block")
        if content_block && content_block["type"] == "text"
          ChatMessage.assistant(content_block["text"] || "", raw: chunk)
        end
      when "content_block_delta"
        delta = chunk["delta"]
        if delta && delta["type"] == "text_delta"
          ChatMessage.assistant(delta["text"], raw: chunk)
        end
      when "message_delta"
        # Handle usage updates
        usage = chunk.dig("usage")
        if usage
          token_usage = TokenUsage.new(
            input_tokens: 0,
            output_tokens: usage["output_tokens"] || 0
          )
          ChatMessage.assistant("", token_usage: token_usage, raw: chunk)
        end
      else
        nil
      end
    end
  end
end
