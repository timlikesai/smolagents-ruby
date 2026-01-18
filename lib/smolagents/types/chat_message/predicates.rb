module Smolagents
  module Types
    module ChatMessageComponents
      # Predicate methods for ChatMessage.
      #
      # Provides boolean queries for message properties.
      module Predicates
        # Checks if this message contains tool calls.
        #
        # @return [Boolean] True if tool_calls array has any elements
        def tool_calls? = tool_calls&.any? || false

        # Checks if this message has attached images.
        #
        # @return [Boolean] True if images array has any elements
        def images? = images&.any? || false
      end
    end
  end
end
