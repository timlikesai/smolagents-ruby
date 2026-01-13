module Smolagents
  module Types
    # Outcome for complete agent execution (agent run).
    #
    # CONTAINS RunResult data - composition pattern.
    # Adds state machine layer on top of RunResult's agent execution data.
    # Task is the INPUT (what to do), AgentExecutionOutcome is the RESULT.
    #
    # @example Pattern matching on agent outcome
    #   case outcome
    #   in AgentExecutionOutcome[state: :success, run_result:]
    #     puts "Completed: #{run_result.output}"
    #   in AgentExecutionOutcome[state: :max_steps_reached, run_result:]
    #     puts "Max steps reached after #{run_result.steps.size} steps"
    #   in AgentExecutionOutcome[state: :error, error:, run_result:]
    #     handle_agent_error(error, run_result.steps)
    #   end
    #
    # @example Creating from RunResult
    #   run_result = RunResult.new(output: "answer", state: :success, ...)
    #   outcome = AgentExecutionOutcome.from_run_result(run_result, task: "Calculate 2+2")
    #
    AgentExecutionOutcome = Data.define(
      :state, :value, :error, :duration, :metadata,
      :run_result # RunResult (contains output, state, steps, token_usage, timing)
    ) do
      # Predicate methods from base ExecutionOutcome
      def success? = state == :success
      def final_answer? = state == :final_answer
      def error? = state == :error
      def max_steps? = state == :max_steps_reached
      def timeout? = state == :timeout
      def completed? = success? || final_answer?
      def failed? = error? || max_steps? || timeout?

      # Delegates to contained run result
      def output = run_result&.output
      def steps = run_result&.steps
      def token_usage = run_result&.token_usage

      # Creates outcome from RunResult
      # @param run_result [RunResult] The agent run result
      # @param task [String] The original task
      # @param error [Exception, nil] Error if execution failed
      # @param metadata [Hash] Additional context
      # @return [AgentExecutionOutcome]
      def self.from_run_result(run_result, task: nil, error: nil, metadata: {})
        # Map RunResult state to ExecutionOutcome state
        state = case run_result.state
                when :success then :success
                when :max_steps_reached then :max_steps_reached
                when :error then :error
                else run_result.state
                end

        new(
          state: state,
          value: run_result.output,
          error: error,
          duration: run_result.timing&.duration || 0.0,
          metadata: metadata.merge(task: task),
          run_result: run_result
        )
      end

      def to_event_payload
        {
          outcome: state,
          duration: duration,
          timestamp: Time.now.utc.iso8601,
          metadata: metadata,
          output: run_result&.output,
          steps_taken: run_result&.steps&.size || 0,
          tokens: run_result&.token_usage&.to_h
        }.tap do |payload|
          payload[:value] = value if completed?
          payload[:error] = error.class.name if error?
          payload[:error_message] = error.message if error?
        end
      end
    end
  end
end
