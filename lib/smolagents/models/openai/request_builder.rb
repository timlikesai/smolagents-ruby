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

        # Builds OpenAI client with configured options.
        #
        # @param api_base [String, nil] Base URL for API
        # @param timeout [Integer, nil] Request timeout in seconds
        # @return [OpenAI::Client] Configured client
        def build_client(api_base, timeout)
          client_opts = build_client_options(api_base, timeout)
          apply_azure_config(client_opts, api_base) if @azure_api_version
          ::OpenAI::Client.new(**client_opts)
        end

        # Builds parameters hash for chat completion request.
        #
        # @param messages [Array<ChatMessage>] Messages to send
        # @param stop_sequences [Array<String>, nil] Stop sequences
        # @param temperature [Float, nil] Sampling temperature
        # @param max_tokens [Integer, nil] Max tokens in response
        # @param tools [Array<Tool>, nil] Available tools
        # @param response_format [Hash, nil] Response format spec
        # @return [Hash] API request parameters
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

        def format_tools(tools)
          tools.map { |tool| { type: "function", function: format_tool_function(tool) } }
        end

        def format_tool_function(tool)
          {
            name: tool.name,
            description: tool.description,
            parameters: {
              type: "object",
              properties: tool_properties(tool, type_mapper: ->(type) { json_schema_type(type) }),
              required: tool_required_fields(tool)
            }
          }
        end
      end
    end
  end
end
