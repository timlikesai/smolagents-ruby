# Event participation pattern documentation.
#
# Components that need both event emission and consumption should include
# both modules separately:
#
#   class MyAgent
#     include Events::Emitter   # emit, emit!, emit_error
#     include Events::Consumer  # on, on_*, consume
#
#     def initialize
#       on(:error_occurred) { |e| log_error(e) }
#     end
#
#     def run(task)
#       emit :task_lifecycle, phase: :started, task: task
#       result = process(task)
#       emit :task_lifecycle, phase: :completed, outcome: :success, output: result
#     end
#   end
#
# This pattern follows Ruby's composition over inheritance principle.
# Each module provides a focused set of capabilities:
#
# - Emitter: Symbol-based emission, block timing, sync/async dispatch
# - Consumer: Multi-event subscription, category handlers, keyword destructuring
#
# See lib/smolagents/orchestrators/event_orchestrator.rb for a real example.
