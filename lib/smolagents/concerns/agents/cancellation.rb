module Smolagents
  module Concerns
    # Cancellation support for agent execution.
    #
    # Creates a cancellation token on run start. External callers
    # can invoke +cancel!+ to request graceful termination.
    # The loop checks at step boundaries via +check_cancellation+.
    #
    # @example
    #   agent = Smolagents.agent.model { m }.build
    #   thread = Thread.new { agent.run("long task") }
    #   agent.cancel!  # graceful stop at next step boundary
    module Cancellation
      # @return [Types::CancellationToken, nil] Current token
      attr_reader :cancellation_token

      def self.included(base)
        base.include(Events::Emitter) unless base < Events::Emitter
      end

      # Request cancellation of the current run.
      # @return [void]
      def cancel!
        @cancellation_token&.cancel!
      end

      # Whether the agent is cancelled.
      # @return [Boolean]
      def cancelled? = @cancellation_token&.cancelled? || false

      private

      # Initialize a fresh cancellation token for each run.
      # Called from prepare_run override.
      def initialize_cancellation
        @cancellation_token = Types::CancellationToken.new
      end

      # Check cancellation status at step boundary.
      # @return [Types::RunResult, nil] Cancelled result or nil to continue
      def check_cancellation_if_enabled
        return unless @cancellation_token&.cancelled?

        emit :task_lifecycle, phase: :completed, outcome: :cancelled,
                              agent_name: self.class.name, steps_taken: @ctx&.step_number
        finalize(:cancelled, nil, @ctx, memory: @memory)
      end
    end
  end
end
