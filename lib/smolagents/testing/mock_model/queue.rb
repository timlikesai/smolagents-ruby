module Smolagents
  module Testing
    # Queue methods for MockModel. Responses returned in FIFO order.
    # @see MockModel
    module MockModelQueue
      # Queue a response for the next generate() call. @return [self]
      def queue_response(content, input_tokens: 50, output_tokens: 25)
        message = build_response_message(content, input_tokens:, output_tokens:)
        @monitor.synchronize { @responses << message }
        self
      end

      # Queue code wrapped in tags for CodeAgent. @return [self]
      def queue_code_action(code) = queue_response("<code>\n#{code}\n</code>")

      # Queue a final_answer() call. @return [self]
      def queue_final_answer(answer) = queue_code_action("final_answer(answer: #{answer.inspect})")

      # Queue plain text (no code). @return [self]
      def queue_planning_response(plan) = queue_response(plan)

      # Queue evaluation "DONE: answer". @return [self]
      def queue_evaluation_done(answer)
        queue_response("DONE: #{answer}", input_tokens: 20, output_tokens: 10)
      end

      # Queue evaluation "CONTINUE: reason". @return [self]
      def queue_evaluation_continue(reason = "More work needed")
        queue_response("CONTINUE: #{reason}", input_tokens: 20, output_tokens: 10)
      end

      # Queue evaluation "STUCK: reason". @return [self]
      def queue_evaluation_stuck(reason)
        queue_response("STUCK: #{reason}", input_tokens: 20, output_tokens: 10)
      end

      # Queue code action + evaluation continue. @return [self]
      def queue_step_with_eval(code, eval_reason: "More work needed")
        queue_code_action(code)
        queue_evaluation_continue(eval_reason)
      end

      # Queue a tool call for ToolAgent JSON format. @return [self]
      def queue_tool_call(name, id: SecureRandom.uuid, **arguments)
        tool_call = Types::ToolCall.new(name:, arguments:, id:)
        message = Types::ChatMessage.assistant(
          nil,
          tool_calls: [tool_call],
          token_usage: Types::TokenUsage.new(input_tokens: 50, output_tokens: 25)
        )
        @monitor.synchronize { @responses << message }
        self
      end

      # ============================================================
      # Self-Refine Queue Methods
      # ============================================================

      # Queue approval response (no refinement needed). @return [self]
      def queue_critique_approved = queue_response("LGTM", input_tokens: 20, output_tokens: 5)

      # Queue actionable critique (triggers refinement). @return [self]
      def queue_critique_issue(issue, fix)
        queue_response("ISSUE: #{issue} | FIX: #{fix}", input_tokens: 30, output_tokens: 20)
      end

      # Queue refined code after critique. @return [self]
      def queue_refinement(code) = queue_response(code, input_tokens: 40, output_tokens: 30)

      # Queue complete action + refine cycle (action, critique, refinement). @return [self]
      def queue_action_with_refinement(initial_code, issue:, fix:, refined_code:)
        queue_code_action(initial_code)
        queue_critique_issue(issue, fix)
        queue_refinement(refined_code)
      end

      private

      def build_response_message(content, input_tokens:, output_tokens:)
        return content if content.is_a?(Types::ChatMessage)

        Types::ChatMessage.assistant(
          content,
          token_usage: Types::TokenUsage.new(input_tokens:, output_tokens:)
        )
      end
    end
  end
end
