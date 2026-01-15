module Smolagents
  module Types
    # Outcome state constants and predicates for agent execution results.
    #
    # Provides standardized terminal states for agent task execution with
    # predicates for state checking and classification (terminal, retriable,
    # completed, failed).
    #
    # @example State checking
    #   Outcome.success?(:success)     # => true
    #   Outcome.completed?(:final_answer)  # => true
    #   Outcome.failed?(:error)        # => true
    #
    # @example Classification
    #   Outcome.terminal?(:success)    # => true  (can't continue)
    #   Outcome.retriable?(:partial)   # => true  (can resume)
    #
    # @see ExecutionOutcome For event-driven outcome handling
    # @see OutcomePredicates For instance-level predicates
    module Outcome
      # Individual states
      SUCCESS      = :success
      PARTIAL      = :partial
      FAILURE      = :failure
      ERROR        = :error
      MAX_STEPS    = :max_steps_reached
      TIMEOUT      = :timeout
      FINAL_ANSWER = :final_answer

      # State groupings
      ALL       = [SUCCESS, PARTIAL, FAILURE, ERROR, MAX_STEPS, TIMEOUT, FINAL_ANSWER].freeze
      TERMINAL  = [SUCCESS, FAILURE, ERROR, TIMEOUT, FINAL_ANSWER].freeze
      RETRIABLE = [PARTIAL, MAX_STEPS].freeze
      COMPLETED = [SUCCESS, FINAL_ANSWER].freeze
      FAILED    = [FAILURE, ERROR, MAX_STEPS, TIMEOUT].freeze

      class << self
        # Individual state predicates
        def success?(state)      = state == SUCCESS
        def partial?(state)      = state == PARTIAL
        def failure?(state)      = state == FAILURE
        def error?(state)        = state == ERROR
        def max_steps?(state)    = state == MAX_STEPS
        def timeout?(state)      = state == TIMEOUT
        def final_answer?(state) = state == FINAL_ANSWER

        # Group predicates
        def terminal?(state)  = TERMINAL.include?(state)
        def retriable?(state) = RETRIABLE.include?(state)
        def completed?(state) = COMPLETED.include?(state)
        def failed?(state)    = FAILED.include?(state)
        def valid?(state)     = ALL.include?(state)

        # Derives outcome from a RunResult.
        #
        # @param run_result [RunResult] The execution result
        # @param error [StandardError, nil] Override error to force ERROR state
        # @return [Symbol] Derived outcome state
        def from_run_result(run_result, error: nil)
          return ERROR if error

          valid?(run_result.state) ? run_result.state : FAILURE
        end

        # Pattern matching support for case/in expressions.
        #
        # @example Pattern matching on outcome groups
        #   case outcome_state
        #   in state if Outcome.completed?(state) then handle_success
        #   in state if Outcome.failed?(state) then handle_failure
        #   end
        def ===(state) = valid?(state)
      end
    end
  end
end
