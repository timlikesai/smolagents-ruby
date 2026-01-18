module Smolagents
  module Testing
    # Query methods for MockModel.
    #
    # Provides methods to inspect recorded generate() calls and query
    # the state of the mock model. All methods are thread-safe.
    #
    # @see MockModel
    module MockModelQuery
      # Returns the most recent generate() call.
      #
      # @return [MockCall, nil] Call data or nil if no calls made
      def last_call = @monitor.synchronize { @calls.last }

      # Returns the messages from the most recent call.
      #
      # @return [Array<ChatMessage>, nil] Messages or nil if no calls
      def last_messages = last_call&.messages

      # Returns all calls that included a system prompt.
      #
      # @return [Array<MockCall>] Calls containing system messages
      def calls_with_system_prompt
        @monitor.synchronize { @calls.select(&:system_message?) }
      end

      # Returns all user messages sent across all calls.
      #
      # Flattens messages from all calls and filters to user role.
      #
      # @return [Array<ChatMessage>] All user messages
      def user_messages_sent
        @monitor.synchronize { @calls.flat_map(&:user_messages) }
      end

      # Returns all assistant messages from queued responses that were consumed.
      #
      # @return [Array<ChatMessage>] Assistant messages that were returned
      def assistant_messages_returned
        @monitor.synchronize { @calls.filter_map { |c| c[:response] } }
      end

      # Checks if all queued responses have been consumed.
      #
      # @return [Boolean] True if response queue is empty
      def exhausted? = @monitor.synchronize { @responses.empty? }

      # Returns the number of unconsumed queued responses.
      #
      # @return [Integer] Remaining response count
      def remaining_responses = @monitor.synchronize { @responses.size }
    end
  end
end
