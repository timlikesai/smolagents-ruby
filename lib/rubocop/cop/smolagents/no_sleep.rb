# Custom RuboCop cop to enforce event-driven architecture
# Sleep calls indicate timing-dependent code which violates our evented design

module RuboCop
  module Cop
    module Smolagents
      # Forbids use of sleep in the codebase.
      #
      # Sleep calls create timing dependencies that make code:
      # - Non-deterministic and flaky in tests
      # - Slow (blocking instead of event-driven)
      # - Difficult to test (requires real elapsed time)
      #
      # Instead, use event-driven patterns:
      # - Thread::Queue for coordination
      # - ConditionVariable for synchronization
      # - Callbacks/events for async completion
      #
      # @example Bad
      #   sleep(1)
      #   sleep 0.5
      #   Kernel.sleep(2)
      #
      # @example Good - Event-driven coordination
      #   queue = Thread::Queue.new
      #   # ... work happens ...
      #   queue.pop  # blocks until event arrives
      #
      # @example Good - Condition variable
      #   mutex.synchronize do
      #     condition.wait(mutex)  # waits for signal, not time
      #   end
      #
      class NoSleep < Base
        MSG = "Avoid `sleep` - use event-driven patterns (Queue, ConditionVariable, callbacks) " \
              "instead of timing-based coordination. Sleep makes code non-deterministic and slow.".freeze

        RESTRICT_ON_SEND = %i[sleep].freeze

        # @!method sleep_call?(node)
        def_node_matcher :sleep_call?, <<~PATTERN
          (send {nil? (const nil? :Kernel)} :sleep ...)
        PATTERN

        def on_send(node)
          return unless sleep_call?(node)

          add_offense(node)
        end
      end
    end
  end
end
