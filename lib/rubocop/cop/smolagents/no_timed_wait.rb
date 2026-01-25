# Custom RuboCop cop to detect timed wait patterns
# Timed waits indicate non-event-driven code

module RuboCop
  module Cop
    module Smolagents
      # Detects timed waits that should use event-driven patterns instead.
      #
      # Thread.join(timeout), ConditionVariable.wait(mutex, timeout), and
      # similar patterns create timing-dependent code. Use proper event-driven
      # synchronization that completes based on events, not elapsed time.
      #
      # @example Bad - Thread.join with timeout
      #   thread.join(5)  # waits up to 5 seconds
      #
      # @example Bad - ConditionVariable.wait with timeout
      #   cv.wait(mutex, 10)  # waits up to 10 seconds
      #
      # @example Good - Thread.join (blocks until done)
      #   thread.join  # blocks until thread completes
      #
      # @example Good - Queue for completion signal
      #   done_queue = Queue.new
      #   Thread.new { work; done_queue.push(:done) }
      #   done_queue.pop  # blocks until signaled
      #
      # @example Good - ConditionVariable without timeout
      #   mutex.synchronize do
      #     cv.wait(mutex) until ready?
      #   end
      #
      class NoTimedWait < Base
        TIMED_JOIN_MSG = <<~MSG.gsub("\n", " ").strip
          Avoid Thread.join(timeout). Use Queue.pop for completion signaling,
          or thread.join without timeout if the thread must complete.
          Timed joins create flaky, timing-dependent code.
        MSG

        TIMED_CV_WAIT_MSG = <<~MSG.gsub("\n", " ").strip
          Avoid ConditionVariable.wait(mutex, timeout). Use cv.wait(mutex) with
          a condition loop, or Queue.pop for simpler cases.
          Timed waits create flaky, timing-dependent code.
        MSG

        RESTRICT_ON_SEND = %i[join wait].freeze

        # @!method thread_join_with_timeout?(node)
        def_node_matcher :thread_join_with_timeout?, <<~PATTERN
          (send _ :join (int _))
        PATTERN

        # @!method thread_join_with_float_timeout?(node)
        def_node_matcher :thread_join_with_float_timeout?, <<~PATTERN
          (send _ :join (float _))
        PATTERN

        # @!method cv_wait_with_timeout?(node)
        def_node_matcher :cv_wait_with_timeout?, <<~PATTERN
          (send _ :wait _ {(int _) (float _)})
        PATTERN

        def on_send(node)
          if thread_join_with_timeout?(node) || thread_join_with_float_timeout?(node)
            add_offense(node, message: TIMED_JOIN_MSG)
          elsif cv_wait_with_timeout?(node)
            add_offense(node, message: TIMED_CV_WAIT_MSG)
          end
        end
      end
    end
  end
end
