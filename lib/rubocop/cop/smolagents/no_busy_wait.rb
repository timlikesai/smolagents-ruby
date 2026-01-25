# Custom RuboCop cop to detect busy-wait and polling patterns
# These patterns indicate non-event-driven code that wastes CPU and is slow

module RuboCop
  module Cop
    module Smolagents
      # Detects busy-wait loops that poll for conditions.
      #
      # Busy-wait patterns waste CPU cycles and create timing-dependent code.
      # Instead, use proper synchronization primitives that block efficiently.
      #
      # @example Bad - Polling loop with sleep
      #   loop do
      #     break if condition_met?
      #     sleep 0.1
      #   end
      #
      # @example Bad - Time-based loop
      #   deadline = Time.now + 5
      #   while Time.now < deadline
      #     break if ready?
      #   end
      #
      # @example Good - Queue-based waiting
      #   queue = Queue.new
      #   # producer: queue.push(result)
      #   result = queue.pop  # blocks until ready
      #
      # @example Good - ConditionVariable (no timeout)
      #   mutex.synchronize do
      #     cv.wait(mutex) until condition_met?
      #   end
      #
      class NoBusyWait < Base
        MSG = <<~MSG.gsub("\n", " ").strip
          Avoid busy-wait loops. Use Queue.pop for blocking wait,
          or ConditionVariable.wait (without timeout) for condition-based waiting.
          Busy-wait wastes CPU and creates timing-dependent code.
        MSG

        # Detect: while Time.now < something
        # @!method time_comparison_loop?(node)
        def_node_matcher :time_comparison_loop?, <<~PATTERN
          (while
            (send (send {nil? (const nil? :Time)} :now) ${:< :> :<= :>=} ...)
            ...)
        PATTERN

        # Detect: until Time.now > something
        # @!method until_time_loop?(node)
        def_node_matcher :until_time_loop?, <<~PATTERN
          (until
            (send (send {nil? (const nil? :Time)} :now) ${:< :> :<= :>=} ...)
            ...)
        PATTERN

        def on_while(node)
          add_offense(node) if time_comparison_loop?(node)
        end

        def on_until(node)
          add_offense(node) if until_time_loop?(node)
        end
      end
    end
  end
end
