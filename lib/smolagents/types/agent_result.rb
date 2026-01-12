module Smolagents
  AgentResult = Data.define(
    :agent_name,
    :output,
    :outcome,
    :error,
    :timing,
    :token_usage,
    :steps_taken,
    :trace_id
  ) do
    def initialize(
      agent_name:,
      output:,
      outcome: Outcome::SUCCESS,
      error: nil,
      timing: nil,
      token_usage: nil,
      steps_taken: 0,
      trace_id: nil
    )
      super
    end

    def success? = Outcome.success?(outcome)
    def partial? = Outcome.partial?(outcome)
    def failure? = Outcome.failure?(outcome)
    def error? = Outcome.error?(outcome)

    def duration_seconds
      timing&.duration || 0.0
    end

    def input_tokens
      token_usage&.input_tokens || 0
    end

    def output_tokens
      token_usage&.output_tokens || 0
    end

    def total_tokens
      input_tokens + output_tokens
    end

    def to_h
      {
        agent_name:,
        output:,
        outcome:,
        error: error&.message || error,
        timing: timing&.to_h,
        token_usage: token_usage&.to_h,
        steps_taken:,
        trace_id:
      }.compact
    end

    class << self
      def from_run_result(run_result, agent_name:, trace_id: nil, error: nil)
        new(
          agent_name: agent_name,
          output: run_result.output,
          outcome: Outcome.from_run_result(run_result, error: error),
          error: error,
          timing: run_result.timing,
          token_usage: run_result.token_usage,
          steps_taken: run_result.steps&.size || 0,
          trace_id: trace_id
        )
      end
    end
  end
end
