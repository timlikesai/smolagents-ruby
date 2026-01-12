module Smolagents
  class AnthropicModel < Model
    include Concerns::GemLoader
    include Concerns::Api
    include Concerns::ToolSchema
    include Concerns::MessageFormatting

    DEFAULT_MAX_TOKENS = 4096
    MIME_TYPES = { ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg", ".png" => "image/png", ".gif" => "image/gif", ".webp" => "image/webp" }.freeze

    def initialize(model_id:, api_key: nil, temperature: 0.7, max_tokens: DEFAULT_MAX_TOKENS, **)
      require_gem "anthropic", install_name: "ruby-anthropic", version: "~> 0.4", description: "ruby-anthropic gem required for Anthropic models"
      super(model_id: model_id, **)
      @api_key = api_key || ENV.fetch("ANTHROPIC_API_KEY", nil)
      @temperature = temperature
      @max_tokens = max_tokens
      @client = Anthropic::Client.new(access_token: @api_key)
    end

    def generate(messages, stop_sequences: nil, temperature: nil, max_tokens: nil, tools_to_call_from: nil, response_format: nil, **)
      Instrumentation.instrument("smolagents.model.generate", model_id: @model_id, model_class: self.class.name) do
        warn "[AnthropicModel] response_format parameter is not supported by Anthropic API" if response_format
        params = build_params(messages, stop_sequences, temperature, max_tokens, tools_to_call_from)
        response = api_call(service: "anthropic", operation: "messages", retryable_errors: [Faraday::Error, Anthropic::Error]) do
          @client.messages(parameters: params)
        end
        parse_response(response)
      end
    end

    def generate_stream(messages, **)
      return enum_for(:generate_stream, messages, **) unless block_given?

      system_content, user_messages = extract_system_message(messages)
      params = { model: @model_id, messages: format_messages(user_messages), max_tokens: @max_tokens, temperature: @temperature, stream: true }
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
        model: @model_id,
        messages: format_messages(user_messages),
        max_tokens: max_tokens || @max_tokens,
        temperature: temperature || @temperature,
        system: system_content,
        stop_sequences: stop_sequences,
        tools: tools && format_tools(tools)
      }.compact
    end

    def extract_system_message(messages)
      system_msgs, user_msgs = messages.partition { |m| m.role.to_sym == :system }
      [system_msgs.any? ? system_msgs.map(&:content).join("\n\n") : nil, user_msgs]
    end

    def parse_response(response)
      raise AgentGenerationError, "Anthropic error: #{response["error"]["message"]}" if response["error"]

      blocks = response["content"] || []
      text = blocks.filter_map { |b| b["text"] if b["type"] == "text" }.join("\n")
      tool_calls = blocks.filter_map { |b| ToolCall.new(id: b["id"], name: b["name"], arguments: b["input"] || {}) if b["type"] == "tool_use" }
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
