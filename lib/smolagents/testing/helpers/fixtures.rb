module Smolagents
  module Testing
    module Helpers
      # Test fixture factory methods.
      #
      # Provides convenience methods for creating test data objects.
      # These are useful for unit testing components that work with
      # agent types without running full agent tests.
      #
      # @example Creating fixtures
      #   message = Fixtures.chat_message(role: :user, content: "Hello")
      #   step = Fixtures.action_step(step_number: 1)
      #   call = Fixtures.tool_call(name: "search", arguments: { query: "test" })
      module Fixtures
        module_function

        # Creates a ChatMessage fixture.
        #
        # @param role [Symbol] Message role (:user, :assistant, :system)
        # @param content [String] Message content
        # @param kwargs [Hash] Additional ChatMessage attributes
        # @return [ChatMessage]
        def chat_message(role: :assistant, content: "Test message", **)
          normalized_role = normalize_role(role)
          create_message_for_role(normalized_role, content, **)
        end

        def normalize_role(role)
          { Types::MessageRole::USER => :user, Types::MessageRole::SYSTEM => :system,
            Types::MessageRole::ASSISTANT => :assistant }.fetch(role, role)
        end

        def create_message_for_role(role, content, **kwargs)
          return Types::ChatMessage.user(content, **kwargs) if role == :user
          return Types::ChatMessage.system(content) if role == :system
          return Types::ChatMessage.tool_call(kwargs[:tool_calls]) if role == :tool_call
          return Types::ChatMessage.tool_response(content, **kwargs) if role == :tool_response

          Types::ChatMessage.assistant(content, **kwargs)
        end

        # Creates an ActionStep fixture.
        #
        # @param step_number [Integer] Step number
        # @param kwargs [Hash] Additional ActionStep attributes
        # @return [ActionStep]
        def action_step(step_number: 1, **kwargs)
          timing = kwargs.delete(:timing) || Types::Timing.start_now
          Types::ActionStep.new(step_number:, timing:, **kwargs)
        end

        # Creates a ToolCall fixture.
        #
        # @param name [String] Tool name
        # @param arguments [Hash] Tool arguments
        # @param id [String] Tool call ID (auto-generated if not provided)
        # @return [ToolCall]
        def tool_call(name: "test_tool", arguments: {}, id: SecureRandom.uuid)
          Types::ToolCall.new(name:, arguments:, id:)
        end

        # Creates a TokenUsage fixture.
        #
        # @param input [Integer] Input token count
        # @param output [Integer] Output token count
        # @return [TokenUsage]
        def token_usage(input: 100, output: 50)
          Types::TokenUsage.new(input_tokens: input, output_tokens: output)
        end
      end
    end
  end
end
