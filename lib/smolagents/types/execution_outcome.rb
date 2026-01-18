require_relative "execution_outcome/predicates"
require_relative "execution_outcome/builders"
require_relative "execution_outcome/event_serialization"
require_relative "execution_outcome/value_unwrapping"

module Smolagents
  module Types
    # Backwards compatibility alias for code using OutcomePredicates directly
    OutcomePredicates = OutcomeComponents::Predicates

    # Immutable execution outcome for any operation.
    #
    # ExecutionOutcome is the foundation of smolagents' event-driven architecture.
    # Every operation produces an outcome, which flows through the system via events.
    #
    # Use the `metadata` field to store domain-specific data (tool name, step number,
    # run result, etc.) rather than creating specialized subclasses.
    #
    # @example Pattern matching
    #   case outcome
    #   in ExecutionOutcome[state: :success, value:]
    #     puts "Success: #{value}"
    #   in ExecutionOutcome[state: :error, error:]
    #     puts "Error: #{error.message}"
    #   end
    #
    # @example With domain-specific metadata
    #   outcome = ExecutionOutcome.success(value, metadata: { tool_name: "search" })
    #
    ExecutionOutcome = Data.define(
      :state,      # :success, :final_answer, :error, :max_steps_reached, :timeout
      :value,      # The successful result value (for :success, :final_answer)
      :error,      # The error object (for :error)
      :duration,   # Execution time in seconds
      :metadata    # Additional context (Hash) for domain-specific data
    ) do
      include TypeSupport::Deconstructable
      include OutcomeComponents::Predicates
      include OutcomeComponents::EventSerialization
      include OutcomeComponents::ValueUnwrapping
      extend OutcomeComponents::Builders
    end
  end
end
