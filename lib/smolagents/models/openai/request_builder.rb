require_relative "../support"

module Smolagents
  module Models
    module OpenAI
      # Request building for OpenAI API.
      #
      # Handles client initialization and parameter construction
      # for chat completion requests. Supports capability-aware
      # parameter filtering for non-OpenAI inference servers.
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
        # When capabilities are provided, filters parameters to only include
        # those supported by the target server. This prevents 400 errors
        # from servers like MLX or LM Studio that don't support all OpenAI
        # API features.
        #
        # @param messages [Array<ChatMessage>] Messages to send
        # @param stop_sequences [Array<String>, nil] Stop sequences
        # @param temperature [Float, nil] Sampling temperature override
        # @param max_tokens [Integer, nil] Max tokens in response
        # @param tools [Array<Tool>, nil] Available tools for function calling
        # @param response_format [Hash, nil] Response format spec (e.g., JSON mode)
        # @param capabilities [Types::ServerCapability, nil] Server capabilities for filtering
        # @return [Hash] Complete API request parameters
        def build_params(messages:, stop_sequences:, temperature:, max_tokens:, tools:, response_format:,
                         capabilities: nil)
          if capabilities
            build_capability_aware_params(
              messages:, stop_sequences:, temperature:, max_tokens:,
              tools:, response_format:, capabilities:
            )
          else
            build_full_params(messages:, stop_sequences:, temperature:, max_tokens:, tools:, response_format:)
          end
        end

        private

        # Build full params for fully compatible servers (llama.cpp, OpenAI, vLLM).
        def build_full_params(messages:, stop_sequences:, temperature:, max_tokens:, tools:, response_format:)
          merge_params(
            build_base_params(messages:, temperature:, max_tokens:, tools:),
            { stop: stop_sequences, response_format: }
          )
        end

        # Build params filtered by server capabilities (MLX, LM Studio, Ollama, llama.cpp).
        def build_capability_aware_params(messages:, stop_sequences:, temperature:, max_tokens:, tools:,
                                          response_format:, capabilities:)
          base = build_base_params_without_tools(messages:, temperature:, max_tokens:)

          include_tools, include_response_format = resolve_feature_conflicts(
            tools:, response_format:, capabilities:
          )

          base[:tools] = format_tools(tools) if include_tools
          base[:response_format] = response_format if include_response_format
          base[:stop] = adapt_stop_sequences(stop_sequences, capabilities)

          compact_params(base)
        end

        # Resolve what features to include, handling server-specific conflicts.
        #
        # CRITICAL: llama.cpp cannot use tools AND response_format together.
        # When both requested, prefer tools for agent workloads.
        def resolve_feature_conflicts(tools:, response_format:, capabilities:)
          include_tools = tools&.any? && capability_supports_tools?(capabilities)
          include_response_format = response_format && response_format_supported?(response_format, capabilities)

          # Drop response_format when conflict exists (llama.cpp)
          include_response_format = false if tool_response_format_conflict?(
            include_tools, include_response_format, capabilities
          )

          [include_tools, include_response_format]
        end

        def tool_response_format_conflict?(include_tools, include_response_format, capabilities)
          include_tools && include_response_format && capabilities.tools_response_format_conflict?
        end

        # Check if tools are supported by the given capabilities.
        # Returns true for:
        #   - true (explicitly supported)
        #   - :model_dependent (might work, be optimistic - server will error if not)
        # Returns false for:
        #   - false (explicitly not supported)
        #   - nil (unknown)
        def capability_supports_tools?(capabilities)
          supports = capabilities.supports_tools
          [true, :model_dependent].include?(supports)
        end

        # Check if the response_format is supported by the server.
        def response_format_supported?(response_format, capabilities)
          return false unless response_format

          case response_format[:type] || response_format["type"]
          when "json_object" then capabilities.supports_json_object
          when "json_schema" then capabilities.supports_json_schema
          when "text" then true
          else false
          end
        end

        # Build base params without tools for capability-aware building.
        def build_base_params_without_tools(messages:, temperature:, max_tokens:)
          {
            model: @model_id,
            messages: format_messages(messages),
            temperature: temperature || @temperature,
            max_tokens: max_tokens || @max_tokens
          }.compact
        end

        # Adapt stop sequences based on server capability.
        def adapt_stop_sequences(sequences, capabilities)
          return nil if sequences.nil? || sequences.empty?

          if capabilities.supports_stop_array
            sequences
          else
            # MLX only supports single stop string
            sequences.first
          end
        end

        # Remove nil values and empty collections.
        def compact_params(params)
          params.compact.reject { |_, v| v.respond_to?(:empty?) && v.empty? }
        end

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
