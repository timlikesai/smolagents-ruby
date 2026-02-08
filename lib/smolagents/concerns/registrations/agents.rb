# Agent concern registrations.
module Smolagents
  module Concerns
    Registry.tap do |r| # rubocop:disable Metrics/BlockLength -- registration data
      r.register :react_loop,
                 Smolagents::Concerns::ReActLoop,
                 category: :agents,
                 dependencies: %i[events_emitter events_consumer],
                 provides: %i[run run_fiber setup_agent tools model memory max_steps state],
                 description: "Event-driven ReAct loop for agent execution"

      r.register :react_loop_control,
                 Smolagents::Concerns::ReActLoop::Control,
                 category: :agents,
                 dependencies: [:react_loop],
                 provides: %i[request_input request_confirmation escalate_query],
                 description: "Fiber-based bidirectional control flow"

      r.register :react_loop_repetition,
                 Smolagents::Concerns::ReActLoop::Repetition,
                 category: :agents,
                 dependencies: [:react_loop],
                 provides: %i[check_repetition repetition_detected?],
                 description: "Loop detection for stuck agents"

      r.register :planning,
                 Smolagents::Concerns::Planning,
                 category: :agents,
                 dependencies: [:react_loop],
                 provides: %i[current_plan plan_context planning_interval],
                 description: "Pre-Act planning with periodic updates"

      r.register :evaluation,
                 Smolagents::Concerns::Evaluation,
                 category: :agents,
                 dependencies: [:react_loop],
                 provides: %i[evaluate_progress parse_evaluation],
                 description: "Metacognition phase for progress assessment"

      r.register :self_refine,
                 Smolagents::Concerns::SelfRefine,
                 category: :agents,
                 provides: %i[refine_answer should_refine?],
                 description: "Iterative answer improvement loop"

      r.register :reflection_memory,
                 Smolagents::Concerns::ReflectionMemory,
                 category: :agents,
                 provides: %i[store_reflection retrieve_reflections],
                 description: "Cross-run learning and memory"

      r.register :managed_agents,
                 Smolagents::Concerns::ManagedAgents,
                 category: :agents,
                 provides: %i[managed_agents delegate_to_agent],
                 description: "Sub-agent delegation and orchestration"

      r.register :async_tools,
                 Smolagents::Concerns::AsyncTools,
                 category: :agents,
                 provides: %i[parallel_execute await_all],
                 description: "Parallel tool execution"

      r.register :early_yield,
                 Smolagents::Concerns::EarlyYield,
                 category: :agents,
                 provides: %i[yield_early speculative_execute],
                 description: "Speculative execution with early results"

      r.register :goal_tracking,
                 Smolagents::Concerns::GoalTracking,
                 category: :agents,
                 provides: %i[current_goal create_goal complete_goal],
                 description: "Goal hierarchy and progress tracking"

      r.register :goal_driven_loop,
                 Smolagents::Concerns::GoalDrivenLoop,
                 category: :agents,
                 dependencies: %i[react_loop goal_tracking],
                 provides: %i[goal_driven_iteration],
                 description: "Goal-aware loop iteration and completion"

      r.register :goal_aware_yield,
                 Smolagents::Concerns::GoalAwareYield,
                 category: :agents,
                 dependencies: %i[early_yield goal_tracking],
                 provides: %i[execute_tools_for_goal],
                 description: "Goal-aware early yield for parallel tools"

      r.register :working_memory,
                 Smolagents::Concerns::WorkingMemory,
                 category: :agents,
                 provides: %i[working_memory update_objective record_finding],
                 description: "Persistent context that survives truncation"

      r.register :task_coordination,
                 Smolagents::Concerns::Agents::TaskCoordination,
                 category: :agents,
                 dependencies: %i[events_emitter],
                 provides: %i[task_coordinator run_coordinated declare_task task_status],
                 description: "Declarative task management with dependencies"

      r.register :stats_tracking,
                 Smolagents::Concerns::StatsTracking,
                 category: :agents,
                 dependencies: %i[events_consumer],
                 provides: %i[stats],
                 description: "Runtime statistics accumulation from events"

      r.register :verbose_subscriber,
                 Smolagents::Concerns::VerboseSubscriber,
                 category: :agents,
                 dependencies: %i[events_consumer],
                 provides: %i[],
                 description: "Human-readable event logging for debugging"
    end
  end
end
