require_relative "../http/ractor_safe_client"

module Smolagents
  module Models
    # Ractor-safe model implementation for use inside child Ractors.
    #
    # This model uses a simple HTTP client instead of ruby-openai,
    # avoiding the global configuration that makes ruby-openai
    # incompatible with Ractors.
    #
    # @example Creating a Ractor-safe model
    #   model = RactorModel.new(
    #     model_id: "gpt-4",
    #     api_key: ENV["OPENAI_API_KEY"],
    #     api_base: "https://api.openai.com/v1"
    #   )
    class RactorModel
      attr_reader :model_id

      # @return [String] Default API base URL for OpenAI-compatible endpoints.
      #   Used when api_base is not explicitly provided. Points to OpenAI's API.
      #   Can be overridden for local servers, Azure, or other providers.
      DEFAULT_API_BASE = "https://api.openai.com/v1".freeze

      def initialize(model_id:, api_key:, api_base: nil, temperature: nil, max_tokens: nil, timeout: 120)
        @model_id = model_id
        @api_key = api_key
        @api_base = api_base || DEFAULT_API_BASE
        @temperature = temperature
        @max_tokens = max_tokens
        @client = Http::RactorSafeClient.new(
          api_base: @api_base,
          api_key:,
          timeout:
        )
      end

      # Generate a response from the model.
      #
      # @param messages [Array<ChatMessage>] Conversation messages
      # @param stop_sequences [Array<String>, nil] Stop sequences
      # @param temperature [Float, nil] Override default temperature
      # @param max_tokens [Integer, nil] Override default max tokens
      # @param tools [Array<Tool>, nil] Available tools
      # @param response_format [Hash, nil] Response format specification
      # @return [ChatMessage] Assistant's response
      def generate(messages, stop_sequences: nil, temperature: nil, max_tokens: nil, tools: nil, _response_format: nil)
        response = @client.chat_completion(
          model: @model_id,
          messages: format_messages(messages),
          temperature: temperature || @temperature,
          max_tokens: max_tokens || @max_tokens,
          tools: tools && format_tools(tools),
          stop: stop_sequences
        )

        parse_response(response)
      end

      private

      def format_messages(messages)
        messages.map do |msg|
          formatted = { role: msg.role.to_s, content: msg.content }
          formatted[:tool_calls] = msg.tool_calls.map(&:to_h) if msg.tool_calls&.any?
          formatted[:tool_call_id] = msg.raw[:tool_call_id] if msg.raw&.[](:tool_call_id)
          formatted
        end
      end

      def format_tools(tools) = tools.map { |tool| format_tool(tool) }

      def format_tool(tool)
        {
          type: "function",
          function: {
            name: tool.name,
            description: tool.description,
            parameters: { type: "object", properties: tool.inputs }
          }
        }
      end

      def parse_response(response)
        raise Smolagents::AgentGenerationError, "API error: #{response["error"]["message"]}" if response["error"]

        message = response.dig("choices", 0, "message")
        return Smolagents::ChatMessage.assistant("") unless message

        Smolagents::ChatMessage.assistant(
          message["content"],
          tool_calls: parse_tool_calls(message["tool_calls"]),
          raw: response,
          token_usage: extract_token_usage(response["usage"])
        )
      end

      def extract_token_usage(usage)
        usage && Smolagents::TokenUsage.new(input_tokens: usage["prompt_tokens"],
                                            output_tokens: usage["completion_tokens"])
      end

      def parse_tool_calls(tool_calls_data)
        return nil if tool_calls_data.nil? || tool_calls_data.empty?

        tool_calls_data.map { |tc| parse_tool_call(tc) }
      end

      def parse_tool_call(tool_call_data)
        function = tool_call_data["function"]
        Smolagents::ToolCall.new(
          id: tool_call_data["id"],
          name: function["name"],
          arguments: parse_arguments(function["arguments"])
        )
      end

      def parse_arguments(args_json)
        JSON.parse(args_json)
      rescue JSON::ParserError
        { "error" => "Invalid JSON in arguments" }
      end
    end
  end
end
