# Event Consolidation Plan: G.1.2

**Goal:** Consolidate 72 events → ~45 using the lifecycle pattern (phase: field discriminator).
**Approach:** Merge groups of 2-4 related events into single lifecycle events with `phase:` predicates.
**Constraint:** User-facing events (in `Registry.for_builder`) are NOT merged to preserve API stability.

---

## User-Facing Events (NOT MERGED)

These events are exposed via `Registry.for_builder` or legacy aliases — keep separate:

| Event | Builder | Why Keep |
|-------|---------|----------|
| StepCompleted | :agent | Interactive.rb consumer |
| ToolCallRequested | - | Distinct from completed |
| ToolCallCompleted | :agent | Interactive.rb consumer |
| ToolRetrying | - | Tool retry, distinct concept |
| ErrorOccurred | all | Core error event |
| ControlYielded | :agent | Fiber control flow |
| ControlResumed | - | Fiber control flow |
| SubAgentLaunched | :team | User callback target |
| SubAgentProgress | :team | User callback target |
| SubAgentCompleted | :team | User callback target |
| SpawnRestricted | - | Security event |
| RetryRequested | :model | User callback target |
| FailoverOccurred | :model | User callback target |
| RecoveryCompleted | :model | User callback target |
| RateLimitHit | :model | User callback target |

Also kept (unique, no merge partner):
- ToolCallParsed, ConfigurationChanged, AgentConfigured, CircuitStateChanged
- EvaluationCompleted, ReflectionRecorded, CompletionRejected, RepetitionDetected
- AgentStepRequested, OrchestratorLifecycle, CoordWaveLifecycle, RateLimitViolated

---

## Consolidation Groups (18 groups, 27 events removed)

### Group 1: ToolIsolation (3 → 1, save 2)
**Replaces:** ToolIsolationStarted, ToolIsolationCompleted, ResourceViolation
**Category:** :isolation
**Phases:** :started, :completed, :resource_violation
**Shared field:** tool_name
**Union fields:** phase, isolation_mode, resource_limits, outcome, metrics, error_class, resource_type, limit_value, actual_value, message
**Files:** events.rb (definitions), concerns/sandbox.rb, concerns/isolation.rb, executors/

### Group 2: CodeExecution (3 → 1, save 2)
**Replaces:** CodeGenerated, CodeExecutionStarted, CodeExecutionFinished
**Category:** :execution
**Phases:** :generated, :started, :finished
**Union fields:** phase, code, code_hash, language, step_number, model_id, isolation_mode, outcome, duration_ms, output, error_class
**Files:** events.rb (definitions), concerns/execution/

### Group 3: GoalLifecycle (3 → 1, save 2)
**Replaces:** GoalCreated, GoalProgress, GoalCompleted
**Category:** :goals
**Phases:** :created, :progress, :completed
**Shared field:** goal
**Union fields:** phase, parent_id, previous_progress, evidence
**Files:** events.rb (definitions), concerns/agents/ (goal tracking)

### Group 4: CheckpointLifecycle (3 → 1, save 2)
**Replaces:** CheckpointCreated, CheckpointRestored, CheckpointDeleted
**Category:** :checkpoints
**Phases:** :created, :restored, :deleted
**Shared field:** checkpoint_id, step_number
**Union fields:** phase, trigger, event_sequence, target_event_sequence, elapsed_steps, reason
**Files:** events/phase_d.rb, concerns/agents/checkpoints.rb

### Group 5: SemanticBreaker (3 → 1, save 2)
**Replaces:** SemanticFailureDetected, SemanticBreakerTripped, SemanticBreakerReset
**Category:** :semantic
**Phases:** :failure_detected, :tripped, :reset
**Union fields:** phase, failure_type, confidence, severity, evidence, recommended_action, consecutive_failures, action_taken, previous_failure_count, recovery_reason
**Files:** events/phase_d.rb, concerns/agents/semantic_breaker.rb

### Group 6: MoaLifecycle (3 → 1, save 2)
**Replaces:** ProposerLaunched, ProposalReceived, AggregationCompleted
**Category:** :moa
**Phases:** :proposer_launched, :proposal_received, :aggregation_completed
**Union fields:** phase, proposer_name, proposer_index, task, total_proposers, confidence, duration_ms, result_preview, strategy, proposal_count, selected_proposer, final_confidence
**Files:** events/phase_d.rb, builders/moa_coordinator.rb (or wherever MoA emits)

### Group 7: CapabilityEvent (3 → 1, save 2)
**Replaces:** CapabilityProbed, CapabilityLearned, CapabilityFallback
**Category:** :capability
**Phases:** :probed, :learned, :fallback
**Union fields:** phase, url, server_type, feature, supported, from_endpoint, to_endpoint, missing_capability
**Files:** events/capability.rb, concerns/resilience/capability_detection.rb

### Group 8: HealthCheck (2 → 1, save 1)
**Replaces:** HealthCheckRequested, HealthCheckCompleted
**Category:** :resilience
**Phases:** :requested, :completed
**Shared field:** model_id
**Union fields:** phase, check_type, status, latency_ms, error
**Files:** events/reliability.rb, concerns/resilience/health_check.rb (or telemetry/)

### Group 9: QueueRequest (2 → 1, save 1)
**Replaces:** QueueRequestStarted, QueueRequestCompleted
**Category:** :resilience
**Phases:** :started, :completed
**Shared field:** model_id
**Union fields:** phase, queue_depth, wait_time, duration, success
**Files:** events/reliability.rb, concerns/resilience/request_queue.rb

### Group 10: WorkItemLifecycle (3 → 1, save 2)
**Replaces:** WorkItemQueued, WorkItemDispatched, WorkItemCompleted
**Category:** :orchestration
**Phases:** :queued, :dispatched, :completed
**Shared field:** work_item_id, work_type
**Union fields:** phase, priority, queue_depth, wait_time_ms, worker_id, outcome, duration_ms, error_class
**Files:** events/orchestration.rb, orchestrators/event_orchestrator.rb

### Group 11: RequestReliability (2 → 1, save 1)
**Replaces:** RequestFailed, RequestRetried
**Category:** :resilience
**Phases:** :failed, :retried
**Shared field:** model_id
**Union fields:** phase, error, error_message, dlq_size, attempt, original_error
**Files:** events/reliability.rb, concerns/resilience/

### Group 12: ModelGeneration (2 → 1, save 1)
**Replaces:** ModelGenerateRequested, ModelGenerateCompleted
**Category:** :models
**Phases:** :requested, :completed
**Shared field:** model_id
**Union fields:** phase, message_count, has_tools, temperature, duration_ms, token_usage, has_tool_calls, outcome
**Files:** events.rb (definitions), models/model.rb

### Group 13: PlanEvent (2 → 1, save 1)
**Replaces:** PlanGenerated, PlanUpdated
**Category:** :planning
**Phases:** :generated, :updated
**Shared field:** plan
**Union fields:** phase, step_count, model_id, previous_plan, reason, step_number
**Files:** events.rb (definitions), concerns/agents/ (planning)

### Group 14: DriftDetected (2 → 1, save 1)
**Replaces:** GoalDriftDetected, PlanDivergence
**Category:** :metacognition
**Phases:** :goal, :plan
**Note:** These have IDENTICAL field signatures (level, task_relevance, off_topic_count)
**Union fields:** phase, level, task_relevance, off_topic_count
**Files:** events.rb (definitions), concerns/agents/ (metacognition)

### Group 15: Refinement (2 → 1, save 1)
**Replaces:** RefinementCompleted, MixedRefinementCompleted
**Category:** :metacognition
**Phases:** :completed, :cross_model_completed
**Union fields:** phase, iterations, improved, confidence, cross_model
**Files:** events.rb (definitions), concerns/agents/ (refinement)

### Group 16: ModelReliability (2 → 1, save 1)
**Replaces:** ModelDiscovered, ModelChanged
**Category:** :resilience
**Phases:** :discovered, :changed
**Union fields:** phase, model_id, provider, capabilities, from_model_id, to_model_id
**Files:** events/reliability.rb, concerns/resilience/

### Group 17: TaskLifecycle (2 → 1, save 1)
**Replaces:** TaskStarted, TaskCompleted
**Category:** :lifecycle
**Phases:** :started, :completed
**Union fields:** phase, task, agent_name, max_steps, run_id, outcome, output, steps_taken
**Files:** events.rb, events/orchestration.rb, concerns/agents/react_loop.rb

### Group 18: CoordTaskLifecycle expansion (absorb 2, save 2)
**Absorbs:** CoordTaskDispatched, CoordTaskProgress (into existing CoordTaskLifecycle)
**New phases:** :dispatched, :progress (added to existing :created, :started, :completed, :failed)
**New fields:** work_item_id, elapsed, progress_percent, subtask_count, blocked_by
**Files:** events/task_coordination.rb, concerns/orchestration/task_dispatch.rb

---

## Implementation Steps

### Step 1: Define consolidated events
For each group, create the new `define_event` with union fields, phase predicates, and defaults.

### Step 2: Update emit sites
For each old `emit :old_event_name, fields...` → `emit :new_event_name, phase: :x, fields...`

### Step 3: Update consumer convenience methods
Update `on_tools`, `on_lifecycle`, `on_models`, `on_orchestration` etc. in consumer.rb.

### Step 4: Add legacy aliases
Map old canonical names to new consolidated names in legacy_aliases.rb.

### Step 5: Update specs
Change event expectations from old names to new names + phase checks.

### Step 6: Delete old event definitions
Remove the replaced `define_event` calls.

### Step 7: Update Registry.for_builder
No changes needed (user-facing events preserved).

### Step 8: Update PLAN.md
Record consolidation results.

---

## Execution Strategy

Groups are independent — execute in parallel batches:

**Batch 1 (events.rb definitions):** Groups 2, 3, 12, 13, 14, 15, 17
**Batch 2 (phase_d.rb):** Groups 4, 5, 6
**Batch 3 (reliability.rb):** Groups 8, 9, 11, 16
**Batch 4 (other files):** Groups 1, 7, 10, 18

---

## Summary

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Total events | 72 | 45 | -37% |
| Event categories | 15 | 13 | -2 |
| define_event calls | 72 | 45 | -27 |
| Data.define types at boot | 72 | 45 | -27 |
| User-facing API | unchanged | unchanged | 0 |
