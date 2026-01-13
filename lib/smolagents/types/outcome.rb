module Smolagents
  module Types
    # Outcome state constants and helpers for agent run results
    module Outcome
      SUCCESS = :success
      PARTIAL = :partial
      FAILURE = :failure
      ERROR = :error
      MAX_STEPS = :max_steps_reached
      TIMEOUT = :timeout

      ALL = [SUCCESS, PARTIAL, FAILURE, ERROR, MAX_STEPS, TIMEOUT].freeze
      TERMINAL = [SUCCESS, FAILURE, ERROR, TIMEOUT].freeze
      RETRIABLE = [PARTIAL, MAX_STEPS].freeze

      class << self
        def success?(state) = state == SUCCESS
        def partial?(state) = state == PARTIAL
        def failure?(state) = state == FAILURE
        def error?(state) = state == ERROR
        def terminal?(state) = TERMINAL.include?(state)
        def retriable?(state) = RETRIABLE.include?(state)
        def valid?(state) = ALL.include?(state)

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
