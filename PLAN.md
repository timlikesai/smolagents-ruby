# Local Development Plan

> "Reinforcing our systems with our systems, our architecture with our architecture, our idioms with our idioms."

This plan tracks local work that isn't ready for GitHub Issues yet. Cross-cutting concerns are being addressed before creating focused, atomic issues.

---

## Current State

**Test Suite:**
- 7059 examples, 0 failures, 1 pending
- 94.18% line coverage
- Clean output (no noise, no warnings)
- Fast execution (~3.4 seconds)

**Context Orchestration (Phase 0 complete):**
- Foundation: Layer, Provider, Registry, RubyPresenter, BudgetAllocator, Orchestrator
- Providers: StepContext (TACTICAL), Planning (STRATEGIC), Reflections (STRATEGIC)
- Integration: Unified `inject_orchestrated_context` in runtime
- Shared `MessageFormatting` concern for injection helpers
- ~303 specs for context module

**Phase 0 Cleanup (complete):**
- Removed dead code: Planning::Injection, ReflectionMemory::Injection modules (~496 lines)
- Standardized provider APIs: use public methods instead of instance_variable_get
- Renamed `ExecutorExecutionOutcome` → `CodeOutcome` (shorter, clearer)
- Removed unused `inject_all_before_last_user` helper
- Simplified `StepContext` to only expose `build_step_context` for providers
- Split `react_loop/execution.rb` into `loop.rb` + `monitoring.rb` (Phase 4 prep)

Ready for Phase 2: IRB Experience

---

## Design Principles

Patterns that work well and should be maintained:

1. **Concerns organization** - Clean separation of cross-cutting concerns
2. **Builder DSL pattern** - Consistent use of `Data.define` with fluent builders
3. **Type system** - Excellent use of immutable Data types
4. **Sub-module organization** - When a folder has 3+ related files, it's well-structured
5. **Context Orchestration** - Clean provider-based architecture with layered context
6. **100/10 rule** - Modules ≤100 lines, methods ≤10 lines (with noted exceptions)

**Naming conventions:**
- No "Enhanced*", "Advanced*", "Improved*" class names - naming is appropriately direct
- Directory names follow Ruby snake_case convention correctly
- Tool naming is consistent (`*_search.rb` pattern for search tools)

---

## Vision: The Agent Loop as Information Flow

```
   ┌──────────────────────────────────────────────────────────────┐
   │                     THE AGENT LOOP                           │
   │                                                              │
   │   ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐  │
   │   │ CONTEXT │───▶│  MODEL  │───▶│ EXECUTE │───▶│ OBSERVE │  │
   │   │ ASSEMBLY│    │  CALL   │    │ ACTIONS │    │ RESULTS │  │
   │   └─────────┘    └─────────┘    └─────────┘    └─────────┘  │
   │        ▲                                            │        │
   │        └────────────────────────────────────────────┘        │
   │                     feedback loop                            │
   └──────────────────────────────────────────────────────────────┘
```

**The key insight:** Context Assembly is WHERE the intelligence lives. Everything else is mechanical.

---

## Context Orchestration Architecture

### The Layered Context Model

```
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 0: SYSTEM (immutable base)                                │
│ System prompt, tool definitions, behavioral instructions        │
└─────────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 1: PERSISTENT (survives truncation)                       │
│ Working memory: current goal, essential state, blockers         │
│ ALWAYS included, highest priority, ~1000 token budget           │
└─────────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 2: STRATEGIC (guides decision-making)                     │
│ Current plan, goal hierarchy, reflections from past failures    │
└─────────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 3: TACTICAL (informs this step)                           │
│ Step budget, last tool result, iteration context                │
└─────────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 4: HISTORY (conversation context)                         │
│ Past actions, observations, tool results                        │
│ Subject to truncation/masking when over budget                  │
└─────────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 5: TASK (the current request)                             │
│ User's task/prompt for this step - always last, always included │
└─────────────────────────────────────────────────────────────────┘
```

### Provider Protocol

```ruby
module Context::Provider
  # Required
  def context_key = raise NotImplementedError
  def context_layer = Layer::STRATEGIC
  def context_contribution(budget:) = nil

  # Optional
  def context_priority = 50
  def context_relevance(task:, step:) = 1.0
  def context_optional? = true
  def context_active? = true
end
```

### Built-in Providers

| Provider | Layer | Priority | Source |
|----------|-------|----------|--------|
| `working_memory` | 1 (Persistent) | 100 | New (Phase 3) |
| `plan` | 2 (Strategic) | 80 | ✅ Done |
| `goals` | 2 (Strategic) | 70 | New (Phase 1) |
| `reflections` | 2 (Strategic) | 60 | ✅ Done |
| `step_context` | 3 (Tactical) | 90 | ✅ Done |
| `last_tool` | 3 (Tactical) | 80 | New |
| `history` | 4 (History) | 50 | From Memory |

---

## Reliability Patterns to Adopt

From codebase research:

| Pattern | Location | Apply To |
|---------|----------|----------|
| **Retry with backoff** | `concerns/resilience/retry_with_backoff.rb` | Provider errors |
| **Circuit breaker** | `concerns/resilience/circuit_breaker.rb` | Model calls |
| **Rate limiting** | `concerns/resilience/rate_limiter.rb` | API calls |
| **Mutex protection** | `reflection_memory/store.rb` | All stores |
| **LRU caching** | `discovery/cache.rb` | Token estimation |

### Reliability Principles

- **Fail gracefully:** Provider errors don't crash assembly
- **Thread-safe stores:** Mutex protection on all state
- **Bounded resources:** Max goals, max iterations, token budgets
- **Observable:** Every decision can be inspected

---

## Work Queue

### Phase 0: Context Orchestration Foundation ✅

**Principle:** Each component is independently testable. Integration tests verify composition.

| Step | File | Status |
|------|------|--------|
| 0.1 Layer Type | `context/layer.rb` | ✅ |
| 0.2 Provider Protocol | `context/provider.rb` | ✅ |
| 0.3 Registry | `context/registry.rb` | ✅ |
| 0.4 RubyPresenter | `context/ruby_presenter.rb` | ✅ |
| 0.5 Budget Allocator | `context/budget_allocator.rb` | ✅ |
| 0.6 Orchestrator | `context/orchestrator.rb` | ✅ |
| 0.7 Wire into Agent | `context_orchestration.rb` | ✅ |
| 0.8 Switch-over | `runtime/accessors.rb` | ✅ |

**Cleanup completed:**
- Removed ~496 lines of dead injection code
- Renamed `ExecutorExecutionOutcome` → `CodeOutcome`
- Standardized provider APIs
- Split `execution.rb` into `loop.rb` + `monitoring.rb`

---

### Phase 1: Goal Tracking (As Context Provider) ✅

| Step | File | Status |
|------|------|--------|
| 1.1 Goal Type | `types/goal.rb` | ✅ 90 lines, 135 specs |
| 1.2 Goal Store | `goal_tracking/store.rb` | ✅ 131 lines, 141 specs |
| 1.3 Goal Tracking Concern | `goal_tracking.rb` | ✅ 110 lines, 138 specs |
| 1.4 Goal Events | `events/registry/built_in.rb` | ✅ 4 events added |
| 1.5 Builder Integration | `builders/goals_concern.rb` | ✅ DSL method |
| 1.6 Context Provider | `context/providers/base.rb` | ✅ Priority 70, STRATEGIC |

**Key design decisions:**
- Goals are agent-scoped (subagents isolated)
- No eviction - completed goals become history
- Provider decides context contribution, not store
- Task becomes root goal automatically

---

### Phase 2: IRB Experience

Interactive visibility for goals and context in IRB/Pry sessions.

- Status line updates showing current goal
- Magic method `agent.goals` for inspection
- Configurable verbosity levels

---

### Phase 3: Working Memory Provider

Layer 1 (Persistent) provider that survives truncation:

- Extracts essential state from goals
- Maintains compact representation
- Always included in context assembly

---

### Phase 4: Loop Orchestration

Goal-driven iteration loop (Ralph-style):

- Outer loop manages goal progress
- Inner loop is ReAct execution (via `execution/loop.rb`)
- Working memory bridges iterations
- Completion detection via goal state

**Prep completed:** Split `execution.rb` into `loop.rb` + `monitoring.rb` for clean composition.

---

### Phase 5: Type Consolidation

Cleanup naming confusion and consolidate parallel abstractions.

#### 5.1 ToolOutput Consolidation

**Current state:**
- `ToolOutput` (type) - Data.define for tool execution tracking (id, observation, is_final_answer)
- `ToolResult` (class) - Chainable wrapper with fluent operations

**Analysis:**
- `ToolOutput` is barely used (only in async error handling)
- `ActionStep.action_output` holds the actual result
- `ToolResult.@data` is already the immutable raw output

**Action:**
- Remove `ToolOutput` type (absorb into ToolResult or ActionStep)
- Update async concern to use ToolResult directly
- Simplify to: tools return `ToolResult`, steps record `action_output`

#### 5.2 Result Type Naming (Optional)

Three related concepts:

| Type | Location | Purpose |
|------|----------|---------|
| `ExecutionResult` | `executors/` | Raw output from code execution |
| `ExecutionOutcome` | `types/` | Generic outcome with state machine |
| `CodeOutcome` | `types/` | Code-specific outcome wrapping ExecutionResult |

**Potential simplification:**
- `ExecutionResult` → `CodeOutput` (what it actually is)
- Keep `ExecutionOutcome` and `CodeOutcome` as-is (already clear)

---

### Phase 6: Structural Cleanup (Ongoing)

Lower priority items to address when touching related code.

#### 6.1 Files Exceeding 100-Line Limit

| File | Lines | Notes |
|------|-------|-------|
| `dsl.rb` | 355 | Core DSL, acceptable |
| `events/registry/built_in.rb` | 313 | Data-heavy, acceptable |
| `concerns/registrations.rb` | 300 | Registration definitions |
| `search_tool/configuration.rb` | 275 | **Split candidate** → builder pattern |
| `team_builder.rb` | 242 | Builder complexity |
| `errors.rb` | 225 | Error definitions |
| `anthropic_model.rb` | 216 | Model adapter |
| `models/queue/dead_letter.rb` | 216 | Queue handling |
| `fiber_execution.rb` | 207 | Fiber execution |

**Priority:** `search_tool/configuration.rb` - Extract to builder pattern

#### 6.2 Directory Structure

**Deep nesting (14 levels):**
```
concerns/resilience/rate_limiter/strategies/token_bucket.rb
```

**Consideration:** Flatten rate limiter strategies to `Concerns::RateLimiting`.

**Single-file directories:**
- `observation_router/summarizer.rb` - Could merge into parent

#### 6.3 Support Folder Inconsistency

"Support" folders used inconsistently:
- `builders/support/` (5 files + 2 sub-dirs)
- `concerns/support/` (helper files)
- `models/support/` (1 file)
- `tools/support/` (3 files)
- `types/support/` (utilities)
- `builders/base/` (similar purpose, different name)

**Action:** Standardize when touching these areas.

---

## File Structure

```
lib/smolagents/
├── context/
│   ├── layer.rb              # Layer enum (Data.define)
│   ├── provider.rb           # Provider protocol (concern)
│   ├── registry.rb           # Provider registry
│   ├── ruby_presenter.rb     # Ruby-native formatting
│   ├── budget_allocator.rb   # Token budget allocation
│   └── orchestrator.rb       # Main assembly logic
├── concerns/agents/
│   ├── goal_tracking/
│   │   ├── store.rb          # Thread-safe goal store
│   │   └── injection.rb      # Provider implementation
│   ├── react_loop/
│   │   └── execution/
│   │       ├── loop.rb       # Core step iteration
│   │       └── monitoring.rb # Events and observability
│   └── working_memory/
│       └── provider.rb       # Layer 1 persistent state
└── types/
    └── goal.rb               # Goal Data.define
```

---

## Dependencies

```
Context::Layer           ← no dependencies
Context::RubyPresenter   ← no dependencies
Context::Provider        ← Layer
Context::Registry        ← Provider
Context::BudgetAllocator ← Registry
Context::Orchestrator    ← All above + AgentMemory

Goal (type)              ← no dependencies
GoalStore                ← Goal, Mutex
GoalTracking (concern)   ← Context::Provider, GoalStore

WorkingMemory            ← Context::Provider, GoalTracking
GoalDrivenLoop           ← GoalTracking, WorkingMemory, Orchestrator
```

---

## Implementation Order

```
Phase 0: Context Orchestration ✅
    ↓
Phase 1: Goals (as Context Provider)
    ↓
Phase 2: IRB Experience (visibility)
    ↓
Phase 3: Working Memory (truncation survival)
    ↓
Phase 4: Loop Orchestration (Ralph-style iteration)
    ↓
Phase 5: Type Consolidation (ToolOutput, naming)
    ↓
Phase 6: Structural Cleanup (ongoing, opportunistic)
```

---

## Reference: Fiber Execution Layers

Five fiber-related files serve **distinct layers** (not duplication):

| File | Layer | Purpose |
|------|-------|---------|
| `react_loop/fiber_execution.rb` | Agent | Interactive sessions, yields ActionSteps |
| `executors/fiber_execution.rb` | Code | Tool batching with ToolFutures |
| `executors/ractor_lazy/fiber_executor.rb` | Code | Ractor-based isolation |
| `tools/managed_agent/fiber_execution.rb` | Tool | Subagent coordination |
| `executors/incremental_execution.rb` | Code | Step-by-step execution |

No consolidation needed - each handles a different execution context.
