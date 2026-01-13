module Smolagents
  # Immutable result from agent execution.
  #
  # AgentResult captures all relevant information from an agent's execution,
  # including the output, success/failure status, performance metrics, and
  # tracing information.
  #
  # @example Successful result
  #   result = AgentResult.new(
  #     agent_name: "calculator",
  #     output: "42",
  #     outcome: Outcome::SUCCESS,
  #     steps_taken: 3
  #   )
  #   result.success?  # => true
  #
  # @example Checking result status
  #   if result.success?
  #     puts result.output
  #   elsif result.error?
  #     puts "Error: #{result.error}"
  #   end
  #
  # @example From RunResult
  #   result = AgentResult.from_run_result(run_result,
  #     agent_name: "my_agent",
  #     trace_id: "abc-123"
  #   )
  #
  # @see Outcome For outcome values (SUCCESS, PARTIAL, FAILURE, ERROR)
  # @see Timing For timing information structure
  # @see TokenUsage For token usage tracking
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
    # Creates a new AgentResult with default values.
    #
    # @param agent_name [String] Name of the agent that produced this result
    # @param output [Object] The agent's output value
    # @param outcome [Symbol] Outcome status (default: Outcome::SUCCESS)
    # @param error [Exception, String, nil] Error if execution failed
    # @param timing [Timing, nil] Execution timing information
    # @param token_usage [TokenUsage, nil] Token consumption metrics
    # @param steps_taken [Integer] Number of steps executed (default: 0)
    # @param trace_id [String, nil] Unique trace identifier for logging
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

    # @return [Boolean] True if outcome is SUCCESS
    def success? = Outcome.success?(outcome)

    # @return [Boolean] True if outcome is PARTIAL
    def partial? = Outcome.partial?(outcome)

    # @return [Boolean] True if outcome is FAILURE
    def failure? = Outcome.failure?(outcome)

    # @return [Boolean] True if outcome is ERROR
    def error? = Outcome.error?(outcome)

    # @return [Float] Execution duration in seconds, or 0.0 if not tracked
    def duration_seconds
      timing&.duration || 0.0
    end

    # @return [Integer] Number of input tokens consumed, or 0 if not tracked
    def input_tokens
      token_usage&.input_tokens || 0
    end

    # @return [Integer] Number of output tokens generated, or 0 if not tracked
    def output_tokens
      token_usage&.output_tokens || 0
    end

    # @return [Integer] Total tokens (input + output)
    def total_tokens
      input_tokens + output_tokens
    end

    # Converts the result to a hash for serialization.
    # @return [Hash] Result as a hash
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
      # Creates an AgentResult from a RunResult.
      #
      # Extracts relevant fields from a RunResult and converts to AgentResult.
      # Determines outcome based on the run result state and any error.
      #
      # @param run_result [RunResult] The raw run result from agent execution
      # @param agent_name [String] Name to assign to the result
      # @param trace_id [String, nil] Optional trace identifier
      # @param error [Exception, nil] Optional error to include
      # @return [AgentResult] Converted result
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
