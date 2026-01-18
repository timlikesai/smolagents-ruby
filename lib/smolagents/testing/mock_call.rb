module Smolagents
  module Testing
    # Immutable record of a generate() call for inspection.
    #
    # Created by MockModel each time generate() is called, capturing the
    # messages, tools, and timestamp for later verification in tests.
    #
    # @example Inspecting a recorded call
    #   call = model.last_call
    #   call.index           # => 1
    #   call.system_message? # => true
    #   call.user_messages   # => [ChatMessage(...)]
    #   call.last_user_content  # => "What is 2+2?"
    #
    # @see MockModel
    MockCall = Data.define(:index, :messages, :tools_to_call_from, :timestamp) do
      # Checks if this call included a system message.
      # @return [Boolean]
      def system_message? = messages.any? { |m| m.role == Types::MessageRole::SYSTEM }

      # Returns all user messages from this call.
      # @return [Array<ChatMessage>]
      def user_messages = messages.select { |m| m.role == Types::MessageRole::USER }

      # Returns all assistant messages from this call.
      # @return [Array<ChatMessage>]
      def assistant_messages = messages.select { |m| m.role == Types::MessageRole::ASSISTANT }

      # Returns the content of the last user message.
      # @return [String, nil]
      def last_user_content = user_messages.last&.content

      # Hash-style access for backwards compatibility.
      # @param key [Symbol] The key to access (:index, :messages, :tools_to_call_from, :timestamp)
      # @return [Object] The value for the key
      def [](key) = public_send(key)

      # Hash-style dig for backwards compatibility.
      # @param keys [Array<Symbol>] Keys to dig through
      # @return [Object, nil] The nested value
      def dig(*keys)
        keys.reduce(self) do |obj, key|
          return nil if obj.nil?

          obj.respond_to?(:[]) ? obj[key] : obj.public_send(key)
        end
      end
    end
  end
end
