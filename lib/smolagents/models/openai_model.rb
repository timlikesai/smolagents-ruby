# frozen_string_literal: true

module Smolagents
  class OpenAIModel < Model
    include Concerns::GemLoader
    include Concerns::Api
    include Concerns::ToolSchema
    include Concerns::MessageFormatting

    LOCAL_SERVERS = { lm_studio: 1234, vllm: 8000, llama_cpp: 8080, ollama: 11_434, text_generation_webui: 5000 }.freeze

    LOCAL_SERVERS.each do |name, default_port|
      define_singleton_method(name) do |model_id, host: "localhost", port: default_port, **kwargs|
        new(model_id: model_id, api_base: "http://#{host}:#{port}/v1", api_key: "not-needed", **kwargs)
      end
    end

    def initialize(model_id:, api_key: nil, api_base: nil, temperature: 0.7, max_tokens: nil, **kwargs)
      require_gem "openai", install_name: "ruby-openai", version: "~> 7.0", description: "ruby-openai gem required for OpenAI models"
      super(model_id: model_id, **kwargs)
      @api_key = api_key || ENV.fetch("OPENAI_API_KEY", nil)
      @temperature = temperature
      @max_tokens = max_tokens
      @client = OpenAI::Client.new(**{
        access_token: @api_key,
        uri_base: api_base,
        request_timeout: kwargs[:timeout]
      }.compact)
    end

    def generate(messages, stop_sequences: nil, temperature: nil, max_tokens: nil, tools_to_call_from: nil, response_format: nil, **)
      Instrumentation.instrument("smolagents.model.generate", model_id: @model_id, model_class: self.class.name) do
        params = build_params(messages, stop_sequences, temperature, max_tokens, tools_to_call_from, response_format)
        response = api_call(service: "openai", operation: "chat_completion", retryable_errors: [Faraday::Error, OpenAI::Error]) do
          @client.chat(parameters: params)
        end
        parse_response(response)
      end
    end

    def generate_stream(messages, **)
      return enum_for(:generate_stream, messages, **) unless block_given?

      params = { model: @model_id, messages: format_messages(messages), temperature: @temperature, stream: true }
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

    def build_params(messages, stop_sequences, temperature, max_tokens, tools, response_format)
      {
        model: @model_id,
        messages: format_messages(messages),
        temperature: temperature || @temperature,
        max_tokens: max_tokens || @max_tokens,
        stop: stop_sequences,
        tools: tools && format_tools(tools),
        response_format: response_format
      }.compact
    end

    def parse_response(response)
      raise AgentGenerationError, "OpenAI error: #{response["error"]["message"]}" if response["error"]

      message = response.dig("choices", 0, "message")
      return ChatMessage.assistant("") unless message

      usage = response["usage"]
      token_usage = usage && TokenUsage.new(input_tokens: usage["prompt_tokens"], output_tokens: usage["completion_tokens"])
      tool_calls = parse_tool_calls(message["tool_calls"])
      ChatMessage.assistant(message["content"], tool_calls: tool_calls, raw: response, token_usage: token_usage)
    end

    def parse_tool_calls(raw_calls)
      raw_calls&.map do |tc|
        args = tc.dig("function", "arguments")
        parsed_args = if args.is_a?(Hash)
                        args
                      else
                        begin
                          JSON.parse(args)
                        rescue StandardError
                          {}
                        end
                      end
        ToolCall.new(id: tc["id"], name: tc.dig("function", "name"), arguments: parsed_args)
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
              properties: tool_properties(tool, type_mapper: ->(t) { json_schema_type(t) }),
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
      tool_calls.map do |tc|
        { id: tc.id, type: "function", function: { name: tc.name, arguments: tc.arguments.is_a?(String) ? tc.arguments : tc.arguments.to_json } }
      end
    end
  end
end
