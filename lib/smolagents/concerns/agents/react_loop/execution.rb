require_relative "completion"
require_relative "execution/loop"
require_relative "execution/monitoring"
require_relative "execution/streaming"

module Smolagents
  module Concerns
    module ReActLoop
      # Main loop execution, step monitoring, and fiber context management.
      #
      # Composes sub-concerns for:
      # - {Loop} - Core step iteration and completion detection
      # - {Monitoring} - Event emission, observability, instrumentation
      # - {Completion} - Result building and cleanup
      #
      # == Extension Points (No-op Stubs)
      #
      # Execution defines no-op stub methods that opt-in concerns override:
      #
      #   | Stub Method                      | Overriding Concern | Purpose                    |
      #   |----------------------------------|--------------------|----------------------------|
      #   | should_execute_initial_planning? | Planning           | Pre-act planning predicate |
      #   | should_execute_planning_update?  | Planning           | Periodic replanning check  |
      #   | execute_initial_planning         | Planning           | Pre-act planning action    |
      #   | execute_planning_update          | Planning           | Periodic replanning action |
      #   | check_and_handle_repetition      | Repetition         | Loop detection             |
      #   | execute_evaluation_if_needed     | Evaluation         | Metacognition phase        |
      #
      # This stub pattern allows concerns to be layered without tight coupling.
      # Include the opt-in concern AFTER ReActLoop to override the stub.
      #
      # == Fiber Context
      #
      # The execution loop runs within a Fiber context tracked via Thread-local:
      # - Uses thread_variable_set for true thread-local storage (not fiber-local)
      # - Control concern methods check this before yielding
      #
      # @see Core For run entry points
      # @see Loop For step iteration logic
      # @see Monitoring For event emission and observability
      # @see Completion For result building
      # @see Planning For execute_planning_update override
      # @see Repetition For check_and_handle_repetition override
      # @see Evaluation For execute_evaluation_if_needed override
      module Execution
        def self.included(base)
          base.include(Completion)
          base.include(Loop)
          base.include(Monitoring)
        end
      end
    end
  end
end
