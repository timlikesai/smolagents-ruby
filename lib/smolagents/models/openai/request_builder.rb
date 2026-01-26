require_relative "../support"

module Smolagents
  module Models
    module OpenAI
      # Request building for OpenAI API.
      #
      # Handles client initialization and parameter construction
      # for chat completion requests.
      module RequestBuilder
        include ModelSupport::RequestBuilding
        include ModelSupport::ToolSchema

        # Builds OpenAI client with configured options.
        #
        # Sets up authentication, URI base, and timeout. Handles Azure API configuration if specified.
        #
        # @param api_base [String, nil] Base URL for API
        # @param timeout [Integer, nil] Request timeout in seconds
        # @return [OpenAI::Client] Configured client instance
        def build_client(api_base: nil, timeout: nil)
          client_opts = build_client_options(api_base, timeout)
          apply_azure_config(client_opts, api_base) if @azure_api_version
          ::OpenAI::Client.new(**client_opts)
        end

        # Builds parameters hash for chat completion request.
        #
        # Combines base params with stop sequences and response format specification.
        #
        # @param messages [Array<ChatMessage>] Messages to send
        # @param stop_sequences [Array<String>, nil] Stop sequences
        # @param temperature [Float, nil] Sampling temperature override
        # @param max_tokens [Integer, nil] Max tokens in response
        # @param tools [Array<Tool>, nil] Available tools for function calling
        # @param response_format [Hash, nil] Response format spec (e.g., JSON mode)
        # @return [Hash] Complete API request parameters
        def build_params(messages:, stop_sequences:, temperature:, max_tokens:, tools:, response_format:)
          merge_params(
            build_base_params(messages:, temperature:, max_tokens:, tools:),
            { stop: stop_sequences, response_format: }
          )
        end

        private

        def build_client_options(api_base, timeout)
          {
            access_token: @api_key,
            uri_base: api_base,
            request_timeout: timeout
          }.compact
        end

        def apply_azure_config(client_opts, api_base)
          client_opts[:extra_headers] = { "api-key" => @api_key }
          client_opts[:uri_base] = "#{api_base}?api-version=#{@azure_api_version}"
        end

        def format_tools(tools) = tools.map { |tool| wrap_openai_tool(tool) }

        def wrap_openai_tool(tool)
          schema = extract_tool_schema(tool, type_mapper: ->(type) { json_schema_type(type) })
          { type: "function", function: { name: schema[:name], description: schema[:description],
                                          parameters: build_parameters_schema(schema) } }
        end
      end
    end
  end
end
