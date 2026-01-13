module Smolagents
  module Types
    # Outcome for agent step execution with step-specific context.
    #
    # CONTAINS ActionStep data - composition pattern.
    # Adds state machine layer on top of ActionStep's comprehensive step data.
    #
    # @example Pattern matching on step outcome
    #   case outcome
    #   in StepExecutionOutcome[state: :final_answer, step:]
    #     return finalize(:success, step.action_output, context)
    #   in StepExecutionOutcome[state: :success, step:]
    #     continue_loop(step.step_number + 1)
    #   in StepExecutionOutcome[state: :error, error:, step:]
    #     handle_step_error(step.step_number, error)
    #   end
    #
    # @example Creating from ActionStep
    #   action_step = ActionStep.new(step_number: 1, observations: "...")
    #   outcome = StepExecutionOutcome.from_step(action_step, duration: 1.5)
    #
    StepExecutionOutcome = Data.define(
      :state, :value, :error, :duration, :metadata,
      :step # ActionStep (contains step_number, timing, tool_calls, observations, etc.)
    ) do
      # Predicate methods from base ExecutionOutcome
      def success? = state == :success
      def final_answer? = state == :final_answer
      def error? = state == :error
      def max_steps? = state == :max_steps_reached
      def timeout? = state == :timeout
      def completed? = success? || final_answer?
      def failed? = error? || max_steps? || timeout?

      # Delegates to contained step
      def step_number = step&.step_number
      def observations = step&.observations
      def tool_calls = step&.tool_calls
      def code_action = step&.code_action

      # Creates outcome from ActionStep
      # @param step [ActionStep] The action step
      # @param duration [Float] Step execution time in seconds
      # @param metadata [Hash] Additional context
      # @return [StepExecutionOutcome]
      def self.from_step(step, duration: 0.0, metadata: {})
        state = if step.is_final_answer
                  :final_answer
                elsif step.error
                  :error
                else
                  :success
                end

        new(
          state: state,
          value: step.action_output,
          error: step.error.is_a?(String) ? StandardError.new(step.error) : step.error,
          duration: duration,
          metadata: metadata,
          step: step
        )
      end

      def to_event_payload
        {
          outcome: state,
          duration: duration,
          timestamp: Time.now.utc.iso8601,
          metadata: metadata,
          step_number: step&.step_number,
          observations: step&.observations,
          tool_calls: step&.tool_calls&.map(&:to_h)
        }.tap do |payload|
          payload[:value] = value if completed?
          payload[:error] = error.class.name if error?
          payload[:error_message] = error.message if error?
        end
      end
    end
  end
end
