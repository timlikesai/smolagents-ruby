module Smolagents
  module Types
    # Record of a sub-agent run within an observability context.
    #
    # Tracks metrics from sub-agent executions for hierarchical observability,
    # including token usage, step count, duration, and outcome.
    #
    # @!attribute [r] agent_name
    #   @return [String] Name/identifier of the sub-agent
    # @!attribute [r] token_usage
    #   @return [TokenUsage] Tokens consumed by this sub-agent
    # @!attribute [r] step_count
    #   @return [Integer] Number of steps executed
    # @!attribute [r] duration
    #   @return [Float] Execution duration in seconds
    # @!attribute [r] outcome
    #   @return [Symbol] Execution outcome (:success, :error, etc.)
    # @!attribute [r] timestamp
    #   @return [String] ISO8601 timestamp of completion
    #
    # @example Creating a sub-agent record
    #   record = SubAgentRecord.new(
    #     agent_name: "researcher",
    #     token_usage: TokenUsage.new(input_tokens: 100, output_tokens: 50),
    #     step_count: 3,
    #     duration: 2.5,
    #     outcome: :success,
    #     timestamp: Time.now.utc.iso8601
    #   )
    #
    # @see Types::ObservabilityContext For hierarchical tracking
    SubAgentRecord = Data.define(:agent_name, :token_usage, :step_count, :duration, :outcome, :timestamp) do
      include TypeSupport::Deconstructable
      include TypeSupport::Serializable
      include TypeSupport::StatePredicates

      state_predicates :outcome, success: :success, error: :error
    end
  end
end
