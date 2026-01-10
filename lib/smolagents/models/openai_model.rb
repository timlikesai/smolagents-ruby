# frozen_string_literal: true

require "openai"

module Smolagents
  # OpenAI model implementation using the ruby-openai gem.
  class OpenAIModel < Model
    include Concerns::MessageFormatting
    include Concerns::Retryable

    LOCAL_SERVERS = { lm_studio: 1234, vllm: 8000, llama_cpp: 8080, ollama: 11_434, text_generation_webui: 5000 }.freeze

    LOCAL_SERVERS.each do |name, default_port|
      define_singleton_method(name) { |model_id, host: "localhost", port: default_port, **kwargs| new(model_id: model_id, api_base: "http://#{host}:#{port}/v1", api_key: "not-needed", **kwargs) }
    end

    def initialize(model_id:, api_key: nil, api_base: nil, temperature: 0.7, max_tokens: nil, **kwargs)
      super(model_id: model_id, **kwargs)
      @api_key = api_key || ENV.fetch("OPENAI_API_KEY", nil)
      @temperature = temperature
      @max_tokens = max_tokens
      @client = OpenAI::Client.new(**{ access_token: @api_key }.tap { |p| p[:uri_base] = api_base if api_base; p[:request_timeout] = kwargs[:timeout] if kwargs[:timeout] })
    end

    def generate(messages, stop_sequences: nil, temperature: nil, max_tokens: nil, tools_to_call_from: nil, response_format: nil, **)
      params = { model: @model_id, messages: format_messages_for_api(messages), temperature: temperature || @temperature }
      params[:max_tokens] = max_tokens || @max_tokens if max_tokens || @max_tokens
      params[:stop] = stop_sequences if stop_sequences
      params[:tools] = format_tools_for_api(tools_to_call_from) if tools_to_call_from
      params[:response_format] = response_format if response_format

      response = with_retry(max_attempts: 3, base_delay: 1.0, on: [Faraday::Error, OpenAI::Error]) { @client.chat(parameters: params) }
      parse_response(response)
    end

    def generate_stream(messages, **)
      return enum_for(:generate_stream, messages, **) unless block_given?
      params = { model: @model_id, messages: format_messages_for_api(messages), temperature: @temperature, stream: true }
      @client.chat(parameters: params) { |chunk, _| (delta = chunk.dig("choices", 0, "delta")) && (yield ChatMessage.assistant(delta["content"], tool_calls: delta["tool_calls"], raw: chunk)) rescue nil }
    end

    private

    def parse_response(response)
      raise AgentGenerationError, "OpenAI error: #{response["error"]["message"]}" if response["error"]
      message = response.dig("choices", 0, "message") or return ChatMessage.assistant("")
      usage = response["usage"]
      token_usage = usage && TokenUsage.new(input_tokens: usage["prompt_tokens"], output_tokens: usage["completion_tokens"])
      tool_calls = message["tool_calls"]&.map { |tc| ToolCall.new(id: tc["id"], name: tc.dig("function", "name"), arguments: (args = tc.dig("function", "arguments")).is_a?(Hash) ? args : (JSON.parse(args) rescue {})) }
      ChatMessage.assistant(message["content"], tool_calls: tool_calls, raw: response, token_usage: token_usage)
    end

    def format_tools_for_api(tools)
      tools.map do |tool|
        { type: "function", function: { name: tool.name, description: tool.description, parameters: {
          type: "object", properties: tool.inputs.transform_values { |s| { type: json_type(s["type"]), description: s["description"] }.tap { |p| p[:enum] = s["enum"] if s["enum"] } },
          required: tool.inputs.reject { |_, s| s["nullable"] }.keys
        } } }
      end
    end

    JSON_TYPES = { "string" => "string", "image" => "string", "audio" => "string", "integer" => "integer", "number" => "number", "boolean" => "boolean", "array" => "array", "object" => "object" }.freeze
    def json_type(type) = JSON_TYPES[type] || "string"

    def format_messages_for_api(messages)
      messages.map do |msg|
        { role: msg.role.to_s }.tap do |formatted|
          formatted[:content] = msg.images? ? [{ type: "text", text: msg.content || "" }] + msg.images.map { |img| ChatMessage.image_to_content_block(img) } : msg.content
          formatted[:tool_calls] = msg.tool_calls.map { |tc| { id: tc.id, type: "function", function: { name: tc.name, arguments: tc.arguments.is_a?(String) ? tc.arguments : tc.arguments.to_json } } } if msg.tool_calls&.any?
        end
      end
    end
  end
end
