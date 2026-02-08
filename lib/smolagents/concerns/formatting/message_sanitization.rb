module Smolagents
  module Concerns
    # Ensures message sequences meet LLM role alternation requirements.
    #
    # Many LLMs (especially those using Jinja templates like gemma, mistral)
    # require strict role alternation: system -> user -> assistant -> user -> ...
    # This concern provides sanitization to merge consecutive same-role messages
    # and ensure valid sequences before API submission.
    #
    # @example Sanitize messages before API call
    #   messages = sanitize_message_roles(messages)
    #   # Consecutive assistant messages merged, ready for API
    #
    # @see MessageRole For role constants
    # @see OpenAI::MessageFormatter For API formatting
    module MessageSanitization
      # Roles that map to "user" in OpenAI-compatible APIs.
      USER_EQUIVALENT_ROLES = %i[user tool_response].freeze

      # Roles that map to "assistant" in OpenAI-compatible APIs.
      ASSISTANT_EQUIVALENT_ROLES = %i[assistant tool_call].freeze

      # Sanitizes message array to ensure valid role alternation.
      #
      # Merges consecutive same-role messages to satisfy LLM role alternation
      # requirements. Does NOT filter out messages - only merges.
      #
      # @param messages [Array<ChatMessage>] Messages to sanitize
      # @return [Array<ChatMessage>] Sanitized messages with valid alternation
      def sanitize_message_roles(messages)
        return [] if messages.nil? || messages.empty?

        # Remove nil messages only, then merge consecutive same-role
        filtered = messages.compact
        return [] if filtered.empty?

        merge_consecutive_same_role(filtered)
      end

      # Checks if message sequence has valid role alternation.
      #
      # @param messages [Array<ChatMessage>] Messages to validate
      # @return [Boolean] True if alternation is valid
      def valid_role_alternation?(messages)
        return true if messages.nil? || messages.size < 2

        messages.each_cons(2).all? do |prev, curr|
          !same_effective_role?(prev, curr)
        end
      end

      # Returns effective API role for a message.
      #
      # Maps internal roles to OpenAI-compatible roles:
      # - :tool_response -> :user (in code mode)
      # - :tool_call -> :assistant
      #
      # @param message [ChatMessage] Message to check
      # @return [Symbol] Effective role (:system, :user, or :assistant)
      def effective_role(message)
        role = message.role.to_sym
        return :system if role == :system
        return :user if USER_EQUIVALENT_ROLES.include?(role)
        return :assistant if ASSISTANT_EQUIVALENT_ROLES.include?(role)

        role
      end

      private

      # Merges consecutive messages with the same effective role.
      #
      # @param messages [Array<ChatMessage>] Filtered messages
      # @return [Array<ChatMessage>] Merged messages
      def merge_consecutive_same_role(messages)
        return messages if messages.size < 2

        result = []
        pending = nil

        messages.each do |msg|
          if pending.nil?
            pending = msg
          elsif same_effective_role?(pending, msg)
            pending = merge_messages(pending, msg)
          else
            result << pending
            pending = msg
          end
        end

        result << pending if pending
        result
      end

      # Checks if two messages have the same effective role.
      #
      # @param a [ChatMessage] First message
      # @param b [ChatMessage] Second message
      # @return [Boolean] True if same effective role
      def same_effective_role?(a, b)
        effective_role(a) == effective_role(b)
      end

      # Merges two messages into one.
      #
      # Combines content with separator, preserves tool_calls from both.
      #
      # @param a [ChatMessage] First message
      # @param b [ChatMessage] Second message
      # @return [ChatMessage] Merged message
      def merge_messages(a, b)
        combined_content = [a.content, b.content].compact.reject(&:empty?).join("\n\n")
        combined_tool_calls = merge_tool_calls(a.tool_calls, b.tool_calls)

        Types::ChatMessage.new(
          role: a.role,
          content: combined_content,
          tool_calls: combined_tool_calls,
          raw: a.raw,
          token_usage: merge_token_usage(a.token_usage, b.token_usage),
          images: merge_images(a.images, b.images),
          reasoning_content: a.reasoning_content || b.reasoning_content
        )
      end

      def merge_tool_calls(a, b)
        return nil if a.nil? && b.nil?

        [*a, *b].compact
      end

      def merge_token_usage(a, b)
        return a if b.nil?
        return b if a.nil?

        # Sum token usage if both present
        Types::TokenUsage.new(
          input_tokens: (a.input_tokens || 0) + (b.input_tokens || 0),
          output_tokens: (a.output_tokens || 0) + (b.output_tokens || 0)
        )
      end

      def merge_images(a, b)
        return nil if a.nil? && b.nil?

        [*a, *b].compact
      end
    end
  end
end
