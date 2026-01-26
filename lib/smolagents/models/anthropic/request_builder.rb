require_relative "../support"

module Smolagents
  module Models
    module Anthropic
      # Request parameter building for Anthropic API.
      #
      # Handles construction of API request parameters including
      # system message extraction and tool formatting.
      module RequestBuilder
        include ModelSupport::RequestBuilding
        include ModelSupport::ToolSchema

        # Builds Anthropic client with configured options.
        #
        # @param api_base [String, nil] Not used by Anthropic (included for interface consistency)
        # @param timeout [Integer, nil] Request timeout in seconds
        # @return [Anthropic::Client] Configured client instance
        # rubocop:disable Lint/UnusedMethodArgument -- api_base kept for interface consistency with OpenAI
        def build_client(api_base: nil, timeout: nil)
          # rubocop:enable Lint/UnusedMethodArgument
          client_opts = { access_token: @api_key }
          client_opts[:request_timeout] = timeout if timeout
          ::Anthropic::Client.new(**client_opts)
        end

        # Builds parameters for non-streaming Anthropic chat request.
        #
        # @param messages [Array<ChatMessage>] Messages to send
        # @param stop_sequences [Array<String>, nil] Sequences to stop generation
        # @param temperature [Float, nil] Sampling temperature
        # @param max_tokens [Integer, nil] Max tokens in response
        # @param tools [Array<Tool>, nil] Available tools
        # @return [Hash] Request parameters for Anthropic API
        def build_params(messages:, stop_sequences:, temperature:, max_tokens:, tools:)
          system_content, user_messages = extract_system_message(messages)
          merge_params(
            build_base_params(messages: user_messages, temperature:, max_tokens:, tools:),
            { system: system_content, stop_sequences: }
          )
        end

        # Builds parameters for streaming Anthropic chat request.
        #
        # @param messages [Array<ChatMessage>] Messages to send
        # @return [Hash] Request parameters for Anthropic streaming API
        def build_stream_params(messages)
          system_content, user_messages = extract_system_message(messages)
          merge_params(
            build_base_params(messages: user_messages, temperature: @temperature, max_tokens: @max_tokens),
            { stream: true, system: system_content }
          )
        end

        private

        # Anthropic requires system messages as separate parameter
        def extract_system_message(messages)
          system_msgs, user_msgs = messages.partition { |msg| msg.role.to_sym == :system }
          system_content = system_msgs.any? ? system_msgs.map(&:content).join("\n\n") : nil
          [system_content, user_msgs]
        end

        # Format tools for Anthropic's tool use format
        def format_tools(tools) = tools.map { |tool| wrap_anthropic_tool(tool) }

        def wrap_anthropic_tool(tool)
          schema = extract_tool_schema(tool)
          { name: schema[:name], description: schema[:description],
            input_schema: build_parameters_schema(schema) }
        end
      end
    end
  end
end
