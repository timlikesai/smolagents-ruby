module Smolagents
  module Types
    # Outcome state constants and helpers for agent run results.
    #
    # Outcome provides a standardized set of terminal states for agent task
    # execution, along with predicates and terminal/retriable classifications.
    # Used in RunResult and ExecutionOutcome for consistent state management.
    #
    # @example Checking outcome state
    #   if Outcome.success?(result.state)
    #     puts "Task completed successfully"
    #   elsif Outcome.retriable?(result.state)
    #     puts "Task partially succeeded, can retry"
    #   end
    #
    # @see RunResult#success?, #failure?, #error?, etc. For runnable predicates
    # @see ExecutionOutcome For event-driven outcome handling
    module Outcome
      # Task completed successfully.
      SUCCESS = :success

      # Task partially succeeded (some goals met, others not).
      PARTIAL = :partial

      # Task failed to meet objectives.
      FAILURE = :failure

      # Task failed with an exception.
      ERROR = :error

      # Task exceeded maximum step limit.
      MAX_STEPS = :max_steps_reached

      # Task execution timed out.
      TIMEOUT = :timeout

      # @return [Array<Symbol>] All valid outcome states
      ALL = [SUCCESS, PARTIAL, FAILURE, ERROR, MAX_STEPS, TIMEOUT].freeze

      # @return [Array<Symbol>] Terminal states (execution ended)
      TERMINAL = [SUCCESS, FAILURE, ERROR, TIMEOUT].freeze

      # @return [Array<Symbol>] Retriable states (can be retried)
      RETRIABLE = [PARTIAL, MAX_STEPS].freeze

      class << self
        # Checks if outcome is success.
        #
        # @param state [Symbol] Outcome state to check
        # @return [Boolean] True if state is :success
        # @example
        #   Outcome.success?(:success)  # => true
        def success?(state) = state == SUCCESS

        # Checks if outcome is partial (partially succeeded).
        #
        # @param state [Symbol] Outcome state to check
        # @return [Boolean] True if state is :partial
        # @example
        #   Outcome.partial?(:partial)  # => true
        def partial?(state) = state == PARTIAL

        # Checks if outcome is failure.
        #
        # @param state [Symbol] Outcome state to check
        # @return [Boolean] True if state is :failure
        # @example
        #   Outcome.failure?(:failure)  # => true
        def failure?(state) = state == FAILURE

        # Checks if outcome is error.
        #
        # @param state [Symbol] Outcome state to check
        # @return [Boolean] True if state is :error
        # @example
        #   Outcome.error?(:error)  # => true
        def error?(state) = state == ERROR

        # Checks if outcome is terminal (execution ended).
        #
        # Terminal states cannot be retried or resumed.
        #
        # @param state [Symbol] Outcome state to check
        # @return [Boolean] True if state is in TERMINAL set
        # @example
        #   Outcome.terminal?(:success)  # => true
        #   Outcome.terminal?(:partial)  # => false
        def terminal?(state) = TERMINAL.include?(state)

        # Checks if outcome is retriable (can be retried).
        #
        # Retriable states indicate partial progress that can be resumed.
        #
        # @param state [Symbol] Outcome state to check
        # @return [Boolean] True if state is in RETRIABLE set
        # @example
        #   Outcome.retriable?(:partial)  # => true
        #   Outcome.retriable?(:max_steps_reached)  # => true
        #   Outcome.retriable?(:success)  # => false
        def retriable?(state) = RETRIABLE.include?(state)

        # Validates if state is a known outcome.
        #
        # @param state [Symbol] Outcome state to check
        # @return [Boolean] True if state is in ALL set
        # @example
        #   Outcome.valid?(:success)  # => true
        #   Outcome.valid?(:unknown)  # => false
        def valid?(state) = ALL.include?(state)

        # Determines outcome from a RunResult, with optional error override.
        #
        # Useful for deriving outcome from task execution results.
        #
        # @param run_result [RunResult] The execution result
        # @param error [StandardError, nil] Override error to force ERROR state
        # @return [Symbol] Derived outcome state
        # @example
        #   Outcome.from_run_result(result, error: RuntimeError.new("oops"))
        #   # => :error
        def from_run_result(run_result, error: nil)
          return ERROR if error

          case run_result.state
          when MAX_STEPS then MAX_STEPS
          when SUCCESS then SUCCESS
          else FAILURE
          end
        end
      end
    end
  end
end
