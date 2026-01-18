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
          Types::ChatMessage.new(role:, content:, **)
        end

        # Creates an ActionStep fixture.
        #
        # @param step_number [Integer] Step number
        # @param kwargs [Hash] Additional ActionStep attributes
        # @return [ActionStep]
        def action_step(step_number: 1, **kwargs)
          Types::ActionStep.new(step_number:).tap do |s|
            s.timing = Types::Timing.start_now
            kwargs.each { |k, v| s.send(:"#{k}=", v) }
          end
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
