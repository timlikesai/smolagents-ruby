module Smolagents
  module Types
    module ChatMessageComponents
      # Factory methods for creating ChatMessage instances.
      #
      # Uses a declarative role configuration to generate factory methods via
      # metaprogramming, reducing boilerplate while maintaining clear semantics.
      module Factories
        extend ImageSupport

        # Role configuration for metaprogrammed factory methods.
        # Each role maps to its factory parameters.
        ROLE_CONFIGS = {
          system: { params: %i[content], defaults: {} },
          user: { params: %i[content images], defaults: { images: nil } },
          tool_call: { params: %i[tool_calls], defaults: {} }
        }.freeze

        # Creates an assistant message.
        #
        # Assistant messages represent the LLM's responses, including optional
        # tool calls and extended reasoning (for models like o1).
        #
        # @param content [String, nil] The assistant's response text
        # @param tool_calls [Array<ToolCall>, nil] Tool calls made by the assistant
        # @param raw [Hash, nil] Raw API response for debugging and event handling
        # @param token_usage [TokenUsage, nil] Input and output token counts
        # @param reasoning_content [String, nil] Extended thinking from o1, DeepSeek models
        # @return [ChatMessage] Assistant role message
        def assistant(content, tool_calls: nil, raw: nil, token_usage: nil, reasoning_content: nil)
          create(MessageRole::ASSISTANT, content:, tool_calls:, raw:, token_usage:, reasoning_content:)
        end

        # Creates a tool response message.
        #
        # Tool response messages return the results of tool execution back to the
        # assistant. They close the tool call-response loop in multi-turn conversations.
        #
        # @param content [String] The tool execution result or error message
        # @param tool_call_id [String, nil] ID linking response to the originating call
        # @return [ChatMessage] Tool response role message
        def tool_response(content, tool_call_id: nil)
          create(MessageRole::TOOL_RESPONSE, content:, raw: { tool_call_id: })
        end

        def self.extended(base)
          define_simple_factories(base)
        end

        def self.define_simple_factories(base)
          ROLE_CONFIGS.each do |role, config|
            define_factory_method(base, role, config)
          end
        end

        def self.define_factory_method(base, role, config)
          params = config[:params]
          defaults = config[:defaults]

          base.define_singleton_method(role) do |*args, **kwargs|
            merged = defaults.merge(kwargs)
            merged[params.first] = args.first if args.any?
            create(MessageRole.const_get(role.to_s.upcase), **merged)
          end
        end

        private

        def create(role, content: nil, tool_calls: nil, raw: nil, token_usage: nil, images: nil, reasoning_content: nil)
          new(role:, content:, tool_calls:, raw:, token_usage:, images:, reasoning_content:)
        end
      end
    end
  end
end
