require_relative "../parsing/critique"

module Smolagents
  module Concerns
    # Mixed-Refinement: Small model generates, larger model provides feedback.
    #
    # Research shows significant improvement when combining model sizes:
    # - Vicuna-13b + ChatGPT: 24% → 40% on math problems
    #
    # @see https://arxiv.org/abs/2303.17651 Self-Refine paper
    #
    # @example Mixed refinement with separate feedback model
    #   agent = Smolagents.agent
    #     .model { small_model }
    #     .refine(feedback_model: large_model, max_iterations: 2)
    #     .build
    module MixedRefinement
      include CritiqueParsing
      include Events::Emitter

      # System prompt for cross-model critique.
      CRITIQUE_SYSTEM = <<~PROMPT.strip.freeze
        You are a code reviewer. If correct, say "APPROVED".
        Otherwise: ISSUE: <description> | FIX: <specific fix>
      PROMPT

      def self.included(base)
        base.attr_reader :mixed_refine_config
      end

      private

      def initialize_mixed_refinement(mixed_refine_config: nil)
        @mixed_refine_config = mixed_refine_config
        @feedback_model_instance = mixed_refine_config&.feedback_model
      end

      def execute_mixed_refinement_if_needed(step, task)
        return nil unless @mixed_refine_config&.enabled
        return nil if step.is_final_answer

        result = attempt_mixed_refinement(step, task)
        emit_mixed_refinement_event(result) if result.refined?
        log_mixed_refinement(result)
        yield result if block_given? && result.refined?
        result
      end

      def attempt_mixed_refinement(step, task)
        return no_refinement_result(step) unless @mixed_refine_config&.enabled

        original = step.action_output || step.code_action
        current, history, iters = refine_with_feedback(original, task)
        build_result(original, current, history, iters)
      end

      def effective_feedback_model
        return @feedback_model_instance if @mixed_refine_config&.cross_model_enabled && @feedback_model_instance

        @model
      end

      def refine_with_feedback(original, task)
        current = original
        history = []
        iters = 0
        @mixed_refine_config.max_iterations.times do
          _, current, done = refine_iteration(current, task, iters, history)
          break if done

          iters += 1
        end
        [current, history, iters]
      end

      def refine_iteration(current, task, iters, history)
        feedback = get_feedback(current, task, iters)
        history << feedback
        return [feedback, current, true] unless feedback.suggests_improvement?

        refined = apply_fix(current, feedback, task)
        return [feedback, current, true] if refined == current

        [feedback, refined, false]
      end

      def get_feedback(output, task, iteration)
        messages = [ChatMessage.system(CRITIQUE_SYSTEM), ChatMessage.user(critique_prompt(output, task))]
        response = effective_feedback_model.generate(messages, max_tokens: 200, temperature: feedback_temp)
        parse_critique_response(response.content, iteration)
      end

      def feedback_temp = @mixed_refine_config&.feedback_temperature || 0.3

      def critique_prompt(output, task)
        "Task: #{task.to_s.slice(0, 300)}\nOutput:\n#{output.to_s.slice(0, 800)}"
      end

      def apply_fix(current, feedback, task)
        prompt = "Task: #{task.to_s.slice(0, 200)}\nCode: #{current.to_s.slice(0, 500)}\n" \
                 "Fix: #{feedback.critique}\n\nOutput corrected code only."
        @model.generate([ChatMessage.user(prompt)], max_tokens: 500).content.strip
      end

      def build_result(original, current, history, iters)
        base = Types::RefinementResult.after_refinement(
          original:, refined: current, iterations: iters, feedback_history: history,
          improved: current != original, confidence: history.last&.confidence || 1.0
        )
        Types::MixedRefinementResult.from_refinement_result(
          base, generation_model: model_id(@model), feedback_model_id: model_id(effective_feedback_model)
        )
      end

      def no_refinement_result(step)
        base = Types::RefinementResult.no_refinement_needed(step.action_output || step.code_action)
        Types::MixedRefinementResult.from_refinement_result(
          base, generation_model: model_id(@model), feedback_model_id: model_id(@model)
        )
      end

      def model_id(model) = model.respond_to?(:model_id) ? model.model_id : model.class.name

      def emit_mixed_refinement_event(result)
        return unless defined?(Events::MixedRefinementCompleted)

        emit(Events::MixedRefinementCompleted.create(
               iterations: result.iterations, improved: result.improved, cross_model: result.cross_model
             ))
      end

      def log_mixed_refinement(result)
        return unless @logger && result.improved

        @logger.info("Mixed refinement", mode: result.cross_model ? "cross" : "same", iterations: result.iterations)
      end
    end
  end
end
