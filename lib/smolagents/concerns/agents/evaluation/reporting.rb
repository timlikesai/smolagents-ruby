module Smolagents
  module Concerns
    module Evaluation
      # Records and reports evaluation results.
      #
      # Handles logging, event emission, and observability context updates.
      module Reporting
        def record_evaluation_to_context(result)
          ctx = Types::ObservabilityContext.current
          return unless ctx

          ctx.add_tokens(result.token_usage)
          ctx.record_evaluation(result)
        end

        def emit_evaluation_event(result, step_count)
          emit(Events::EvaluationCompleted.create(
                 step_number: step_count,
                 status: result.status,
                 answer: result.answer,
                 reasoning: result.reasoning,
                 confidence: result.confidence,
                 token_usage: result.token_usage
               ))
        end

        # NOTE: Evaluation results are communicated via EvaluationCompleted events.
        # Consumers can subscribe to events and log as needed.
        # The event includes status (:goal_achieved, :stuck, :continue), answer,
        # reasoning, confidence, and token_usage fields.
      end
    end
  end
end
