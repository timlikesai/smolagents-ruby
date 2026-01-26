# Custom RuboCop cop to prevent Timeout.timeout usage
# Timeout blocks are dangerous and indicate timing-dependent code

module RuboCop
  module Cop
    module Smolagents
      # Forbids use of Timeout.timeout blocks.
      #
      # Timeout.timeout is problematic because:
      # - It uses Thread.raise which can corrupt state
      # - It creates timing-dependent behavior
      # - It's often used as a band-aid for poor async design
      #
      # Instead, use:
      # - Event-driven patterns with explicit completion signals
      # - Process-level timeouts for external commands (Thread.join with timeout)
      # - Circuit breakers for external service calls
      #
      # @example Bad
      #   Timeout.timeout(5) { do_work }
      #   Timeout::timeout(10) { api_call }
      #
      # @example Good - Process-level timeout
      #   thread = Thread.new { do_work }
      #   thread.join(5) || thread.kill
      #
      # @example Good - Circuit breaker
      #   Stoplight("api_call") { api_call }.run
      #
      # @example Good - Event-driven
      #   queue = Thread::Queue.new
      #   worker.on_complete { queue.push(:done) }
      #   result = queue.pop  # blocks until complete
      #
      class NoTimeoutBlock < Base
        MSG = "Avoid `Timeout.timeout` - it uses Thread.raise which can corrupt state. " \
              "Use event-driven patterns, circuit breakers (Stoplight), or process-level " \
              "timeouts (Thread.join) instead.".freeze

        RESTRICT_ON_SEND = %i[timeout].freeze

        # @!method timeout_call?(node)
        def_node_matcher :timeout_call?, <<~PATTERN
          (send
            (const {nil? (cbase)} :Timeout)
            :timeout
            ...)
        PATTERN

        def on_send(node)
          return unless timeout_call?(node)

          add_offense(node)
        end
      end
    end
  end
end
