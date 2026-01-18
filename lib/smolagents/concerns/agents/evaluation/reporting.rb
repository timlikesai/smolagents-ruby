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

        def log_evaluation_result(result, step_count)
          case result.status
          when :goal_achieved
            @logger.info("Evaluation: goal achieved", step: step_count, answer: result.answer&.slice(0, 50))
          when :stuck
            @logger.warn("Evaluation: stuck", step: step_count, reason: result.reasoning&.slice(0, 50))
          else
            @logger.debug("Evaluation: continue", step: step_count, reason: result.reasoning&.slice(0, 50))
          end
        end
      end
    end
  end
end
