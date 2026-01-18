module Smolagents
  module Concerns
    module ReflectionMemory
      # Reflection generation and error analysis.
      #
      # Handles creating reflections from step outcomes and
      # inferring actionable guidance from errors.
      module Analysis
        include Events::Emitter

        private

        # Records a reflection from a step outcome.
        #
        # @param step [ActionStep] The step to reflect on
        # @param task [String] The current task
        # @return [Smolagents::Types::Reflection, nil] The recorded reflection or nil
        def record_reflection(step, task)
          return nil unless @reflection_config&.enabled
          return nil if step.is_final_answer

          reflection = step.error ? failure_reflection(step, task) : success_reflection_if_enabled(step, task)
          record_and_emit(reflection) if reflection
          reflection
        end

        def failure_reflection(step, task)
          generate_failure_reflection(step, task).tap do |r|
            emit_reflection_event(r)
            log_reflection(r)
          end
        end

        def success_reflection_if_enabled(step, task)
          return unless @reflection_config.include_successful && step.action_output

          generate_success_reflection(step, task)
        end

        def record_and_emit(reflection)
          @reflection_store.add(reflection)
        end

        # Gets relevant past reflections for the current task.
        #
        # @param task [String] The current task
        # @param limit [Integer] Maximum reflections to return
        # @return [Array<Smolagents::Types::Reflection>] Relevant reflections
        def get_relevant_reflections(task, limit: 3)
          return [] unless @reflection_config&.enabled

          @reflection_store.relevant_to(task, limit:)
        end

        # Generates a reflection from a failed step.
        def generate_failure_reflection(step, task)
          error = step.error.to_s
          reflection_text = infer_reflection_from_error(error, step)

          Smolagents::Types::Reflection.from_failure(task:, step:, reflection_text:)
        end

        # Generates a reflection from a successful step.
        def generate_success_reflection(step, task)
          Smolagents::Types::Reflection.from_success(
            task:, step:, reflection_text: "This approach worked - consider reusing"
          )
        end

        ERROR_PATTERNS = [
          [
            /undefined local variable or method [`'](\w+)'/,
            ->(m) { "Define #{m[1]} before using it, or check spelling" }
          ],
          [/undefined method [`'](\w+)'/, ->(m) { "Method #{m[1]} doesn't exist - use a different approach" }],
          [/wrong number of arguments/, ->(_) { "Check the method signature and pass correct number of arguments" }],
          [/no implicit conversion/, ->(_) { "Add explicit type conversion (.to_s, .to_i, etc.)" }],
          [/syntax error/, ->(_) { "Check brackets, quotes, and keyword pairs (do/end, if/end)" }],
          [/Tool.*not found/i, ->(_) { "Use only available tools - list them first if unsure" }],
          [/timeout|timed out/i, ->(_) { "Simplify the approach or break into smaller steps" }]
        ].freeze

        def infer_reflection_from_error(error, _step)
          ERROR_PATTERNS.each { |pattern, advice| (m = error.match(pattern)) && (return advice.call(m)) }
          "Avoid this approach - try something different"
        end

        def emit_reflection_event(reflection)
          return unless defined?(Events::ReflectionRecorded)

          emit(Events::ReflectionRecorded.create(
                 outcome: reflection.outcome,
                 reflection: reflection.reflection
               ))
        end

        def log_reflection(reflection)
          return unless @logger

          @logger.debug("Reflection recorded", outcome: reflection.outcome, lesson: reflection.reflection.slice(0, 50))
        end
      end
    end
  end
end
