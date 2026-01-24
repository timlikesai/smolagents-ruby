# Local Development Plan

> "Reinforcing our systems with our systems, our architecture with our architecture, our idioms with our idioms."

This plan tracks local work that isn't ready for GitHub Issues yet. Cross-cutting concerns are being addressed before creating focused, atomic issues.

---

## Current State

**Test Suite:**
- 6971 examples, 0 failures, 1 pending
- 94.09% line coverage
- Clean output (no noise, no warnings)
- Fast execution (~3.3 seconds)

**Context Orchestration (Phase 0 complete):**
- Foundation: Layer, Provider, Registry, RubyPresenter, BudgetAllocator, Orchestrator
- Providers: StepContext (TACTICAL), Planning (STRATEGIC), Reflections (STRATEGIC)
- Integration: Unified `inject_orchestrated_context` in runtime
- Shared `MessageFormatting` concern for injection helpers
- ~303 specs for context module
- Ready for Phase 1: Goal Tracking

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

## Integration Points Discovery

Research agents identified the critical integration point for Context Orchestration:

### Primary Integration Point

**File:** `lib/smolagents/agents/runtime/accessors.rb:50-54`

```ruby
def write_memory_to_messages(summary_mode: false)
  messages = @memory.to_messages(summary_mode:)
  messages = inject_plan_into_messages(messages)  # ← REPLACE
  inject_context_into_messages(messages)          # ← REPLACE
end
```

This is WHERE Context Orchestrator will replace the scattered injections.

### Current Injection Points (To Be Unified)

| Location | Current Behavior | New Provider |
|----------|------------------|--------------|
| `agents/runtime/accessors.rb:50-54` | `write_memory_to_messages()` | **Orchestrator entry point** |
| `concerns/agents/step_context.rb` | Step budget injection | `StepContextProvider` |
| `concerns/agents/planning/injection.rb` | Plan injection | `PlanningProvider` |
| `concerns/agents/reflection_memory/injection.rb` | Reflections injection | `ReflectionProvider` |
| `agents/runtime/initialization.rb:40` | Memory setup | Layer 4 (History) |
| `agents/core.rb:51-52` | Model initialization | Layer 0 (System) |

### Existing Patterns to Reuse

| Pattern | Location | Reuse For |
|---------|----------|-----------|
| **Registry** | `events/registry.rb` | `Context::Registry` |
| **Store** | `concerns/agents/reflection_memory/store.rb` | `GoalStore`, `WorkingMemoryStore` |
| **Injection** | `concerns/agents/reflection_memory/injection.rb` | Provider pattern |
| **Concern Composition** | `concerns/agents/*.rb` | Provider modules |
| **Config Types** | `types/agent_config.rb` | `ContextConfig` |
| **Builder Pattern** | `builders/*.rb` | DSL extensions |

### DSL Pattern to Follow

From `builders/planning_concern.rb`:

```ruby
def planning(interval_or_enabled = :_default_, interval: nil, templates: nil)
  check_frozen!
  resolved_interval = resolve_planning_interval(...)
  with_config(planning_interval: resolved_interval, ...)
end
```

New DSL methods follow this pattern: `check_frozen!` → validate → `with_config()`.

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
| `working_memory` | 1 (Persistent) | 100 | New |
| `plan` | 2 (Strategic) | 80 | Refactor from `planning/injection.rb` |
| `goals` | 2 (Strategic) | 70 | New |
| `reflections` | 2 (Strategic) | 60 | Refactor from `reflection_memory/injection.rb` |
| `step_context` | 3 (Tactical) | 90 | Refactor from `step_context.rb` |
| `last_tool` | 3 (Tactical) | 80 | New |
| `history` | 4 (History) | 50 | From Memory |

---

## Ruby-Native Context Formatting

### The Insight

The agent thinks in Ruby code. The context should look like Ruby too.

### Example Output

```ruby
# ╔══════════════════════════════════════════════════════════════════╗
# ║ CONTEXT                                                          ║
# ╚══════════════════════════════════════════════════════════════════╝

# == Goal ==
# Find and summarize Ruby 4.0 release notes
# Progress: Found 2 sources, analyzing content

# == Execution State ==
# step:      3 of 10 (7 remaining)
# last_tool: search ✓ (1.2s)
# budget:    ~2000 tokens remaining

# == Plan ==
# 1. [✓] Search for Ruby 4.0 release notes
# 2. [→] Extract key features              <- YOU ARE HERE
# 3. [ ] Summarize findings

# == Available Tools ==
# search(query:)        -> String    # Web search
# final_answer(answer:) -> void      # Complete the task

# Continue from here:
```

### Research Support

| Paper | Key Finding | Improvement |
|-------|-------------|-------------|
| PAL (ICML 2023) | Code for intermediate reasoning | +11-40% over CoT |
| Program of Thoughts (TMLR 2023) | Disentangle computation via code | +12% average |
| Code Prompting | NL to code structure | +8-22% on conditional reasoning |

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

### Phase 0: Context Orchestration Foundation

**Principle:** Each component is independently testable. Integration tests verify composition.

#### 0.1 Layer Type ✅

**File:** `lib/smolagents/context/layer.rb` (35 lines)

Data.define enum with SYSTEM, PERSISTENT, STRATEGIC, TACTICAL, HISTORY, TASK layers.
Class methods: `[]`, `by_priority`, `truncatable`.

**Tests:** 32 specs

#### 0.2 Provider Protocol ✅

**File:** `lib/smolagents/context/provider.rb` (77 lines)

Module with required methods (`context_key`, `context_layer`, `context_contribution`) and
optional methods with defaults (`context_priority`, `context_relevance`, `context_optional?`, `context_active?`).

**Tests:** 20 specs

#### 0.3 Registry ✅

**File:** `lib/smolagents/context/registry.rb` (78 lines)

Mirrors Events::Registry pattern. Methods: `register`, `[]`, `all`, `providers`, `registered?`, `for_layer`, `by_layer`, `clear!`, `size`.

**Tests:** 22 specs

#### 0.4 RubyPresenter ✅

**File:** `lib/smolagents/context/ruby_presenter.rb` (121 lines)

Ruby-native formatting. Methods: `section`, `list_section`, `kv_section`, `tools_section`, `continuation`, `boxed_header`, `context_block`, `progress`, `status`.

**Tests:** 27 specs

#### 0.5 Budget Allocator ✅

**File:** `lib/smolagents/context/budget_allocator.rb` (96 lines)

Token budget allocation by priority × relevance. Guarantees minimum for required providers.

**Tests:** 26 specs

#### 0.6 Orchestrator ✅

**File:** `lib/smolagents/context/orchestrator.rb` (122 lines)

Main assembly logic. Returns `AssemblyResult` with content, layers hash, and metadata.

**Tests:** 26 specs

**Commit:** `8ea052b feat: add Context Orchestration foundation (Phase 0.1-0.6)`

---

#### 0.7 Wire into Agent ✅

**Files created:**
- `lib/smolagents/concerns/agents/context_orchestration.rb` (65 lines)
- `lib/smolagents/context/providers/base.rb` (69 lines)

**Implementation:**
- `AdapterProvider`: Data.define wrapper for content procs
- `Providers.step_context`: delegates to `build_step_context` at TACTICAL layer
- `Providers.planning`: wraps `plan_context` at STRATEGIC layer
- `ContextOrchestration` concern: initializes orchestrator, provides `inject_orchestrated_context`

**Tests:** 33 specs

**Commit:** `5ad21e7 feat: wire Context Orchestrator into AgentRuntime (Phase 0.7)`

**Observations for 0.8:**
- Duplicate "inject before last user" logic in StepContext and Planning::Injection → extract to shared helper
- Runtime state access via `instance_variable_get` → expose public methods or use context object
- Plan content building as Providers class method → consider dedicated builder

---

#### 0.8 Complete Context Orchestration Switch-over ✅

**Implementation:**
- Add `ReflectionProvider` for reflection memory at STRATEGIC layer (priority 60)
- Update `write_memory_to_messages` to use `inject_orchestrated_context` only
- Wire reflection provider into `ContextOrchestration` concern
- Extracted `inject_before_last_user` to shared `MessageFormatting` concern (7618c51)
- Old injection concerns remain for backward compatibility and unit testing

**Files modified:**
- `lib/smolagents/agents/runtime/accessors.rb` - simplified to single orchestrator call
- `lib/smolagents/concerns/agents/context_orchestration.rb` - added reflection provider
- `lib/smolagents/context/providers/base.rb` - added `Providers.reflections`
- `lib/smolagents/concerns/formatting/messages.rb` - shared injection helpers

**Tests:** 17 new specs for reflection integration and message assembly

**Commits:**
- `7618c51 refactor: extract message injection to MessageFormatting concern`
- `fef8ec9 feat: complete Phase 0.8 - Context Orchestration switch-over`

---

## Phase 0 Complete: Context Orchestration Foundation

All context injection now flows through the unified Context Orchestrator:
- **Step Context** (TACTICAL, priority 90) - step budget, last tool outcome
- **Planning** (STRATEGIC, priority 80) - current plan, progress
- **Reflections** (STRATEGIC, priority 60) - lessons from past failures

The old injection concerns (`StepContext`, `Planning::Injection`) remain for unit testing
and backward compatibility, but the main runtime flow uses `inject_orchestrated_context`.

**Total new specs:** ~300 for context module
**Test suite:** 6971 examples, 0 failures, 94.09% coverage

---

### Phase 1: Goal Tracking (As Context Provider)

#### 1.1 Goal Type

**File:** `lib/smolagents/types/goal.rb` (~30 lines)

```ruby
Goal = Data.define(:id, :description, :status, :progress, :parent_id, :created_at) do
  def complete(evidence:) = with(status: :complete, progress: evidence)
  def active? = status == :active
  def root? = parent_id.nil?
end
```

**Tests:** ~50 specs covering creation, transitions, hierarchy, pattern matching

#### 1.2 Goal Store

**File:** `lib/smolagents/concerns/agents/goal_tracking/store.rb` (~50 lines)

Thread-safe bounded store. Same pattern as `ReflectionMemory::Store`.

**Tests:** ~60 specs covering add, update, current, thread safety

#### 1.3 Goal Tracking Concern

**File:** `lib/smolagents/concerns/agents/goal_tracking.rb` (~60 lines)

Implements `Context::Provider`. Layer 2 (Strategic), priority 70.

**Tests:** ~70 specs covering provider protocol, relevance scoring

#### 1.4 Goal Events

**Extend:** `lib/smolagents/events/registry/built_in.rb`

Add: `goal_created`, `goal_progress`, `goal_complete`

#### 1.5 Builder Integration

**Extend:** `lib/smolagents/builders/agent_builder.rb`

```ruby
def goals(visible: false, max: 10)
  check_frozen!
  with_config(goal_config: GoalConfig.new(visible:, max_goals: max))
end
```

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
- Inner loop is ReAct execution
- Working memory bridges iterations
- Completion detection via goal state

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

## Test Coverage Targets

| Component | Unit Tests | Integration | Total |
|-----------|------------|-------------|-------|
| Layer | 40 | - | 40 |
| Provider | 50 | - | 50 |
| Registry | 45 | - | 45 |
| RubyPresenter | 45 | - | 45 |
| BudgetAllocator | 60 | - | 60 |
| Orchestrator | 80 | 100 | 180 |
| Goal | 50 | - | 50 |
| GoalStore | 60 | - | 60 |
| GoalTracking | 70 | 50 | 120 |
| **Total** | **~500** | **~150** | **~650** |

---

## Implementation Order

```
Phase 0: Context Orchestration (THE foundation)
    ↓
    0.1 Layer → 0.2 Provider → 0.3 Registry
    ↓
    0.4 RubyPresenter (parallel with above)
    ↓
    0.5 BudgetAllocator → 0.6 Orchestrator
    ↓
    0.7 Wire into Agent (accessors.rb:50-54)
    ↓
    0.8 Refactor existing injections
    ↓
Phase 1: Goals (as Context Provider)
    ↓
Phase 2: IRB Experience (visibility)
    ↓
Phase 3: Working Memory (truncation survival)
    ↓
Phase 4: Loop Orchestration (Ralph-style iteration)
```
