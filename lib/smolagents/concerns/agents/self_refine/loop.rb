module Smolagents
  module Concerns
    module SelfRefine
      # Refinement loop control flow.
      #
      # Handles the iterative Generate -> Feedback -> Refine loop.
      module Loop
        private

        # Attempts to refine a step's output through iterative feedback.
        #
        # @param step [ActionStep] The step to potentially refine
        # @param task [String] The original task for context
        # @return [Smolagents::Types::RefinementResult] The refinement outcome
        def attempt_refinement(step, task)
          return Smolagents::Types::RefinementResult.no_refinement_needed(step) unless @refine_config&.enabled

          state = RefinementState.from_output(step.action_output)
          run_refinement_loop(state, step, task)
          build_refinement_result(state)
        end

        # Mutable struct for refinement state tracking
        # rubocop:disable Smolagents/PreferDataDefine -- needs mutation for loop iteration
        RefinementState = Struct.new(:original, :current, :feedback_history, :iterations) do
          def self.from_output(output)
            new(output, output, [], 0)
          end

          def improved? = current != original
          def confidence = feedback_history.last&.confidence || 1.0
        end
        # rubocop:enable Smolagents/PreferDataDefine

        def run_refinement_loop(state, step, task)
          while state.iterations < @refine_config.max_iterations
            feedback = get_refinement_feedback(state.current, step, task, state.iterations)
            state.feedback_history << feedback
            break unless feedback.suggests_improvement?

            state.iterations += 1
            refined = apply_refinement(state.current, feedback, task)
            break if refined == state.current

            state.current = refined
          end
        end

        def build_refinement_result(state)
          Smolagents::Types::RefinementResult.after_refinement(
            original: state.original, refined: state.current, iterations: state.iterations,
            feedback_history: state.feedback_history, improved: state.improved?, confidence: state.confidence
          )
        end

        # Executes refinement if configured, wrapping step execution.
        #
        # @param step [ActionStep] Step to potentially refine
        # @param task [String] Original task
        # @yield [RefinementResult] If block given, yields result
        # @return [Smolagents::Types::RefinementResult, nil] Result or nil if disabled
        def execute_refinement_if_needed(step, task)
          return nil unless @refine_config&.enabled
          return nil if step.is_final_answer

          result = attempt_refinement(step, task)
          emit_refinement_event(result) if result.refined?
          log_refinement_result(result)
          yield result if block_given?
          result
        end

        def emit_refinement_event(result)
          return unless respond_to?(:emit, true)

          emit(Events::RefinementCompleted.create(
                 iterations: result.iterations,
                 improved: result.improved,
                 confidence: result.confidence
               ))
        rescue NameError
          # Event not defined - skip
        end

        def log_refinement_result(result)
          return unless @logger

          if result.improved
            @logger.info("Refinement improved output", iterations: result.iterations)
          elsif result.refined?
            @logger.debug("Refinement attempted but no improvement", iterations: result.iterations)
          end
        end
      end
    end
  end
end
