module Smolagents
  module Types
    # Constants and helpers for agent run outcomes.
    #
    # Outcome defines the possible states an agent run can complete with,
    # along with classification methods to check outcome categories.
    #
    # @example Checking outcome state
    #   if Types::Outcome.success?(result.state)
    #     puts "Task completed successfully"
    #   elsif Types::Outcome.retriable?(result.state)
    #     puts "Task can be retried"
    #   end
    #
    # @see RunResult Uses outcomes to report run state
    module Outcome
      SUCCESS = :success
      PARTIAL = :partial
      FAILURE = :failure
      ERROR = :error
      MAX_STEPS = :max_steps
      TIMEOUT = :timeout

      ALL = [SUCCESS, PARTIAL, FAILURE, ERROR, MAX_STEPS, TIMEOUT].freeze
      TERMINAL = [SUCCESS, FAILURE, ERROR, TIMEOUT].freeze
      RETRIABLE = [PARTIAL, MAX_STEPS].freeze

      class << self
        def success?(state) = state == SUCCESS
        def partial?(state) = state == PARTIAL
        def failure?(state) = state == FAILURE
        def error?(state) = state == ERROR
        def max_steps?(state) = state == MAX_STEPS
        def timeout?(state) = state == TIMEOUT

        def terminal?(state) = TERMINAL.include?(state)
        def retriable?(state) = RETRIABLE.include?(state)
        def valid?(state) = ALL.include?(state)

        def from_run_result(result, error: nil)
          return ERROR if error
          return MAX_STEPS if result.state == :max_steps_reached
          return SUCCESS if result.success?

          FAILURE
        end
      end
    end
  end
end
