module Smolagents
  module Concerns
    module SelfRefine
      # Feedback sources for refinement.
      #
      # Routes to appropriate feedback method based on configuration.
      module Feedback
        private

        # Gets feedback based on configured source.
        #
        # @param output [Object] Current output to evaluate
        # @param step [ActionStep] The step context
        # @param task [String] Original task
        # @param iteration [Integer] Current iteration number
        # @return [Smolagents::Types::RefinementFeedback] Feedback for this iteration
        FEEDBACK_SOURCES = {
          execution: ->(o, s, _t, i, fb) { fb.send(:execution_feedback, o, s, i) },
          self: ->(o, _s, t, i, fb) { fb.send(:self_critique_feedback, o, t, i) },
          evaluation: ->(o, s, t, i, fb) { fb.send(:evaluation_feedback, o, s, t, i) }
        }.freeze

        def get_refinement_feedback(output, step, task, iteration)
          handler = FEEDBACK_SOURCES[@refine_config.feedback_source]
          return handler.call(output, step, task, iteration, self) if handler

          Smolagents::Types::RefinementFeedback.new(iteration:, source: :none, critique: "Unknown feedback source",
                                                    actionable: false, confidence: 0.0)
        end

        def execution_feedback(_output, step, iteration)
          step.error ? error_feedback(step, iteration) : success_feedback(iteration)
        end

        def error_feedback(step, iteration)
          oracle_fb = try_oracle_feedback(step)
          return oracle_fb.call(iteration) if oracle_fb

          refinement_feedback(iteration, :execution, "Execution error: #{step.error}", true, 0.7)
        end

        def try_oracle_feedback(step)
          return unless respond_to?(:analyze_execution, true)

          result = step.respond_to?(:execution_result) ? step.execution_result : nil
          return unless result

          oracle = analyze_execution(result, step.code_action)
          ->(i) { refinement_feedback(i, :execution, oracle.to_observation, oracle.actionable?, oracle.confidence) }
        end

        def success_feedback(iteration) = refinement_feedback(iteration, :execution, "Execution succeeded", false, 0.9)

        def refinement_feedback(iteration, source, critique, actionable, confidence)
          Smolagents::Types::RefinementFeedback.new(iteration:, source:, critique:, actionable:, confidence:)
        end

        def evaluation_feedback(_output, step, task, iteration)
          unless respond_to?(:evaluate_progress, true)
            return refinement_feedback(iteration, :evaluation, "Evaluation not available", false, 0.5)
          end

          result = evaluate_progress(task, step, iteration + 1)
          critique = result.reasoning || result.answer || "Evaluation complete"
          actionable = result.continue? || result.stuck?
          refinement_feedback(iteration, :evaluation, critique, actionable, result.confidence || 0.5)
        end
      end
    end
  end
end
