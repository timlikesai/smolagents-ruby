module Smolagents
  module Concerns
    # Validates completion before allowing final_answer to end the task.
    #
    # Guards against premature completion by checking:
    # - Plan has no incomplete steps (if planning enabled)
    # - Answer aligns with original task
    # - Custom validators pass
    #
    # When validation fails, injects feedback and continues execution.
    module CompletionValidation
      # Validation result indicating rejection with reason.
      ValidationRejection = Data.define(:reason, :guidance)

      private

      # Validates completion attempt before finalizing.
      #
      # @param step [ActionStep] The step with final_answer
      # @param task [String] Original task description
      # @param memory [AgentMemory] For injecting feedback
      # @return [Boolean] true if completion allowed, false if rejected
      def validate_completion(step, task, memory:) # rubocop:disable Naming/PredicateMethod
        rejection = run_completion_validators(step, task)
        return true unless rejection

        inject_completion_rejection(rejection, memory:)
        false
      end

      # Runs all completion validators.
      #
      # @param step [ActionStep] The final answer step
      # @param task [String] Original task
      # @return [ValidationRejection, nil] Rejection or nil if valid
      def run_completion_validators(step, task)
        validate_plan_complete(step, task) ||
          validate_goal_alignment(step, task) ||
          run_custom_validators(step, task)
      end

      # Validates plan is complete (if planning enabled).
      #
      # @return [ValidationRejection, nil]
      def validate_plan_complete(_step, _task)
        return nil unless respond_to?(:plan_context, true) && @plan_context&.initialized?
        return nil if plan_steps_complete?

        ValidationRejection.new(
          reason: "Plan has incomplete steps",
          guidance: incomplete_plan_guidance
        )
      end

      # Checks if all plan steps are marked complete.
      # Override in Planning concern for actual implementation.
      def plan_steps_complete? = true

      # Guidance for incomplete plan.
      def incomplete_plan_guidance
        "Complete remaining plan steps before calling final_answer, " \
          "or update the plan if steps are no longer needed."
      end

      # Validates answer aligns with task (basic check).
      #
      # @return [ValidationRejection, nil]
      def validate_goal_alignment(step, task)
        return nil unless should_validate_goal_alignment?

        answer = step.action_output.to_s.downcase
        task_keywords = extract_task_keywords(task)

        return nil if answer_addresses_task?(answer, task_keywords)

        ValidationRejection.new(
          reason: "Answer may not address the original task",
          guidance: "Ensure your answer directly addresses: #{task.slice(0, 100)}"
        )
      end

      # Whether to check goal alignment. Override to enable.
      def should_validate_goal_alignment? = false

      # Extracts key terms from task for alignment checking.
      def extract_task_keywords(task)
        task.downcase.scan(/\b[a-z]{4,}\b/).uniq.first(5)
      end

      # Checks if answer contains task-relevant content.
      def answer_addresses_task?(answer, keywords)
        return true if keywords.empty?

        keywords.any? { |kw| answer.include?(kw) }
      end

      # Runs custom validators registered via hooks.
      #
      # @return [ValidationRejection, nil]
      def run_custom_validators(step, task)
        return nil unless respond_to?(:completion_validators, true)

        completion_validators.each do |validator|
          result = validator.call(step, task)
          return result if result.is_a?(ValidationRejection)
        end
        nil
      end

      # Injects rejection feedback into memory so model sees it.
      #
      # @param rejection [ValidationRejection] The rejection details
      # @param memory [AgentMemory] Memory to inject into
      def inject_completion_rejection(rejection, memory:)
        message = <<~MSG.strip
          [COMPLETION REJECTED] #{rejection.reason}

          #{rejection.guidance}

          Continue working on the task. Do not call final_answer until ready.
        MSG

        memory.add_system_message(message) if memory.respond_to?(:add_system_message)
        emit_completion_rejected(rejection) if respond_to?(:emit, true)
      end

      # Emits completion rejection event for observability.
      def emit_completion_rejected(rejection)
        return unless defined?(Events::CompletionRejected)

        emit(Events::CompletionRejected.create(
               reason: rejection.reason,
               guidance: rejection.guidance
             ))
      end
    end
  end
end
