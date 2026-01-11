# frozen_string_literal: true

require "retriable"

module Smolagents
  # Anthropic Claude model implementation using the anthropic gem.
  class AnthropicModel < Model
    include Concerns::MessageFormatting
    include Concerns::Auditable

    DEFAULT_MAX_TOKENS = 4096

    def initialize(model_id:, api_key: nil, temperature: 0.7, max_tokens: DEFAULT_MAX_TOKENS, **)
      begin
        require "anthropic"
      rescue LoadError
        raise LoadError, "ruby-anthropic gem required for Anthropic models. Add `gem 'ruby-anthropic', '~> 0.4'` to your Gemfile."
      end

      super(model_id: model_id, **)
      @api_key = api_key || ENV.fetch("ANTHROPIC_API_KEY", nil)
      @temperature = temperature
      @max_tokens = max_tokens
      @client = Anthropic::Client.new(access_token: @api_key)
    end

    def generate(messages, stop_sequences: nil, temperature: nil, max_tokens: nil, tools_to_call_from: nil, **)
      Instrumentation.instrument("smolagents.model.generate", model_id: @model_id, model_class: self.class.name) do
        system_content, user_messages = extract_system_message(messages)
        params = { model: @model_id, messages: format_messages_for_api(user_messages), max_tokens: max_tokens || @max_tokens, temperature: temperature || @temperature }
        params[:system] = system_content if system_content
        params[:stop_sequences] = stop_sequences if stop_sequences
        params[:tools] = format_tools_for_api(tools_to_call_from) if tools_to_call_from

        response = with_audit_log(service: "anthropic", operation: "messages") do
          Retriable.retriable(tries: 3, base_interval: 1.0, max_interval: 30.0, on: [Faraday::Error, Anthropic::Error]) do
            @client.messages(parameters: params)
          end
        end
        parse_response(response)
      end
    end

    def generate_stream(messages, **)
      return enum_for(:generate_stream, messages, **) unless block_given?

      system_content, user_messages = extract_system_message(messages)
      params = { model: @model_id, messages: format_messages_for_api(user_messages), max_tokens: @max_tokens, temperature: @temperature, stream: true }
      params[:system] = system_content if system_content
      @client.messages(parameters: params) do |chunk|
        next unless chunk.is_a?(Hash) && chunk["type"] == "content_block_delta" && (d = chunk["delta"])&.[]("type") == "text_delta"

        yield ChatMessage.assistant(d["text"], raw: chunk)
      end
    end

    MIME_TYPES = { ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg", ".png" => "image/png", ".gif" => "image/gif", ".webp" => "image/webp" }.freeze

    private

    def extract_system_message(messages)
      system_msgs, user_msgs = messages.partition { |m| m.role.to_sym == :system }
      [system_msgs.any? ? system_msgs.map(&:content).join("\n\n") : nil, user_msgs]
    end

    def parse_response(response)
      raise AgentGenerationError, "Anthropic error: #{response["error"]["message"]}" if response["error"]

      blocks = response["content"] || []
      text = blocks.select { |b| b["type"] == "text" }.map { |b| b["text"] }.join("\n")
      tool_calls = blocks.select { |b| b["type"] == "tool_use" }.map { |b| ToolCall.new(id: b["id"], name: b["name"], arguments: b["input"] || {}) }
      usage = response["usage"]
      token_usage = usage && TokenUsage.new(input_tokens: usage["input_tokens"], output_tokens: usage["output_tokens"])
      ChatMessage.assistant(text, tool_calls: tool_calls.any? ? tool_calls : nil, raw: response, token_usage: token_usage)
    end

    def format_tools_for_api(tools)
      tools.map do |t|
        properties = t.inputs.transform_values { |s| { type: s["type"], description: s["description"] } }
        required = t.inputs.reject { |_, s| s["nullable"] }.keys
        { name: t.name, description: t.description, input_schema: { type: "object", properties: properties, required: required } }
      end
    end

    def format_messages_for_api(messages)
      messages.map do |msg|
        role = msg.role.to_sym == :assistant ? "assistant" : "user"
        content = msg.images? ? [{ type: "text", text: msg.content || "" }] + msg.images.map { |img| image_block(img) } : (msg.content || "")
        { role: role, content: content }
      end
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
