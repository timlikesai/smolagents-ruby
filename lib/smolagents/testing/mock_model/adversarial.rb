module Smolagents
  module Testing
    # Adversarial response factories for MockModel.
    #
    # Factory methods that queue specifically crafted adversarial responses
    # for testing agent resilience against common model failure modes.
    #
    # @example Testing format drift
    #   model.queue_malformed("Here's what I think: the answer is 42")
    #   model.queue_hallucinated_tool("nonexistent_tool(arg: 'value')")
    #
    # @example Testing empty responses
    #   model.queue_empty_response
    #   model.queue_empty_final_answer
    #
    # @see MockModel
    module MockModelAdversarial
      # Queue prose without code blocks (triggers parse failure).
      #
      # @param text [String] Plain text response without code tags
      # @return [self]
      def queue_malformed(text) = queue_response(text)

      # Queue a code block calling a nonexistent tool.
      #
      # @param call_str [String] Tool call expression (e.g. "fake_tool(arg: 1)")
      # @return [self]
      def queue_hallucinated_tool(call_str) = queue_code_action(call_str)

      # Queue an empty string response (no content at all).
      #
      # @return [self]
      def queue_empty_response = queue_response("")

      # Queue a final_answer with nil value.
      #
      # @return [self]
      def queue_empty_final_answer = queue_code_action("final_answer(answer: nil)")

      # Queue text with reasoning but no code block.
      #
      # @param text [String] The reasoning text
      # @return [self]
      def queue_text_only(text)
        queue_response("I think the answer is: #{text}")
      end
    end
  end
end
