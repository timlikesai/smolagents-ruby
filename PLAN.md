# Cleanup & Organization Plan

**Generated:** 2025-01-25
**Branch:** feature/tool-future-lazy-eval
**Status:** Comprehensive Audit Complete - Ready for Implementation

---

# Event-Driven Agent Architecture (EDAA)

**Vision:** Events as the fundamental atom of agent building blocks.

## Executive Summary

This design establishes Events as the primary orchestration mechanism for smolagents-ruby.
Rather than direct method calls between components, all significant operations emit events
that can trigger downstream workflows, enable parallel execution, and provide complete
observability.

**Key Principles:**
1. **Events are atoms** - Every significant action produces an event; events trigger workflows
2. **Models are services** - Agents don't own models; they request generation via events
3. **Parallel by default** - Sub-agents, tool calls, and model requests can run concurrently
4. **Multi-model native** - Different models for different purposes (planning, execution, evaluation)
5. **Provider-agnostic** - Same event flow works across OpenAI, Anthropic, local, hybrid

---

## Current State vs. Target State

### Current Architecture (Synchronous, Tightly Coupled)

```
┌────────────────────────────────────────────────┐
│                  CodeAgent                      │
│                                                 │
│  ┌──────────┐   direct call   ┌─────────────┐  │
│  │ ReActLoop│─────────────────▶│   @model    │  │  ← Model owned by agent
│  │          │◀────────────────│  .generate  │  │  ← Blocking response
│  └────┬─────┘                 └─────────────┘  │
│       │                                         │
│       │ direct call                            │
│       ▼                                         │
│  ┌──────────┐                                  │
│  │  @tools  │  ← Tools owned by agent          │
│  └──────────┘                                  │
└────────────────────────────────────────────────┘
         │
         │ sub_agent.run(task)  ← BLOCKING
         ▼
┌────────────────────────────────────────────────┐
│              Sub-Agent (Sequential)             │
└────────────────────────────────────────────────┘
```

### Target Architecture (Event-Driven, Parallel)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           EventOrchestrator                              │
│  ┌──────────────┐   ┌─────────────────┐   ┌──────────────────────────┐  │
│  │  WorkQueue   │◀──│  EventRouter    │◀──│     Subscribers          │  │
│  │  (priority)  │   │  (dispatch)     │   │  (workflow triggers)     │  │
│  └──────┬───────┘   └─────────────────┘   └──────────────────────────┘  │
│         │                                                                │
│         │ dispatches to workers                                         │
│         ▼                                                                │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                      Worker Pool (parallel)                      │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐            │    │
│  │  │ Agent 1 │  │ Agent 2 │  │ Model A │  │ Model B │            │    │
│  │  │ (code)  │  │ (eval)  │  │ (OpenAI)│  │(Anthro) │            │    │
│  │  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘            │    │
│  │       │            │            │            │                  │    │
│  │       ▼            ▼            ▼            ▼                  │    │
│  │  ┌─────────────────────────────────────────────────────────┐   │    │
│  │  │              Event Bus (all events flow here)            │   │    │
│  │  └─────────────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Design Components

### 1. Event Taxonomy (Expanded)

Events are organized into **domains** that map to concerns:

```ruby
# Generation Domain - Model interactions
ModelGenerateRequested     # Before any model call
ModelGenerateCompleted     # After model returns
ModelGenerateQueued        # Request added to work queue  [NEW]
ModelGenerateDispatched    # Request sent to provider     [NEW]

# Execution Domain - Tool and code execution
ToolCallRequested          # Before tool execution
ToolCallCompleted          # After tool returns
CodeExecutionRequested     # Before code runs in sandbox  [NEW]
CodeExecutionCompleted     # After sandbox returns        [NEW]

# Agent Domain - Agent lifecycle
AgentStepRequested         # Before step begins           [NEW]
StepCompleted              # After step completes
TaskCompleted              # Agent finished task

# Sub-Agent Domain - Parallel agent orchestration
SubAgentRequested          # Request to spawn sub-agent   [NEW]
SubAgentLaunched           # Sub-agent started
SubAgentProgress           # Sub-agent step completed
SubAgentCompleted          # Sub-agent finished

# Orchestration Domain - Work distribution              [NEW]
WorkItemQueued             # Item added to work queue
WorkItemDispatched         # Item sent to worker
WorkItemCompleted          # Worker finished item
WorkerPoolScaled           # Pool size changed

# Planning Domain - Multi-step coordination             [NEW]
PlanGenerationRequested    # Request to generate plan
PlanGenerationCompleted    # Plan ready
PlanStepCompleted          # Plan step executed
PlanDivergence             # Execution diverged from plan
```

### 2. Work Queue Architecture

Generalizes `RequestQueue` (currently models-only) to all work items:

```ruby
# types/work_item.rb
WorkItem = Data.define(
  :id,              # UUID
  :type,            # :model_generate, :tool_call, :sub_agent, :code_execution
  :priority,        # :critical, :high, :normal, :low
  :payload,         # Type-specific data
  :context,         # Execution context (parent_id, spawn_context, etc.)
  :created_at,
  :deadline         # Optional timeout
) do
  def self.model_generate(messages:, model_id:, priority: :normal, **opts)
    create(type: :model_generate, priority:, payload: { messages:, model_id:, **opts })
  end

  def self.sub_agent(task:, agent_config:, priority: :normal, **opts)
    create(type: :sub_agent, priority:, payload: { task:, agent_config:, **opts })
  end
end

# types/work_result.rb
WorkResult = Data.define(:work_item_id, :outcome, :value, :error, :duration_ms, :metrics)
```

### 3. Model Pool (Multi-Model Support)

Agents don't own models; they request generation from a pool:

```ruby
# concerns/orchestration/model_pool.rb
module ModelPool
  # Registry of available models by purpose
  # Different models for different tasks within a single agent

  def register_model(purpose, model, priority: :normal)
    # purpose: :planning, :execution, :evaluation, :summarization, :code_review
    @model_pool[purpose] ||= []
    @model_pool[purpose] << { model:, priority: }
  end

  def request_generation(purpose:, messages:, priority: :normal, &callback)
    model = select_model(purpose)
    work_item = WorkItem.model_generate(
      messages:,
      model_id: model.model_id,
      priority:,
      context: { purpose:, agent_id: }
    )

    emit(Events::ModelGenerateRequested.create(
      model_id: model.model_id,
      purpose:,
      message_count: messages.size
    ))

    enqueue_work(work_item, &callback)
  end

  private

  def select_model(purpose)
    candidates = @model_pool[purpose] || @model_pool[:default]
    # Health-aware selection, load balancing, etc.
    candidates.min_by { |c| c[:model].queue_depth }[:model]
  end
end
```

### 4. Parallel Sub-Agent Orchestration

```ruby
# concerns/orchestration/parallel_agents.rb
module ParallelAgents
  # Spawn multiple sub-agents and await results

  def spawn_parallel(tasks)
    # tasks: [{ persona:, task:, tools:, priority: }, ...]
    futures = tasks.map do |spec|
      work_item = WorkItem.sub_agent(
        task: spec[:task],
        agent_config: build_sub_agent_config(spec),
        priority: spec[:priority] || :normal
      )

      emit(Events::SubAgentRequested.create(
        agent_name: spec[:persona],
        task: spec[:task],
        parent_id: agent_id
      ))

      AgentFuture.new(work_item, orchestrator: self)
    end

    # Return Future that resolves when all complete
    Future.all(futures)
  end

  def spawn_race(tasks)
    # First to complete wins, others cancelled
    futures = tasks.map { |spec| spawn_single(spec) }
    Future.race(futures)
  end

  def spawn_any(tasks, count:)
    # Wait for N completions
    futures = tasks.map { |spec| spawn_single(spec) }
    Future.any(futures, count:)
  end
end
```

### 5. Event-Driven Step Execution

Transform ReActLoop from direct calls to event-driven:

```ruby
# concerns/agents/react_loop/event_driven.rb
module EventDriven
  # Step execution via events instead of direct model.generate

  def execute_step_async(task, step_number)
    emit(Events::AgentStepRequested.create(
      agent_id:,
      step_number:,
      task:
    ))

    # Request model generation (async)
    request_generation(
      purpose: :execution,
      messages: build_step_messages(task, step_number),
      priority: step_priority(step_number)
    ) do |result|
      # Callback when generation completes
      handle_generation_result(result, step_number)
    end
  end

  def handle_generation_result(result, step_number)
    case result
    in { outcome: :success, value: message }
      process_model_response(message, step_number)
    in { outcome: :error, error: }
      handle_generation_error(error, step_number)
    end
  end

  def process_model_response(message, step_number)
    code = extract_code(message)

    # Request code execution (async)
    emit(Events::CodeExecutionRequested.create(
      agent_id:,
      step_number:,
      code:
    ))

    enqueue_work(WorkItem.code_execution(code:, context: execution_context)) do |result|
      handle_execution_result(result, step_number)
    end
  end
end
```

### 6. Orchestrator Core

The central coordinator that processes events and dispatches work:

```ruby
# lib/smolagents/orchestrator.rb
class Orchestrator
  include Events::Consumer
  include Events::Emitter

  def initialize(worker_count: 4)
    @work_queue = PriorityQueue.new
    @workers = WorkerPool.new(count: worker_count)
    @subscriptions = {}

    setup_core_subscriptions
  end

  def setup_core_subscriptions
    # Model generation workflow
    on(Events::ModelGenerateRequested) do |event|
      @work_queue.enqueue(event.to_work_item)
    end

    # Sub-agent workflow
    on(Events::SubAgentRequested) do |event|
      @work_queue.enqueue(event.to_work_item)
    end

    # Completion triggers
    on(Events::ModelGenerateCompleted) do |event|
      # Trigger dependent workflows
      notify_dependents(event.work_item_id, event)
    end

    on(Events::SubAgentCompleted) do |event|
      aggregate_results(event.launch_id, event)
    end
  end

  def run
    loop do
      work_item = @work_queue.dequeue
      worker = @workers.acquire

      worker.execute(work_item) do |result|
        emit(result.to_completion_event)
        @workers.release(worker)
      end
    end
  end
end
```

### 7. DSL Extensions

```ruby
# Extended AgentBuilder DSL
agent = Smolagents.agent
  # Multi-model: different models for different purposes
  .model(:execution) { OpenAIModel.lm_studio("gemma-3n") }
  .model(:planning) { AnthropicModel.new(model_id: "claude-sonnet") }
  .model(:evaluation) { OpenAIModel.new(model_id: "gpt-4o-mini") }

  # Parallel sub-agents (singular noun, matches: planning, memory, evaluation)
  .parallel

  # Event subscriptions (optional, for custom workflows)
  .on(:sub_agent_completed) { |e| aggregate_metrics(e) }

  .build

# Team with heterogeneous models - parallel is automatic
team = Smolagents.team
  .model { OpenAIModel.new(model_id: "gpt-4-turbo") }
  .agent(Smolagents.agent.model { claude_haiku }.tools(:search), as: "researcher")
  .agent(Smolagents.agent.model { claude_opus }.tools(:analysis), as: "analyst")
  .build  # Parallel execution is the default for teams

# Teams can opt-out of parallel for debugging
team = Smolagents.team
  .model { coordinator }
  .agent(researcher, as: "researcher")
  .sequential  # Run agents one at a time (debugging)
  .build

# Team members can also be multi-model
team = Smolagents.team
  .model { coordinator }
  .agent(
    Smolagents.agent
      .model(:execution) { fast_model }
      .model(:evaluation) { smart_model }
      .tools(:search),
    as: "smart_researcher"
  )
  .build
```

**DSL Consistency Principles:**

| Pattern | Examples | New Methods |
|---------|----------|-------------|
| Singular noun features | `planning`, `memory`, `evaluation` | `.parallel` |
| Resource nouns | `model`, `tools`, `executor` | `.model(:purpose)` |
| Opt-out toggles | `evaluation(false)` | `.sequential` |
| Event subscriptions | `on(:event) { }` | No change |

**Design Defaults:**

- `.parallel` - Defaults to `max(2, CPU_cores - 1)` concurrent
- `.model(:purpose)` - Automatically enables event-driven orchestration
- Teams are parallel by default; use `.sequential` to opt-out
- Work queue tuning is in global config, not per-agent DSL

### 8. Advanced Configuration (Internal)

For advanced tuning, use global config (not per-agent DSL):

```ruby
Smolagents.configure do |config|
  # Only configure what you need to override
  config.parallel_concurrency = 4          # Default: CPU cores - 1
  config.work_queue_depth = 1000           # Default: 500
  config.model_request_timeout = 30        # Default: 60 seconds
  config.model_routing do |r|
    r.purpose(:planning).prefer(:anthropic).fallback(:openai)
    r.purpose(:execution).prefer(:local).fallback(:openai)
    r.purpose(:evaluation).prefer(:openai, model: "gpt-4o-mini")
  end
end
```

---

## Implementation Phases

### Phase 1: Foundation (Events + Work Queue) ✅ COMPLETED

**Implemented:**
- `types/work_item.rb` - WorkItem type with factory methods for model_generate, tool_call, code_execution, sub_agent
- `types/work_result.rb` - WorkResult type with success/error/timeout/cancelled outcomes
- 7 new orchestration events: WorkItemQueued, WorkItemDispatched, WorkItemCompleted, AgentStepRequested, CodeExecutionRequested, CodeExecutionCompleted, SubAgentRequested
- `concerns/orchestration/work_queue.rb` - WorkQueue concern with priority buckets, deadline handling, event emission
- Comprehensive test coverage (169 examples)

### Phase 2: Multi-Model Support

**Goal:** Agents can use different models for different purposes

1. **ModelPool Concern** (Week 3)
   - Model registration by purpose
   - Health-aware selection
   - Request routing

2. **DSL Extensions** (Week 3)
   - `.model(:purpose) { }` builder method
   - `.model_pool { }` block configuration
   - Backwards compatible with single `.model { }`

3. **Provider Configuration** (Week 4)
   - Provider registry
   - Rate limit coordination
   - Failover routing

4. **Tests** (Week 4)
   - Multi-model agent tests
   - Provider failover tests
   - Load balancing tests

### Phase 3: Parallel Sub-Agents

**Goal:** Sub-agents can execute concurrently

1. **AgentFuture** (Week 5)
   - Extends FutureBase for agent results
   - Completion tracking via events
   - Cancellation support

2. **ParallelAgents Concern** (Week 5)
   - `spawn_parallel`, `spawn_race`, `spawn_any`
   - Result aggregation
   - Error handling for partial failures

3. **WorkerPool** (Week 6)
   - Thread-based worker management
   - Dynamic scaling
   - Graceful shutdown

4. **Tests** (Week 6)
   - Parallel spawn tests
   - Race condition tests
   - Timeout/cancellation tests

### Phase 4: Event-Driven Orchestration

**Goal:** Full event-driven execution model

1. **Orchestrator Class** (Week 7)
   - Central event routing
   - Work dispatch
   - Subscription management

2. **EventDriven Concern** (Week 7)
   - Transforms ReActLoop to async
   - Callback-based step completion
   - Compatible with Fiber control flow

3. **Integration** (Week 8)
   - Wire up all components
   - Performance tuning
   - Monitoring/observability

4. **Tests** (Week 8)
   - End-to-end orchestration tests
   - Performance benchmarks
   - Chaos testing (failures, timeouts)

### Phase 5: Polish and Documentation

1. **DSL Completion** (Week 9)
   - All builder methods implemented
   - Validation and error messages
   - YARD documentation

2. **Guides** (Week 9)
   - Multi-model configuration guide
   - Parallel agent patterns guide
   - Event subscription cookbook

3. **Performance** (Week 10)
   - Benchmark suite
   - Memory profiling
   - Optimization pass

---

## Testing Strategy

### Unit Tests

```ruby
# spec/smolagents/types/work_item_spec.rb
RSpec.describe Smolagents::Types::WorkItem do
  describe ".model_generate" do
    it "creates work item with correct type and payload"
    it "assigns UUID id"
    it "defaults to normal priority"
  end

  describe ".sub_agent" do
    it "creates work item with agent config"
    it "preserves spawn context"
  end
end

# spec/smolagents/concerns/orchestration/work_queue_spec.rb
RSpec.describe Smolagents::Concerns::Orchestration::WorkQueue do
  describe "#enqueue" do
    it "emits WorkItemQueued event"
    it "respects priority ordering"
    it "enforces max_depth"
  end

  describe "#dequeue" do
    it "returns highest priority first"
    it "respects deadline ordering within priority"
  end
end
```

### Integration Tests

```ruby
# spec/integration/parallel_agents_spec.rb
RSpec.describe "Parallel Agent Execution", :integration do
  it "executes multiple sub-agents concurrently" do
    results = []

    agent = Smolagents.agent
      .model { mock_model }
      .parallel_agents(max_concurrent: 3)
      .build

    # Verify parallel execution via timing
    start = Time.now
    agent.spawn_parallel([
      { persona: :researcher, task: "Task 1" },
      { persona: :analyst, task: "Task 2" },
      { persona: :fact_checker, task: "Task 3" }
    ]).value
    duration = Time.now - start

    # Should complete faster than sequential
    expect(duration).to be < (3 * single_task_duration)
  end
end

# spec/integration/multi_model_spec.rb
RSpec.describe "Multi-Model Agent", :integration do
  it "uses different models for different purposes" do
    planning_model = mock_model(id: "planner")
    execution_model = mock_model(id: "executor")

    agent = Smolagents.agent
      .model(:planning) { planning_model }
      .model(:execution) { execution_model }
      .build

    agent.run("Complex task")

    expect(planning_model).to have_received_calls(1)  # Plan generation
    expect(execution_model).to have_received_calls(3) # Step execution
  end
end
```

### Dry-Run Render Tests

```ruby
# spec/render/event_flow_spec.rb
RSpec.describe "Event Flow Rendering" do
  it "renders complete event sequence for single step" do
    events = capture_events do
      agent.run("Simple task")
    end

    expect(events.map(&:class)).to eq([
      Events::AgentStepRequested,
      Events::ModelGenerateRequested,
      Events::WorkItemQueued,
      Events::WorkItemDispatched,
      Events::ModelGenerateCompleted,
      Events::WorkItemCompleted,
      Events::CodeExecutionRequested,
      Events::CodeExecutionCompleted,
      Events::StepCompleted,
      Events::TaskCompleted
    ])
  end
end
```

---

## Data Types Summary

| Type | Location | Purpose |
|------|----------|---------|
| `WorkItem` | `types/work_item.rb` | Unified work unit for queue |
| `WorkResult` | `types/work_result.rb` | Unified result from workers |
| `AgentFuture` | `executors/agent_future.rb` | Future for sub-agent results |
| `ModelPoolConfig` | `types/model_pool_config.rb` | Multi-model configuration |
| `ProviderConfig` | `types/provider_config.rb` | Provider settings |
| `WorkerPoolConfig` | `types/worker_pool_config.rb` | Worker pool settings |

---

## Backwards Compatibility

The event-driven architecture is **opt-in**:

```ruby
# Classic mode (default) - works exactly as before
agent = Smolagents.agent
  .model { OpenAIModel.new(...) }
  .build

# Event-driven mode - explicit opt-in
agent = Smolagents.agent
  .model { OpenAIModel.new(...) }
  .event_driven(enabled: true)
  .build
```

Single `.model { }` continues to work, mapped to `:execution` purpose internally.

---

## Success Metrics

1. **Parallel Speedup:** 3 sub-agents complete in ~1.5x single agent time (not 3x)
2. **Event Coverage:** 100% of significant operations emit events
3. **Multi-Model:** Single agent can use 3+ different models/providers
4. **Zero Regressions:** All existing tests pass unchanged
5. **Documentation:** Every new DSL method has YARD docs and examples

---

## Current Construct Evolution Map

Shows how existing constructs map to the event-driven architecture:

### Agent Launching Constructs

| Current Construct | Role | EDAA Evolution |
|-------------------|------|----------------|
| `SpawnAgentTool` | Dynamic agent spawning | Emits `SubAgentRequested` → WorkQueue dispatches |
| `ManagedAgentTool` | Static agent delegation | Same, but pre-configured in `WorkerPool` |
| `TeamBuilder` | Team composition | Configures `ModelPool` per team member |
| `AgentBuilder` | Agent construction | Adds `.model(:purpose)`, `.parallel_agents()` |
| `SpawnConfig` | Spawn constraints | Extended to multi-model allowlists |
| `SpawnPolicy` | Enforcement rules | Adds parallel execution limits |
| `SpawnContext` | Execution state | Tracks work_item_id for event correlation |

### Model Constructs

| Current Construct | Role | EDAA Evolution |
|-------------------|------|----------------|
| `@model` (single) | Agent's model | Becomes `ModelPool[:execution]` |
| `RequestQueue` | Model request serialization | Generalized to `WorkQueue` |
| `Model.generate()` | Direct generation | Wrapped by `request_generation(purpose:)` |
| `ModelGenerateRequested` | Event (new) | Triggers work queue dispatch |
| `ModelGenerateCompleted` | Event (new) | Triggers dependent workflows |

### Execution Constructs

| Current Construct | Role | EDAA Evolution |
|-------------------|------|----------------|
| `ReActLoop` | Step execution | Adds `EventDriven` concern (opt-in) |
| `RactorExecutor` | Code sandbox | Receives `WorkItem.code_execution` |
| `ToolFuture` | Lazy tool eval | Extended to `AgentFuture` for sub-agents |
| `Fiber` control flow | Interactive execution | Preserved, events bubble through yields |
| `AsyncQueue` | Background event processing | Upgraded to `WorkQueue` with priorities |

### Event Constructs

| Current Construct | Status | EDAA Evolution |
|-------------------|--------|----------------|
| `Events::Emitter` | ✅ Ready | No changes, used everywhere |
| `Events::Consumer` | ✅ Ready | Adds workflow trigger subscriptions |
| `Events::AsyncQueue` | ✅ Ready | Worker thread model preserved |
| `Events::Mappings` | ✅ Ready | Extended with new event types |
| `Events::Registry` | ✅ Ready | Documents all events by domain |

### New Constructs Required

| Construct | Purpose | Dependencies |
|-----------|---------|--------------|
| `WorkItem` | Unified work representation | `Data.define` type |
| `WorkResult` | Unified result representation | `Data.define` type |
| `WorkQueue` | Priority queue for all work | Extends `RequestQueue` pattern |
| `WorkerPool` | Parallel work execution | Thread pool management |
| `ModelPool` | Multi-model registration | Purpose → Model mapping |
| `AgentFuture` | Sub-agent result tracking | Extends `FutureBase` |
| `Orchestrator` | Central event routing | Combines queue + workers + events |
| `EventDriven` concern | Async step execution | Opt-in for ReActLoop |

---

## Architecture Reinforcement Checklist

Each phase reinforces our architecture patterns:

### Ruby 4.0 Idioms
- [ ] All new types use `Data.define` with factory methods
- [ ] Pattern matching in event handlers (`case event in`)
- [ ] Endless methods for simple predicates
- [ ] Frozen data structures throughout

### Concern Decomposition
- [ ] `WorkQueue` < 100 lines (extract types to `types/`)
- [ ] `ModelPool` < 100 lines (single responsibility)
- [ ] `ParallelAgents` < 100 lines (extract combinators)
- [ ] `EventDriven` < 100 lines (wrap, don't rewrite)

### Type System
- [ ] `WorkItem` in `types/work_item.rb` with full YARD
- [ ] `WorkResult` in `types/work_result.rb` with predicates
- [ ] `ModelPoolConfig` in `types/model_pool_config.rb`
- [ ] `WorkerPoolConfig` in `types/worker_pool_config.rb`

### Event Coverage
- [ ] Every queue operation emits event
- [ ] Every worker dispatch emits event
- [ ] Every completion emits event
- [ ] Event IDs enable full trace correlation

### DSL Consistency
- [ ] `.model(:purpose)` extends existing `.model { }` (same method, optional param)
- [ ] `.parallel` follows singular noun pattern (like `planning`, `memory`, `evaluation`)
- [ ] `.sequential` follows opt-out pattern (like `evaluation(false)`)
- [ ] All methods return `self` for chaining (immutable builder)
- [ ] TeamBuilder gets `.sequential` for opt-out of parallel default
- [ ] No new `with_*` methods on AgentBuilder (that pattern is ModelBuilder-specific)
- [ ] Register all new methods with `register_method` for `.help` support

### Test Coverage
- [ ] Unit tests for all new types
- [ ] Concern tests for all new concerns
- [ ] Integration tests for multi-model scenarios
- [ ] Integration tests for parallel execution
- [ ] Render tests for event sequences

---

## Priority Legend

- **P0 (Critical)**: Blocks future work, violates core architecture rules
- **P1 (High)**: Significant inconsistency, affects maintainability
- **P2 (Medium)**: Code quality improvement, reduces technical debt
- **P3 (Low)**: Polish, nice-to-have refinements

---

## Completed Work Summary

### P0 Critical - All Fixed
- Concern boundary violations analyzed - all concerns compliant under 100 code lines
- Type extractions: ValidationRejection, ExecutionFeedback, RetryPolicy, HealthStatus, ModelInfo, QueuedRequest, QueueStats, FailedRequest
- Sub-module splits: formatting/structure.rb split into primitives, arrays, hashes, helpers
- Event mappings: MixedRefinementCompleted, DSL callback names fixed
- Tests: incremental_execution.rb spec created

### P1 Architecture - All Fixed
- InlineTool inherits from Tool
- ManagedAgentTool uses symbol keys
- Builder check_frozen! on all methods
- Model adapter signatures standardized
- GoalAbandoned dead code removed

---

## Remaining P1 Items

### 6. Events Never Emitted: ToolCallRequested

**Problem:** Event defined but never emitted anywhere.

**Decision Required:**
- Option A: Emit in Ractor executor before `tool.call` (low-level, comprehensive)
- Option B: Remove event and mapping (if not needed for observability)
- Option C: Keep as-is (mapping exists for future use)

**Status:** Deferred - requires architecture decision on observability model.

---

## P1: High Impact - Affects Maintainability

### 7. Type System: AgentConfig Has Too Many Fields (12 fields, 11 optional)

**Problem:** Configuration type mixes unrelated concerns.

**Current fields in `types/agent_config.rb`:**
- Planning: `planning_interval`, `planning_templates`
- Behavioral: `evaluation_enabled`, `custom_instructions`, `refine_config`, `sync_events`
- Observability: `observe_mode`, `summarizer_model`
- Core: `max_steps`, `authorized_imports`, `spawn_config`, `memory_config`

**Recommendation:** Split into focused types:
```ruby
PlanningConfig = Data.define(:interval, :templates)
BehavioralConfig = Data.define(:custom_instructions, :evaluation_enabled, :refine_config, :sync_events)
ObservabilityConfig = Data.define(:observe_mode, :summarizer_model)
```

---

### 8. ~~Ruby 4.0 Idiom: Struct.new vs Data.define~~ ✅ REVIEWED

**Status:** Both files have proper RuboCop disables with comments documenting why mutability is needed:
- `utilities/pattern_matching/final_answer.rb:9` - ParseState needs mutation for character parsing
- `concerns/agents/self_refine/loop.rb:27` - RefinementState needs mutation for loop iteration

No changes needed - the documentation is already in place.

---

### 9. ~~Naming: Underscore-Prefixed Public API Methods~~ ✅ FIXED

**Status:** Added `@api private` documentation and rationale to all FutureBase files:
- `executors/future_base.rb` - Core rationale for the naming convention
- `executors/tool_future.rb` - Reference to FutureBase
- `executors/ractor_lazy/tool_future.rb` - Reference to FutureBase
- `executors/ractor_lazy/future_combinators.rb` - Reference to FutureBase

The underscore prefix is intentional for duck-typing and avoiding method conflicts.

---

### 10. ~~Code Duplication: Search Tool Message Templates~~ ✅ ALREADY ADDRESSED

**Status:** `Support::ResultTemplates` mixin already exists at `tools/support/result_templates.rb`.

Both ArxivSearch and WikipediaSearch include this mixin and use its DSL (`empty_message`,
`next_steps_message`). The message *content* differs between tools (ArXiv talks about papers,
Wikipedia talks about articles) - this is proper domain customization, not duplication.

No changes needed - the pattern is already extracted.

---

### 11. Code Duplication: Model Adapter Response Parsing

**Problem:** OpenAI and Anthropic response parsers share 70%+ code structure.

**Files:**
- `models/openai/response_parser.rb`
- `models/anthropic/response_parser.rb`

**Shared Pattern:**
- Include `ModelSupport::ResponseParsing`
- Define `parse_response(response)` with provider-specific extraction
- Extract content, tool calls, token usage
- Convert to `ChatMessage`

**Fix:** Create `ModelAdapterBase` with shared parsing logic and provider hooks.

---

### 12. Code Duplication: Retry Logic (3 implementations)

**Problem:** Three separate retry implementations with overlapping logic.

| File | Purpose |
|------|---------|
| `concerns/resilience/retryable.rb` | Generic retry with exponential backoff |
| `concerns/resilience/retry_execution.rb` | Model-specific retry with events |
| `concerns/resilience/tool_retry.rb` | Tool-specific event-driven retry |

**All three handle:** Attempt counting, backoff calculation, error filtering, max attempts, event emission.

**Fix:** Consolidate into `BaseRetryHandler` with hooks for callbacks.

---

### 13. ~~Constants: Unfrozen Numeric Constants (5 instances)~~ ✅ NOT APPLICABLE

**Status:** Integers in Ruby are already immutable. Adding `.freeze` is redundant and
RuboCop's `Style/RedundantFreeze` correctly rejects this pattern.

No changes needed - current code is correct.

---

### 14. Architecture Gap: Models Don't Emit Events

**Problem:** Models have no event emission for observability.

**Missing events:**
- `ModelGenerateRequested` - before LLM call
- `ModelGenerateCompleted` - after response
- `ToolCallParsed` - tool extraction

**Impact:** External monitoring can't track model behavior without coupling.

**Fix:** Add `include Events::Emitter` to Model base class with optional emission.

---

### 15. Architecture Gap: Tools Don't Emit Events

**Problem:** Most tools don't emit `ToolCallCompleted` with metrics.

**Impact:** Per-tool monitoring, rate limiting feedback unavailable.

**Exception:** `ManagedAgentTool` does emit events (good example).

**Fix:** Add event emission to `Tool::Execution` module.

---

## P2: Medium Impact - Code Quality

### 16. Ruby 4.0 Idiom: Lambda vs Stabby Lambda Syntax

**Problem:** Mixing `lambda { }` with `->` stabby lambda syntax.

**Files with `lambda { }` that should use `->`:**
- `config/validators.rb:19-31` (3 lambdas)
- `persistence/errors.rb:49,54,60,71,77,84` (6 lambdas)

**Fix:** Standardize on `->` stabby lambda syntax throughout.

---

### 17. Model Adapter: Inconsistent Method Signatures

**Problem:** `build_params` signatures differ between adapters.

**OpenAI** (`models/openai/request_builder.rb:38`):
```ruby
def build_params(messages:, stop_sequences:, temperature:, max_tokens:, tools:, response_format:)
```

**Anthropic** (`models/anthropic/request_builder.rb:35`):
```ruby
def build_params(messages:, stop_sequences:, temperature:, max_tokens:, tools:)
# response_format NOT accepted!
```

**Fix:** Both should accept same parameters (Anthropic can ignore response_format).

---

### 18. Model Adapter: Anthropic max_tokens Default Behavior

**Problem:** AnthropicModel applies `DEFAULT_MAX_TOKENS = 4096` even when not specified.

**File:** `models/anthropic_model.rb:118`

**OpenAI:** Passes nil if not specified.

**Impact:** Same builder config produces different behavior across adapters.

**Fix:** Document this difference OR make both behave identically.

---

### 19. Test Coverage Gap: Ractor Lazy Execution System (669 lines)

**Problem:** Complex concurrent code with partial test coverage.

**Files needing dedicated specs:**
- `executors/ractor_lazy/batch_handling.rb` (95 lines)
- `executors/ractor_lazy/context.rb` (85 lines)
- `executors/ractor_lazy/future_combinators.rb` (101 lines)
- `executors/ractor_lazy/future_resolution.rb` (60 lines)

**Fix:** Add comprehensive unit tests for wave resolution, dependency handling.

---

### 20. Test Coverage Gap: Orchestrators

**Problem:** Ralph Loop and Agent Pool have minimal test coverage.

**Files:**
- `orchestrators/agent_pool.rb` (176 lines)
- `orchestrators/ralph_loop.rb`

**Fix:** Add tests for parallel execution, timeout handling, error scenarios.

---

### 21. Concern Naming Inconsistency

**Problem:** Some concerns use `Concern` suffix, others don't.

| Has Suffix | No Suffix |
|------------|-----------|
| `ModelConcern` | `ToolResolution` |
| `SettersConcern` | `Callbacks` |
| `BuildConcern` | `Resolution` |

**Fix:** Standardize - either all use suffix or none do.

---

### 22. Formatting Concerns Not Used Internally

**Problem:** Powerful formatting concerns exist but aren't used by internal code.

**Available concerns:**
- `Concerns::ResultFormatting` - `.as_markdown`, `.as_table`, `.as_list`
- `Concerns::MessageFormatting` - LLM message formatting
- `Concerns::StructureFormatting` - Data structure description

**Missing usage:**
- SearchTool builds results manually instead of using ResultFormatting
- Model adapters reimplement MessageFormatting instead of using concern
- Builder introspection uses custom formatting instead of StructureFormatting

**Fix:** Refactor internal code to use shared concerns.

---

## P3: Low Impact - Polish

### 23. Endless Method Opportunities

**Problem:** Some simple methods could be converted to endless definitions.

**Examples:**
- Response parsers have multi-line methods that could be one-liners
- Simple predicate methods not using `=` syntax

**Status:** Not urgent - existing code is correct and readable.

---

### 24. Pattern Matching Opportunities

**Problem:** Some `case/when` could be `case/in` for better Ruby 4.0 idioms.

**Files:**
- `builders/team_builder/resolution_concern.rb:34-43`
- `builders/agent_builder/model_concern.rb:58-66`

**Fix:** Convert type-based dispatch to pattern matching.

---

### 25. Verbose Method Names

**Problem:** Some method names could be simplified.

| Current | Suggested |
|---------|-----------|
| `validate_required_attributes!` | `validate_attributes!` |
| `strip_html_from_results` | `strip_html` or `clean_results` |
| `extract_and_format_value` | `format_value` |

**Status:** Low priority - existing names are clear.

---

### 26. Test Quality: Implementation Detail Testing

**Problem:** Some tests verify method calls rather than behavior.

**Example in `agents/agent_spec.rb:25-32`:**
```ruby
expect(Smolagents::RactorExecutor).to have_received(:new)
```

**Better:** Test observable behavior, not internal implementation.

---

## Architecture Strengths

- **Type system:** 85+ Data.define types including new WorkItem/WorkResult
- **Event system:** 50+ events with 7 new orchestration events
- **Executor abstraction:** All code through executor, no direct eval
- **Builder pattern:** Lazy model evaluation, immutable configs
- **Test suite:** 13,900+ examples, 96.72% coverage, zero RuboCop violations
- **Zero circular dependencies:** Clean concern layering
- **Work Queue:** Generalized priority queue for orchestration
