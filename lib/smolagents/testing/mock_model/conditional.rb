module Smolagents
  module Testing
    # Conditional response logic for MockModel.
    #
    # Conditionals are checked BEFORE the FIFO queue in generate().
    # If no conditional matches, falls through to the normal queue.
    #
    # @example Pattern-based responses
    #   model.when_input_matches(/error/) { "final_answer(answer: 'recovered')" }
    #   model.when_input_matches(/search/) { 'search(query: "Ruby")' }
    #   model.default_response("final_answer(answer: 'fallback')")
    #
    # @see MockModel
    module MockModelConditional
      # Register a conditional response triggered by input pattern.
      #
      # When the last message content matches the pattern, the block is called
      # and its return value is wrapped as a code action response.
      #
      # @param pattern [Regexp] Pattern to match against last message content
      # @yield [messages] Block returning code string for the response
      # @yieldparam messages [Array<ChatMessage>] Full message list (if arity == 1)
      # @return [self]
      def when_input_matches(pattern, &block)
        @monitor.synchronize { @conditionals << [pattern, block] }
        self
      end

      # Set a default response used when queue is empty and no conditional matches.
      #
      # @param content [String] Response content (wrapped in code tags)
      # @return [self]
      def default_response(content)
        @monitor.synchronize do
          @default = build_response_message(
            "<code>\n#{content}\n</code>", input_tokens: 50, output_tokens: 25
          )
        end
        self
      end

      private

      # Check conditionals against the last message in the conversation.
      #
      # @param messages [Array<ChatMessage>] Messages from generate() call
      # @return [ChatMessage, nil] Matched response or nil
      def check_conditionals(messages)
        last_msg = messages.last
        last_content = (last_msg.respond_to?(:content) ? last_msg.content : last_msg&.dig(:content)).to_s
        @conditionals.each do |pattern, block|
          next unless last_content.match?(pattern)

          code = block.arity == 1 ? block.call(messages) : block.call
          return build_response_message(
            "<code>\n#{code}\n</code>", input_tokens: 50, output_tokens: 25
          )
        end
        nil
      end
    end
  end
end
