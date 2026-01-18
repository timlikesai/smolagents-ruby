# smolagents-ruby

Highly-testable agents that think in Ruby 4.0.

---

## Current Status

| Metric | Value | Status |
|--------|-------|--------|
| Ruby Version | 4.0 | Target |
| RSpec Tests | 6527 | Passing |
| Line Coverage | 94.37% | Met |
| RuboCop Offenses | 0 | ✓ |

### Architecture Scores (2026-01-18)

| Area | Score | Notes |
|------|-------|-------|
| Ruby 4.0 Idioms | 9/10 | 2 justified Struct.new exceptions |
| Self-Documenting | 10/10 | Full registry introspection |
| Test Infrastructure | 10/10 | AutoGen, AgentSpec, MockModel |
| Concurrency | 10/10 | Fiber/Thread/Ractor correct |
| Timeout Handling | 10/10 | RuboCop enforced, zero sleep() |
| Event Completeness | 10/10 | Tool/queue/health/config all emit |
| Reliability | 10/10 | DLQ, backpressure, fallback, graceful shutdown |
| IRB Experience | 10/10 | Tab completion, progress, auto-logging |
| Code DRYness | 10/10 | Utilities extracted, concerns composable |

---

## Track Status

All implementation tracks complete:

| Track | Description | Status |
|-------|-------------|--------|
| A: Health | K8s liveness/readiness probes | ✓ |
| B: IRB UX | Tab completion, spinners, progress | ✓ |
| C: Reliability | Dead Letter Queue, retry, events | ✓ |
| D: Scaling | Distributed rate limiting | Deferred |
| E: Pre-Act Planning | arXiv:2505.09970, 70% recall improvement | ✓ |
| F: Self-Refine | arXiv:2303.17651, 20% quality improvement | ✓ |
| G: Test Quality | Zero offenses, 94%+ coverage | ✓ |
| H: Consolidation | HTTP unified, concerns DRYed | ✓ |

---

## Architecture

### Execution Model

```
Agent (Fiber for control flow)
    │
    ▼
Code Executor
    │
    ├── LocalRuby (fast, BasicObject sandbox)
    │   └── ~0ms overhead, TracePoint ops limit
    │
    └── Ractor (secure, memory isolation)
        └── ~20ms overhead, message-passing
```

### Concurrency Primitives

```ruby
# Fiber: Control flow (yield steps, request input)
Fiber.new { agent_loop }.resume

# Thread: Background work (both use same worker pattern)
Thread.new { process_loop }  # nil from queue.pop = exit

# Ractor: Code sandboxing
Ractor.new(code) { |c| sandbox.eval(c) }
```

### Key Utilities

```ruby
# Recursive transformations (DRY)
Utilities::Transform.symbolize_keys(hash)
Utilities::Transform.freeze(obj)
Utilities::Transform.dup(obj)

# Similarity calculations (DRY)
Utilities::Similarity.jaccard(set_a, set_b)
Utilities::Similarity.string(a, b)
```

### Event System

Concerns include `Events::Emitter` directly for composability:
```ruby
module MyConcern
  include Events::Emitter

  def do_work
    emit(Events::WorkCompleted.create(...))
  end
end
```

---

## Backlog

### Deferred

| Item | Reason |
|------|--------|
| STRATUS Checkpointing | Infrastructure needed (see below) |
| Multi-language execution | Ruby-only focus |
| Distributed rate limiting | Single-process sufficient for gem |
| GraphRAG | Complex, low priority |

#### STRATUS Checkpointing (NeurIPS 2025) — 150% improvement

**Status**: 40% complete — strong serialization foundation, missing orchestration

**What exists**:
- ✅ Serializable types (all 40+ types have `to_h`)
- ✅ Step history in `AgentMemory`
- ✅ 40+ lifecycle events for state changes
- ✅ Immutable `Data.define` structures
- ✅ Token/timing tracking per step

**Infrastructure needed**:
- ○ `Checkpoint` type with run_id, steps, memory, context
- ○ Persistence layer (file/DB adapter)
- ○ Restore mechanism to resume from checkpoint
- ○ Undo operators for reversible actions
- ○ Transaction boundaries for rollback grouping
- ○ Severity assessment for state quality metrics

---

## Principles

- **Ruby 4.0 Only** - No backwards compatibility
- **Simple by Default** - One line for common cases
- **IRB-First** - Interactive sessions work great out of the box
- **Event-Driven** - All state changes emit events
- **100/10 Rule** - Modules ≤100 lines, methods ≤10 lines
- **Test Everything** - MockModel for fast deterministic tests
- **Forward Only** - Delete unused code, no legacy shims
- **Defense in Depth** - Multiple independent security layers
- **Composable Concerns** - Include what you need, no guards
