# Task Management & Coordination System

**Status:** Design Phase
**Target:** Phase E (Post Phase D: Checkpoints, Semantic Circuit Breaker, MoA)
**Inspiration:** Claude Code's declarative task management with automatic dependency tracking

---

## Executive Summary

This document outlines a magical task coordination system for smolagents-ruby that enables declarative multi-agent orchestration with automatic parallelism detection, dependency management, and resource allocation. The design leverages existing infrastructure (event system, work queue, goal tracking, orchestrator) and follows the principle of **progressive disclosure**—simple cases work with zero configuration, while complex cases expose full control.

**Key Insight:** All infrastructure pieces exist; they need assembly into a coherent task management layer that "just works" for 90% of use cases while remaining fully customizable for experts.

---

## Table of Contents

1. [Current Architecture](#current-architecture)
2. [Recommended Features](#recommended-features)
3. [Sensible Defaults](#sensible-defaults)
4. [Implementation Phases](#implementation-phases)
5. [API Examples](#api-examples)
6. [Integration Points](#integration-points)
7. [Files to Create](#files-to-create)

---

## Current Architecture

### What We Have (Strengths)

#### Event System (75+ Event Types)
- **Emitter Pattern:** `events/emitter.rb` (~160 lines)
- **Consumer Pattern:** `events/consumer.rb` (~200 lines)
- **Categories:** Lifecycle, tools, models, agents, errors, resilience, planning, goals
- **Event Store:** Foundation for persistence and time-travel debugging

#### Work Queue Infrastructure
- **Implementation:** `concerns/orchestration/work_queue.rb`
- **Priority Levels:** `:critical`, `:high`, `:normal`, `:low`
- **Work Item Types:** `model_generate`, `tool_call`, `code_execution`, `sub_agent`, `agent_step`
- **Thread-Safe:** Four-level priority bucket system with mutex protection
- **Callback System:** Work results routed via callbacks

#### Goal Tracking System
- **Implementation:** `concerns/agents/goal_tracking.rb` + `types/goal.rb`
- **Hierarchy:** Tree structure with parent/child relationships
- **States:** `:active`, `:blocked`, `:completed`, `:abandoned`
- **Store:** Thread-safe with queries: `active()`, `blocked()`, `completed()`, `children_of()`
- **History Preservation:** Completed goals never evicted

#### Event Orchestrator
- **Implementation:** `orchestrators/event_orchestrator.rb` (~105 lines)
- **Capabilities:** Event routing, work queue management, worker pool, subscriptions
- **Work Triggers:** Map event types to work item creation
- **Statistics:** Combined stats from all components
- **Status:** Infrastructure exists but not integrated into agent runtime

#### Multi-Agent Coordination

**Team Coordination:**
- `builders/team_builder.rb` - Coordinator delegates to specialized sub-agents
- `ManagedAgentTool` - Sub-agents callable as tools
- Model inheritance - Sub-agents without models use team model

**Parallel Execution:**
- `concerns/orchestration/parallel_agents.rb`
- Patterns: `spawn_parallel()` (wait all), `spawn_race()` (first wins), `spawn_any()` (optimistic)
- Thread-based with futures/Ractor support

**Sub-Agent Spawning:**
- `concerns/agents/spawn_restrictions.rb`
- Depth tracking, tool restriction, step budget enforcement
- Security policy validation

#### Context & Memory Management

**Working Memory:** `concerns/agents/working_memory.rb`
- Survives context truncation
- Tracks objectives, findings, blockers

**Context Orchestration:** `concerns/agents/context_orchestration.rb`
- Five layers: PERSISTENT, STRATEGIC, TACTICAL, HISTORICAL, DIAGNOSTIC
- Budget-aware assembly

**Planning System:** `concerns/agents/planning.rb`
- Pre-Act pattern (arXiv:2505.09970)
- Interval-based replanning (default: 3 steps)
- Strategic decomposition

### What's Missing (Gaps)

1. **No Centralized Task Model**
   - Tasks are implicit (agent.run strings)
   - No task identity, lifecycle tracking, or persistence
   - No dependency relationships between tasks
   - No resource allocation across tasks

2. **No Work Allocation/Scheduling Layer**
   - Work queue exists but not wired to agent execution
   - Orchestrator built but not integrated
   - No scheduler for prioritizing spawned work
   - No backpressure mechanism

3. **No Task Persistence/Resumption**
   - No mechanism to save/load task execution state
   - No resumption from failure points
   - No long-running task support

4. **No Coordination Primitives**
   - No task barriers/gates (wait for multiple tasks)
   - No result aggregation rules
   - No cascading failure handling
   - No rollback/compensation

5. **No Progress/Status Tracking Model**
   - No unified task progress query interface
   - No structured milestone tracking
   - No completion percentage estimation

---

## Recommended Features

Prioritized by impact and implementation effort.

### **1. Declarative Task API** (Highest Impact)

**Purpose:** Enable agents to declare sub-tasks with dependencies, priorities, and lifecycle management.

**Design:**
```ruby
agent.run_coordinated("Implement Phase D") do |coordinator|
  # Wave 1: Parallel foundation
  types_task = coordinator.task("Create types") do
    create_checkpoint_types
  end

  # Wave 2: Depends on types
  events_task = coordinator.task("Register events", after: types_task) do
    register_phase_d_events
  end

  # Coordinator handles scheduling, blocking, status
end
```

**Implementation Strategy:**
- Extend `Concerns::Agents::GoalTracking` → `Concerns::Agents::TaskCoordination`
- Add `TaskCoordinator` type wrapping goal store
- Map task states to goal states (`:active` → `:in_progress`, `:completed`, `:blocked`)
- Wire task completion events to unblock dependent tasks

**Key Files:**
- `types/task.rb` - Task identity (extends Goal)
- `types/task_coordinator.rb` - Coordinator API
- `concerns/agents/task_coordination.rb` - Task DSL and lifecycle (~100 lines)
- `builders/agent_builder.rb` - `.task_coordination(enabled: true)`

**Estimated Size:** ~200 lines total (80 types, 120 concern)

---

### **2. Parallel Execution Waves** (Visual Clarity)

**Purpose:** Automatically detect parallel-safe tasks and execute in waves based on dependency graph.

**Design:**
```ruby
team = Smolagents.team
  .model { gpt4 }
  .agent(researcher1, as: "researcher1")
  .agent(researcher2, as: "researcher2")
  .agent(analyst, as: "analyst")
  .execute_in_waves  # NEW: Analyze dependencies, schedule parallel batches
  .build

team.run_coordinated("Research and analyze") do |coord|
  # Wave 1 (parallel)
  r1 = coord.task("Research Ruby 4.0") { researcher1.run("...") }
  r2 = coord.task("Research gems") { researcher2.run("...") }

  # Wave 2 (depends on Wave 1)
  analysis = coord.task("Analyze", after: [r1, r2]) { analyst.run("...") }
end
```

**Implementation Strategy:**
- Add `WaveScheduler` that does topological sort on task DAG
- Extend `Concerns::Orchestration::ParallelAgents` to accept wave config
- Use existing `.spawn_parallel()` for intra-wave execution
- Emit events: `:wave_started`, `:wave_completed`

**Key Files:**
- `types/wave.rb` - Wave identity with task sets (~30 lines)
- `concerns/orchestration/wave_scheduler.rb` - DAG analysis (~90 lines)
- `builders/team_builder.rb` - `.execute_in_waves`

**Estimated Size:** ~120 lines total (30 types, 90 concern)

---

### **3. Task Status Query API** (Developer Experience)

**Purpose:** Provide structured queries over task coordinator state for observability.

**Design:**
```ruby
# Query interface over task coordinator
status = agent.task_status
status.total        # 12
status.completed    # 0
status.open         # 12
status.blocked      # [#6, #7, ...]

# Per-task queries
task = status.find_task("#6")
task.blocked_by     # [#2, #4]
task.status         # :pending
task.can_start?     # false (blockers present)

# Next actionable task
next_task = status.next_available
# → First unblocked, highest priority task
```

**Implementation Strategy:**
- Extend `Concerns::Agents::GoalTracking::Store` with query methods
- Add predicates: `.blocked?`, `.actionable?`, `.waiting_for`
- Use existing goal hierarchy for parent/child relationships
- Emit `:task_status_changed` events

**Key Files:**
- `concerns/agents/task_coordination/queries.rb` - Query interface (~50 lines)
- `types/task_status.rb` - Status snapshot type (~30 lines)

**Estimated Size:** ~80 lines total (30 types, 50 concern)

---

### **4. Automatic Work Distribution** (Orchestration Magic)

**Purpose:** Wire task completion events to automatic work item creation for dependent tasks.

**Design:**
```ruby
# Work queue integration with task coordination
agent = Smolagents.agent
  .model { ... }
  .task_coordination(enabled: true)
  .work_distribution(strategy: :priority_first)  # NEW
  .build

# When tasks complete, dependent tasks auto-enqueue
orchestrator.trigger_work_on(TaskCompleted) do |event|
  dependent_tasks = find_unblocked_by(event.task_id)
  dependent_tasks.each do |task|
    WorkItem.agent_step(task: task.description, priority: task.priority)
  end
end
```

**Implementation Strategy:**
- Wire `Orchestrators::EventOrchestrator` into agent runtime
- Add event triggers for task lifecycle: `TaskCreated`, `TaskCompleted`, `TaskBlocked`
- Map task completion → work item creation for unblocked dependents
- Use existing `WorkQueue` for priority-based scheduling

**Key Files:**
- `concerns/orchestration/task_dispatch.rb` - Event → work item translation (~90 lines)
- `builders/agent_builder.rb` - `.work_distribution(strategy:)`

**Estimated Size:** ~90 lines (concern only)

---

### **5. Task Progress Visualization** (Observability)

**Purpose:** Emit structured progress events for real-time task status updates.

**Design:**
```ruby
# Event-driven progress tracking
agent.on(:task_progress) do |event|
  puts "#{event.active_form}... (#{event.elapsed_time})"
  event.subtasks.each do |subtask|
    status = subtask.blocked? ? "blocked by #{subtask.blockers}" : subtask.status
    puts "  #{subtask.icon} ##{subtask.id} #{subtask.description} › #{status}"
  end
end

# Or structured query
progress = agent.task_progress("#1")
progress.active_form    # "Creating checkpoint types"
progress.elapsed        # Duration
progress.subtasks       # Nested task tree
progress.tokens_used    # From context orchestration
```

**Implementation Strategy:**
- Extend task events to include `activeForm` field (present continuous)
- Emit `:task_progress` events at intervals
- Aggregate timing from existing step metrics
- Use goal hierarchy for subtask tree rendering
- Lazy emission: only if subscribers present

**Key Files:**
- `concerns/agents/task_coordination/progress.rb` - Progress tracking (~50 lines)
- `types/task_progress.rb` - Progress snapshot type (~25 lines)

**Estimated Size:** ~75 lines total (25 types, 50 concern)

---

## Sensible Defaults

The magic is in defaults that create excellent experiences without configuration.

### 1. Auto-Enable Task Coordination (Context-Aware)

**Principle:** Enable coordination automatically when multiple agents are involved.

```ruby
# In AgentBuilder#build
needs_coordination = configuration[:managed_agents].any? ||
                    configuration[:spawn_config] ||
                    configuration[:event_driven]

if needs_coordination && !configuration[:task_coordination_disabled]
  enable_task_coordination  # Silently enable
end
```

**When to auto-enable:**
- ✅ Teams (multiple agents via `TeamBuilder`)
- ✅ Spawn enabled (`.can_spawn`)
- ✅ Event-driven mode (`.event_driven`)
- ✅ Managed agents (`.managed_agent`)
- ❌ Single agent with no sub-agents → Keep it simple

**Opt-out available:**
```ruby
agent.task_coordination(enabled: false)  # Manual override
```

---

### 2. Smart Orchestrator Creation

**Principle:** Create orchestrator lazily when first needed.

```ruby
# In config/defaults.rb
orchestration: {
  auto_create: true,                    # Create when coordination enabled
  queue_depth: 500,
  pool_size: Concurrent.processor_count, # CPU-aware worker pool
  event_buffer_size: 1000,
  work_distribution: :priority_first_fair,
  enable_progress_events: :on_subscribe # Only emit if someone listens
}.freeze
```

**Magic:** Users never think about the orchestrator unless they want custom config.

---

### 3. Wave Execution by Default for Teams

**Principle:** Automatically detect parallelism in declarative task structures.

```ruby
# In team_builder.rb defaults
def self.default_configuration
  {
    # ... existing fields ...
    wave_execution: true,              # NEW: Auto-detect parallel opportunities
    wave_strategy: :auto_detect,       # NEW: Analyze dependencies
    max_parallel_per_wave: nil         # NEW: nil = no limit (use pool size)
  }
end
```

**Strategy:**
- `:auto_detect` - Analyze dependencies via topological sort
- `:force_parallel` - Run all tasks in parallel (user knows they're safe)
- `:sequential` - Force sequential execution (backward compatible)

---

### 4. Smart Priority Inference

**Principle:** Infer priority from task structure; allow manual override.

```ruby
# Priority inference from dependency graph
def infer_priority_from_dependencies(deps)
  return :normal if deps.empty?

  # Critical path: tasks with many dependents = higher priority
  case dependency_depth(deps)
  when 0      then :normal   # No deps = normal
  when 1..2   then :high     # Short chain = high
  else             :critical # Long chain = critical path
  end
end
```

**Config:**
```ruby
task_coordination: {
  priority_levels: [:low, :normal, :high, :critical],
  default_priority: :normal,
  critical_path_boost: true,          # Auto-boost blocking tasks
  starvation_threshold_seconds: 60,   # Boost tasks waiting >60s
  priority_aging_enabled: true        # Gradually boost waiting tasks
}.freeze
```

---

### 5. Resource Limits (Spawn Budget Aware)

**Principle:** Inherit constraints from parent context.

```ruby
def task_coordination_defaults
  {
    max_parallel_tasks: if spawn_context
      # Child agents: limited by parent's remaining budget
      [spawn_context.remaining_steps / 2, 1].max
    else
      # Root agents: use CPU count or config
      Config.default(:orchestration, :pool_size)
    end,

    task_timeout: if spawn_context
      # Proportional to remaining steps
      spawn_context.remaining_steps * 30  # 30s per step
    else
      nil  # No timeout for root
    end,

    memory_budget_per_task: if @memory_config
      # Split parent's budget across parallel tasks
      @memory_config.token_budget / max_parallel_tasks
    else
      nil  # No limit
    end
  }
end
```

**Magic:** Sub-agents automatically respect parent resource limits.

---

### 6. Progress Events (Lazy Emission)

**Principle:** Only emit verbose progress events if someone subscribes.

```ruby
def emit_task_progress(task)
  # Always emit core events (cheap)
  emit :task_created, task_id: task.id, description: task.description
  emit :task_completed, task_id: task.id, outcome: task.outcome

  # Only emit verbose progress if subscribed (expensive)
  if subscribed_to?(:task_progress)
    emit :task_progress,
      task_id: task.id,
      active_form: task.active_form,
      elapsed: task.elapsed,
      subtasks: task.subtasks,
      tokens_used: estimate_tokens(task)
  end
end
```

**Magic:** Zero overhead for progress tracking unless actively used.

---

### 7. Scheduling Strategy Defaults

**Principle:** Priority-first with fairness guarantees.

```ruby
work_distribution: {
  strategy: :priority_first_fair,    # Respect priority but prevent starvation
  fairness_window: 5,                 # After 5 high-priority, allow 1 lower
  starvation_boost_seconds: 60,      # Boost priority after 60s wait
  critical_path_detection: true,     # Auto-boost blocking tasks
  adaptive_priority: true            # Adjust based on actual execution time
}.freeze
```

**Strategies:**
- `priority_first_fair` (default): Priority with starvation prevention
- `priority_strict`: Always highest priority first
- `fifo`: First-in-first-out (ignore priority)
- `sjf`: Shortest job first (estimated duration)
- `round_robin`: Fair time slicing

---

### 8. Timeout Defaults (Context-Aware)

**Principle:** Timeouts scale with task complexity.

```ruby
def compute_task_timeout(task)
  base_timeout = Config.default(:http, :ractor_timeout_seconds)  # 120s

  # Scale by factors
  multiplier = 1.0
  multiplier *= 2 if task.priority == :critical  # Critical tasks get more time
  multiplier *= 1.5 if task.dependencies.any?    # Dependent tasks may be complex
  multiplier *= 0.5 if task.priority == :low     # Low priority = less time

  # Cap at parent's remaining budget
  max_allowed = spawn_context&.remaining_steps&.* (30) || Float::INFINITY

  [base_timeout * multiplier, max_allowed].min
end
```

---

### 9. Memory Budget Distribution

**Principle:** Split token budget fairly across parallel tasks.

```ruby
def task_memory_budget(num_parallel_tasks)
  return nil unless @memory_config

  total_budget = @memory_config.token_budget
  persistent_overhead = 2000  # Working memory, system prompt
  available = total_budget - persistent_overhead

  # Fair split with minimum guarantee
  per_task = available / num_parallel_tasks
  minimum = 5000  # Minimum tokens per task

  [per_task, minimum].max
end
```

---

### 10. Team Coordination Defaults

**Principle:** Teams should coordinate by default.

```ruby
# In team_builder.rb
def build
  # Teams ALWAYS use task coordination (they have multiple agents)
  coordinator = build_coordinator_with_coordination(
    orchestrator: shared_orchestrator,  # One orchestrator for whole team
    wave_execution: configuration[:wave_execution],  # true by default
    max_parallel: configuration[:max_parallel_per_wave]  # nil = auto
  )
end

def shared_orchestrator
  @shared_orchestrator ||= EventOrchestrator.new
end
```

---

### 11. Planning Integration

**Principle:** Planning steps can create task structures.

```ruby
def execute_planning_step(step_number)
  plan = generate_plan(step_number)

  # If task coordination enabled, planning can decompose into tasks
  if task_coordination_enabled? && plan.tasks.any?
    plan.tasks.each do |planned_task|
      task_coordinator.task(
        planned_task.description,
        priority: planned_task.priority,
        after: resolve_dependencies(planned_task)
      ) { execute_planned_task(planned_task) }
    end
  end

  plan
end
```

---

### 12. Status Observability (Always Available)

**Principle:** Status queries should always work, even if coordination is minimal.

```ruby
# Even simple agents have queryable status
agent = Smolagents.agent.model { ... }.build
agent.run_async("task")

# Works even without task_coordination:
status = agent.status
# => { state: :running, step: 5, max_steps: 20, progress: 0.25 }

# With task_coordination:
status = agent.task_status
# => TaskStatus(total: 5, completed: 2, open: 3, blocked: 1)
```

---

### Configuration Summary

```ruby
# In config/defaults.rb - NEW SECTIONS

# Task Coordination
task_coordination: {
  auto_enable: true,                    # Enable when teams/spawn/parallel detected
  priority_levels: [:low, :normal, :high, :critical],
  default_priority: :normal,
  critical_path_boost: true,
  starvation_threshold_seconds: 60,
  priority_aging_enabled: true
}.freeze,

# Wave Execution
wave_execution: {
  auto_detect: true,                    # Analyze dependencies for waves
  max_parallel_per_wave: nil,           # nil = use pool size
  inter_wave_delay_ms: 0                # No delay between waves
}.freeze,

# Orchestration (EXPAND EXISTING)
orchestration: {
  auto_create: true,                    # Create orchestrator when needed
  queue_depth: 500,
  pool_size: Concurrent.processor_count, # CPU-aware
  event_buffer_size: 1000,
  work_distribution: :priority_first_fair,
  enable_progress_events: :on_subscribe, # Lazy emission
  fairness_window: 5,
  adaptive_priority: true
}.freeze,

# Task Timeouts
task_timeouts: {
  base_timeout_seconds: 120,
  critical_multiplier: 2.0,
  low_priority_multiplier: 0.5,
  respect_spawn_budget: true            # Never exceed parent's budget
}.freeze,

# Task Memory
task_memory: {
  persistent_overhead_tokens: 2000,     # Working memory
  minimum_tokens_per_task: 5000,        # Minimum guarantee
  fair_split: true                      # Divide budget across parallel
}.freeze
```

---

## Implementation Phases

### Phase 0: Foundation Wiring (2-3 days)

**Goal:** Connect existing pieces

**Tasks:**
1. Wire Event Orchestrator into Agent Runtime
   - Add `.orchestrator(instance)` to AgentBuilder
   - Default orchestrator creation if not provided
   - Route agent lifecycle events through orchestrator

2. Map Goals → Tasks
   - Extend `Goal` type with task-specific fields (`activeForm`, `blockedBy`, `priority`)
   - Add task query methods to `GoalTracking::Store`
   - Emit task-specific events (reuse goal events initially)

**Deliverable:** Agents emit events to orchestrator, goals queryable as tasks

---

### Phase 1: Task Coordination DSL (1 week)

**Goal:** Declarative task API

**Tasks:**

1. **Create Task Coordinator** (~50 lines)
   ```ruby
   # types/task_coordinator.rb
   TaskCoordinator = Data.define(:store, :orchestrator) do
     def task(description, after: [], priority: :normal, &block)
       # Create goal with dependencies
       # Enqueue work item if unblocked
       # Return task handle
     end
   end
   ```

2. **Add TaskCoordination Concern** (~100 lines)
   ```ruby
   # concerns/agents/task_coordination.rb
   module Concerns::Agents::TaskCoordination
     def task_coordinator
       @task_coordinator ||= TaskCoordinator.new(
         store: goal_store,
         orchestrator: @orchestrator
       )
     end

     def run_coordinated(task, &block)
       coordinator = task_coordinator
       block.call(coordinator)
       coordinator.execute
     end
   end
   ```

3. **Builder Integration**
   ```ruby
   # builders/agent_builder.rb
   def task_coordination(enabled: true)
     with(task_coordination_enabled: enabled)
   end
   ```

**Deliverable:** Agents can declare tasks with dependencies programmatically

---

### Phase 2: Wave Scheduling (3-4 days)

**Goal:** Automatic parallel execution planning

**Tasks:**

1. **Create Wave Type & Scheduler** (~120 lines)
   ```ruby
   # types/wave.rb
   Wave = Data.define(:number, :task_ids, :status)

   # concerns/orchestration/wave_scheduler.rb
   module Concerns::Orchestration::WaveScheduler
     def compute_waves(tasks)
       # Topological sort by dependencies
       # Group into parallel-safe batches
       # Return Wave instances
     end

     def execute_wave(wave, &task_runner)
       # Use existing spawn_parallel for tasks in wave
     end
   end
   ```

2. **Team Builder Integration**
   ```ruby
   # builders/team_builder.rb
   def execute_in_waves
     with(wave_execution: true)
   end
   ```

**Deliverable:** Teams automatically detect parallelism and schedule waves

---

### Phase 3: Status Query API (2 days)

**Goal:** Developer-friendly progress inspection

**Tasks:**

1. **Add Query Methods** (~50 lines)
   ```ruby
   # concerns/agents/task_coordination/queries.rb
   module Concerns::Agents::TaskCoordination::Queries
     def task_status
       TaskStatus.from_store(goal_store)
     end

     def next_available_task
       goal_store.active.find(&:actionable?)
     end
   end
   ```

2. **Status Type** (~30 lines)
   ```ruby
   # types/task_status.rb
   TaskStatus = Data.define(:total, :completed, :open, :blocked) do
     def self.from_store(store)
       # Aggregate from goal store
     end
   end
   ```

**Deliverable:** `agent.task_status` returns structured progress info

---

### Phase 4: Progress Events (1-2 days)

**Goal:** Real-time observability

**Tasks:**

1. **Emit Progress Events**
   ```ruby
   # Add to task_coordination.rb
   def on_task_progress(task_id)
     emit :task_progress,
       task_id: task_id,
       active_form: task.active_form,
       elapsed: Time.now - task.started_at,
       subtasks: task_coordinator.children_of(task_id)
   end
   ```

2. **Progress Type** (~25 lines)
   ```ruby
   # types/task_progress.rb
   TaskProgress = Data.define(:task_id, :active_form, :elapsed, :subtasks, :tokens_used)
   ```

**Deliverable:** Subscribe to `:task_progress` for real-time updates

---

### Phase 5: Work Distribution (2-3 days)

**Goal:** Automatic task dispatch via orchestrator

**Tasks:**

1. **Create Task Dispatch Concern** (~90 lines)
   ```ruby
   # concerns/orchestration/task_dispatch.rb
   module Concerns::Orchestration::TaskDispatch
     def setup_task_triggers
       trigger_work_on(TaskCompleted) do |event|
         dispatch_dependent_tasks(event.task_id)
       end
     end

     def dispatch_dependent_tasks(completed_task_id)
       # Find unblocked tasks
       # Create work items
       # Enqueue to work queue
     end
   end
   ```

2. **Builder Integration**
   ```ruby
   # builders/agent_builder.rb
   def work_distribution(strategy: :priority_first_fair)
     with(work_distribution_strategy: strategy)
   end
   ```

**Deliverable:** Task completion automatically triggers dependent task execution

---

### Phase 6: Configuration & Defaults (1-2 days)

**Goal:** Add all sensible defaults to config

**Tasks:**

1. **Extend Config Defaults**
   - Add `task_coordination`, `wave_execution`, `task_timeouts`, `task_memory` sections
   - Update `Config.default` helper for nested access

2. **Add Auto-Enable Logic**
   - Detect when coordination needed (teams, spawn, event-driven)
   - Silently enable unless disabled

3. **Add Context-Aware Calculations**
   - Timeout computation based on spawn context
   - Memory budget distribution
   - Priority inference

**Deliverable:** Zero-config experience for common cases

---

### Phase 7: Testing & Documentation (3-4 days)

**Goal:** Comprehensive coverage and examples

**Tasks:**

1. **Unit Tests** (~400 lines)
   - `spec/concerns/agents/task_coordination_spec.rb`
   - `spec/concerns/orchestration/wave_scheduler_spec.rb`
   - `spec/types/task_coordinator_spec.rb`
   - `spec/types/task_status_spec.rb`

2. **Integration Tests** (~300 lines)
   - `spec/integration/coordinated_team_spec.rb`
   - `spec/integration/wave_execution_spec.rb`
   - `spec/integration/task_progress_spec.rb`

3. **Documentation**
   - Update AGENTS.md with task coordination examples
   - Update CLAUDE.md with task API reference
   - Add examples to builder docs

**Deliverable:** Full test coverage and usage examples

---

## API Examples

### Progressive Disclosure Levels

#### Level 1: Simple (No Config)
```ruby
# Just works - no coordination visible
agent = Smolagents.agent.model { ... }.tools(:search).build
agent.run("Find Ruby 4.0 docs")
```

#### Level 2: Teams (Auto-Coordination)
```ruby
# Coordination + waves auto-enabled
team = Smolagents.team
  .model { ... }
  .agent(researcher, as: "researcher")
  .agent(writer, as: "writer")
  .build

team.run("Research and write")
# Magic: Automatically detects if they can run in parallel
```

#### Level 3: Explicit Tasks (Full Control)
```ruby
# Full control over task DAG
team.run_coordinated("Complex project") do |coord|
  r1 = coord.task("Research A", priority: :high) { ... }
  r2 = coord.task("Research B", priority: :high) { ... }
  analysis = coord.task("Analyze", after: [r1, r2]) { ... }
  coord.task("Report", after: analysis, priority: :critical) { ... }
end
# Magic: Waves, priority, dependencies all handled automatically
```

#### Level 4: Custom Orchestration (Expert)
```ruby
# Full customization for experts
orchestrator = EventOrchestrator.new(
  config: EventOrchestrator::Config.new(
    pool_size: 16,
    work_distribution: :sjf  # Shortest job first
  )
)

agent = Smolagents.agent
  .model { ... }
  .orchestrator(orchestrator)
  .task_coordination(
    priority_aging: false,
    starvation_threshold: 120
  )
  .build
```

---

### Real-World Examples

#### Example 1: Multi-Phase Research Team

```ruby
team = Smolagents.team
  .model { OpenAIModel.new(model_id: "gpt-4") }
  .agent(researcher1, as: "researcher1")
  .agent(researcher2, as: "researcher2")
  .agent(analyst, as: "analyst")
  .agent(writer, as: "writer")
  .execute_in_waves
  .build

result = team.run_coordinated("Create comprehensive Ruby 4.0 report") do |coord|
  # Wave 1: Parallel research (both run simultaneously)
  docs = coord.task("Research official docs", priority: :high) do
    researcher1.run("Find and read Ruby 4.0 official documentation")
  end

  community = coord.task("Research community feedback", priority: :high) do
    researcher2.run("Gather community reactions and blog posts")
  end

  # Wave 2: Analysis (waits for both research tasks)
  analysis = coord.task("Synthesize findings", after: [docs, community], priority: :high) do
    analyst.run("Compare official docs with community feedback, identify key themes")
  end

  # Wave 3: Writing (waits for analysis)
  coord.task("Write report", after: analysis, priority: :critical) do
    writer.run("Create well-structured report with intro, findings, and conclusion")
  end
end

puts result.output
```

**Execution Timeline:**
```
Wave 1 (parallel, ~60s):
  ├─ researcher1: "Research official docs"
  └─ researcher2: "Research community feedback"

Wave 2 (sequential, ~30s):
  └─ analyst: "Synthesize findings" (waits for both researchers)

Wave 3 (sequential, ~45s):
  └─ writer: "Write report" (waits for analyst)

Total: ~135s (vs ~195s sequential)
```

---

#### Example 2: Spawn with Task Coordination

```ruby
agent = Smolagents.agent
  .model { ... }
  .tools(:search, :web)
  .can_spawn(max_depth: 2)
  .task_coordination(enabled: true)
  .build

result = agent.run_coordinated("Research competing frameworks") do |coord|
  frameworks = ["Rails 8", "Hanami 2", "Roda 3"]

  # Dynamically spawn sub-agents for each framework
  research_tasks = frameworks.map do |framework|
    coord.task("Research #{framework}", priority: :high) do
      spawn_child(
        persona: :researcher,
        task: "Deep dive into #{framework} features and adoption",
        max_steps: 10
      )
    end
  end

  # Compare all results
  coord.task("Compare frameworks", after: research_tasks, priority: :critical) do
    "Compare findings: #{research_tasks.map(&:result).join(', ')}"
  end
end
```

---

#### Example 3: Progress Tracking

```ruby
agent = Smolagents.agent
  .model { ... }
  .task_coordination(enabled: true)
  .build

# Subscribe to progress events
agent.on(:task_progress) do |event|
  puts "[#{event.task_id}] #{event.active_form}... (#{event.elapsed}s)"

  event.subtasks.each do |subtask|
    icon = case subtask.status
           when :completed then "✓"
           when :in_progress then "◼"
           when :blocked then "⚠"
           else "◻"
           end

    puts "  #{icon} ##{subtask.id} #{subtask.description}"
  end
end

agent.run_coordinated("Complex task") do |coord|
  # ... task definitions ...
end

# Output:
# [task-1] Creating types... (2.3s)
#   ◼ #1 Create Checkpoint types
#   ◼ #2 Create Semantic types
#   ◻ #3 Register events › blocked by #1, #2
```

---

#### Example 4: Priority and Resource Management

```ruby
team = Smolagents.team
  .model { ... }
  .agent(urgent_agent, as: "urgent")
  .agent(batch_agent, as: "batch")
  .memory(budget: 50_000)  # 50k token budget
  .execute_in_waves
  .build

team.run_coordinated("Mixed priority workload") do |coord|
  # Critical path: High priority, more resources
  urgent = coord.task("Handle urgent request", priority: :critical) do
    urgent_agent.run("Process critical customer issue")
  end

  # Background work: Low priority, fewer resources
  coord.task("Process batch job", priority: :low) do
    batch_agent.run("Update 1000 records")
  end

  # Memory budget automatically split:
  # - urgent: ~30k tokens (critical priority gets boost)
  # - batch: ~18k tokens (low priority gets less)
  # - overhead: ~2k tokens (persistent context)
end
```

---

## Integration Points

### Event System Integration

**New Events to Add:**
```ruby
# In events/mappings.rb
LIFECYCLE_EVENTS = %i[
  task_created
  task_started
  task_completed
  task_failed
  task_blocked
  task_unblocked
  task_cancelled
  wave_started
  wave_completed
  task_priority_changed
  task_status_changed
  task_progress
].freeze
```

**Event Payloads:**
```ruby
# task_created
{ task_id:, description:, priority:, dependencies:, created_at: }

# task_progress
{ task_id:, active_form:, elapsed:, subtasks:, tokens_used:, progress: }

# wave_started
{ wave_number:, task_count:, total_waves: }
```

---

### Goal Store Integration

**Extensions to Goal Type:**
```ruby
# types/goal.rb
Goal = Data.define(
  # Existing fields
  :id, :description, :parent_id, :progress, :state,

  # NEW: Task-specific fields
  :priority,           # :low, :normal, :high, :critical
  :active_form,        # "Creating types" (present continuous)
  :dependencies,       # Array of goal IDs that must complete first
  :blocked_by,         # Computed from dependencies
  :started_at,         # Timestamp when state → :active
  :completed_at,       # Timestamp when state → :completed
  :timeout_seconds,    # Max execution time
  :assigned_to         # Agent ID for tracking
) do
  # NEW: Task predicates
  def actionable?
    active? && blocked_by.empty?
  end

  def blocked?
    blocked_by.any?
  end

  def overdue?
    timeout_seconds && started_at &&
      (Time.now - started_at) > timeout_seconds
  end
end
```

---

### Context Orchestration Integration

**Budget Allocation for Parallel Tasks:**
```ruby
# In concerns/agents/context_orchestration.rb
def assemble_for_task(task_id:, num_parallel_siblings:)
  # Existing context assembly
  base_context = assemble(task: task.description, step: current_step)

  # NEW: Adjust budget for parallel execution
  if num_parallel_siblings > 1
    adjusted_budget = base_context.budget / num_parallel_siblings
    adjusted_budget = [adjusted_budget, Config.default(:task_memory, :minimum_tokens_per_task)].max

    base_context.with(budget: adjusted_budget)
  else
    base_context
  end
end
```

---

### Planning Integration

**Planning → Task Decomposition:**
```ruby
# In concerns/agents/planning.rb
def execute_planning_step(step_number)
  plan = generate_plan(step_number)

  # NEW: If task coordination enabled, auto-create tasks from plan
  if task_coordination_enabled?
    decompose_plan_into_tasks(plan)
  end

  plan
end

def decompose_plan_into_tasks(plan)
  return unless plan.respond_to?(:steps)

  plan.steps.each_with_index do |step, idx|
    prior_step = idx > 0 ? task_coordinator.find_by_description(plan.steps[idx - 1]) : nil

    task_coordinator.task(
      step.description,
      priority: step.priority || :normal,
      after: prior_step ? [prior_step.id] : []
    ) { execute_planned_step(step) }
  end
end
```

---

## Files to Create

### Types (5 files, ~160 lines total)

```
types/
├── task_coordinator.rb      # ~50 lines - Coordinator API
├── task_status.rb            # ~30 lines - Status snapshot
├── task_progress.rb          # ~25 lines - Progress snapshot
├── wave.rb                   # ~30 lines - Wave identity
└── task.rb                   # ~25 lines - Task-specific Goal extensions
```

### Concerns (5 files, ~380 lines total)

```
concerns/
├── agents/
│   ├── task_coordination.rb                # ~100 lines - Main DSL
│   └── task_coordination/
│       ├── queries.rb                      # ~50 lines - Query API
│       └── progress.rb                     # ~50 lines - Progress tracking
└── orchestration/
    ├── wave_scheduler.rb                   # ~90 lines - Wave computation
    └── task_dispatch.rb                    # ~90 lines - Work distribution
```

### Builders (2 files, ~60 lines total)

```
builders/
├── agent_builder.rb          # +30 lines - .task_coordination(), .work_distribution()
└── team_builder.rb           # +30 lines - .execute_in_waves
```

### Configuration (1 file, ~80 lines)

```
config/
└── defaults.rb               # +80 lines - Task coordination defaults
```

### Tests (3 files, ~700 lines total)

```
spec/
├── concerns/
│   ├── agents/
│   │   └── task_coordination_spec.rb       # ~250 lines
│   └── orchestration/
│       └── wave_scheduler_spec.rb          # ~150 lines
└── integration/
    └── coordinated_team_spec.rb            # ~300 lines
```

### Documentation (3 files)

```
docs/
├── AGENTS.md                 # Update with task coordination examples
├── CLAUDE.md                 # Update DSL reference
└── TASK_COORDINATION.md      # New: Deep dive guide
```

**Total Estimated LOC:** ~1,380 lines (types + concerns + builders + config + tests)

---

## Architecture Integration Map

```
┌─────────────────────────────────────────────────────────────┐
│                     Agent/Team Builder DSL                   │
│  .task_coordination(enabled: true)                          │
│  .work_distribution(strategy: :priority_first)              │
│  .execute_in_waves                                          │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐  ┌──────────────────┐  ┌──────────────┐
│ Task         │  │ Wave             │  │ Work         │
│ Coordination │  │ Scheduler        │  │ Distribution │
│ Concern      │  │ Concern          │  │ Concern      │
└──────────────┘  └──────────────────┘  └──────────────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
                   ┌────────┴────────┐
                   │  Event System   │
                   │  (75+ → 87+)    │
                   └────────┬────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐  ┌──────────────────┐  ┌──────────────┐
│ Goal Store   │  │ Work Queue       │  │ Event        │
│ (Extended)   │  │ (Existing)       │  │ Orchestrator │
│              │  │                  │  │ (Wired)      │
└──────────────┘  └──────────────────┘  └──────────────┘
```

---

## Success Metrics

### Developer Experience
- ✅ Zero config for 90% of use cases
- ✅ Single method call for task coordination: `run_coordinated { |coord| ... }`
- ✅ Automatic parallelism detection in teams
- ✅ Intuitive priority system (auto-inferred or explicit)

### Performance
- ✅ Parallel task execution reduces wall-clock time 30-50%
- ✅ Priority scheduling ensures critical path completes first
- ✅ Resource limits prevent OOM and timeouts

### Observability
- ✅ Real-time progress tracking via events
- ✅ Structured status queries (`agent.task_status`)
- ✅ Dependency visualization in logs
- ✅ Performance metrics per task

### Code Quality
- ✅ All concerns ≤100 lines
- ✅ Types use Data.define
- ✅ Event-driven (no instrumentation wrapping)
- ✅ Comprehensive test coverage (>95%)

---

## Future Extensions (Post-MVP)

### Phase E+: Persistence & Resumption
- Task state snapshots using event store
- Resumption from failure points
- Long-running task support
- Distributed execution coordination

### Phase F: Advanced Coordination
- Task barriers/gates (wait for N of M tasks)
- Result aggregation strategies (voting, consensus)
- Cascading failure handling
- Rollback/compensation patterns

### Phase G: Observability UI
- Real-time task dashboard
- Dependency graph visualization
- Performance profiling per task
- Interactive task control (pause, cancel, reprioritize)

### Phase H: Adaptive Scheduling
- Learn optimal task priorities from history
- Dynamic resource allocation based on actual usage
- Predictive timeouts based on task similarity
- Auto-scaling worker pool based on queue depth

---

## References

- **Pre-Act Planning:** arXiv:2505.09970 - Research showing 70% improvement with 3-5 step planning intervals
- **Claude Code:** Inspiration for declarative task management with dependency tracking
- **Existing Architecture:** `AGENTS.md`, `PLAN.md` for current patterns and design philosophy

---

## Questions & Decisions

### Open Questions

1. **Persistence Strategy:** Should tasks persist to disk by default, or only when explicitly configured?
   - **Recommendation:** In-memory by default, opt-in persistence via `.task_persistence(storage: ...)`

2. **Task Cancellation:** Should parent task cancellation cascade to children?
   - **Recommendation:** Yes by default, opt-out via `cascade_cancellation: false`

3. **Error Handling:** Should task failure block dependent tasks, or allow retry/skip?
   - **Recommendation:** Block by default, expose retry policies per task

4. **Distributed Execution:** Should orchestrator support remote agents?
   - **Recommendation:** Out of scope for MVP, design for future extensibility

### Resolved Decisions

- ✅ **Auto-enable coordination:** Yes, for teams/spawn/parallel cases
- ✅ **Default wave execution:** Yes for teams, analyze dependencies
- ✅ **Priority inference:** Yes, from dependency graph + manual override
- ✅ **Lazy progress emission:** Yes, only if subscribers present
- ✅ **Scheduling strategy:** Priority-first with fairness (starvation prevention)

---

## Implementation Checklist

### Phase 0: Foundation ☐
- [ ] Wire EventOrchestrator into agent runtime
- [ ] Add orchestrator to AgentBuilder
- [ ] Extend Goal type with task fields
- [ ] Add task query methods to GoalTracking::Store

### Phase 1: Task Coordination ☐
- [ ] Create TaskCoordinator type
- [ ] Implement TaskCoordination concern
- [ ] Add .task_coordination() to builder
- [ ] Write unit tests

### Phase 2: Wave Scheduling ☐
- [ ] Create Wave type
- [ ] Implement WaveScheduler concern
- [ ] Add .execute_in_waves to TeamBuilder
- [ ] Write unit tests

### Phase 3: Status Queries ☐
- [ ] Create TaskStatus type
- [ ] Implement query methods
- [ ] Add .task_status API
- [ ] Write unit tests

### Phase 4: Progress Events ☐
- [ ] Create TaskProgress type
- [ ] Implement progress emission
- [ ] Add lazy emission logic
- [ ] Write unit tests

### Phase 5: Work Distribution ☐
- [ ] Implement TaskDispatch concern
- [ ] Add work triggers for task events
- [ ] Add .work_distribution() to builder
- [ ] Write unit tests

### Phase 6: Configuration ☐
- [ ] Add task_coordination defaults
- [ ] Add wave_execution defaults
- [ ] Add work_distribution defaults
- [ ] Add auto-enable logic

### Phase 7: Testing & Docs ☐
- [ ] Write integration tests
- [ ] Update AGENTS.md
- [ ] Update CLAUDE.md
- [ ] Create TASK_COORDINATION.md

---

## Conclusion

This task coordination system transforms smolagents-ruby into a framework where multi-agent orchestration "just works" with zero configuration, while experts retain full control. By leveraging existing infrastructure and following the principle of progressive disclosure, we create a magical experience that scales from simple single-agent tasks to complex multi-phase team coordination with automatic parallelism, resource management, and real-time observability.

**Next Steps:** Begin Phase 0 foundation wiring, starting with EventOrchestrator integration into agent runtime.
