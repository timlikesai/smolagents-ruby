# smolagents-ruby

Highly-testable agents that think in Ruby 4.0.

---

## Current Status

| Metric | Value | Status |
|--------|-------|--------|
| Ruby Version | 4.0 | Target |
| RSpec Tests | 6361 | Passing |
| Line Coverage | 93.94% | Met |
| RuboCop Offenses | 2 | Minor |

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
| IRB Experience | 10/10 | Auto-logging, .inspect, help hint |

---

## Remaining Work

### Parallel Tracks

Work is organized into independent tracks that can be developed concurrently.

```
Track A: Health ──────────────────────────────────────────── ✓ COMPLETE
         Liveness/Readiness health checks for K8s deployments

Track B: IRB UX ──────────────────────────────────────────────────
         Tab Completion (2-3 hrs) ─┬─> Both use Interactive module
         Spinners (3-4 hrs) ───────┘   and event system

Track C: Reliability ───────────────────────────────────── ✓ COMPLETE
         Dead Letter Queue with retry, events, FIFO eviction

Track D: Scaling (DEFERRED) ──────────────────────────────────────
         Distributed Rate Limiting (4-6 hrs)
         └── Requires Redis, out of scope for gem
```

### Track A: Health (Independent)

**Liveness vs Readiness Health Checks** (~1-2 hrs)

| Subtask | Description | Effort |
|---------|-------------|--------|
| A1. Define check types | `liveness_check` (can accept traffic) vs `readiness_check` (dependencies ready) | 20 min |
| A2. Separate endpoints | `healthy?` → `live?` + `ready?` predicates | 20 min |
| A3. Readiness checks | Add dependency checks (model loaded, tools initialized) | 30 min |
| A4. K8s probe format | Return JSON compatible with K8s probe expectations | 20 min |

**Foundation provided:** Enables proper K8s/container deployments.

---

### Track B: IRB UX (Parallelizable)

**Tab Completion** (~2-3 hrs)

| Subtask | Description | Effort |
|---------|-------------|--------|
| B1. IRB completion hook | Register completion proc with `IRB.conf[:MAIN_CONTEXT].completion_proc` | 30 min |
| B2. Builder method completion | Complete `.tools(`, `.model(`, `.as(` etc. | 45 min |
| B3. Tool name completion | Complete tool names after `.tools(` | 30 min |
| B4. Persona/specialization completion | Complete persona names after `.as(` | 30 min |

**Spinners/Progress** (~3-4 hrs)

| Subtask | Description | Effort |
|---------|-------------|--------|
| B5. ProgressReporter class | Subscribe to events, manage terminal output | 45 min |
| B6. Spinner component | Animated spinner using ANSI escape codes | 30 min |
| B7. Step progress bar | Show `[Step 3/10]` style progress | 30 min |
| B8. Token counter | Live token usage display | 30 min |
| B9. Integrate with Interactive | Auto-enable in IRB when not piped | 30 min |

**Dependencies:**
- B5-B9 depend on event system (already complete)
- B1-B4 are standalone IRB integration

**Can parallelize:** B1-B4 and B5-B9 are independent tracks within Track B.

---

### Track C: Reliability (Independent)

**Dead Letter Queue** (~2-3 hrs)

| Subtask | Description | Effort |
|---------|-------------|--------|
| C1. DLQ data type | `FailedRequest = Data.define(:request, :error, :attempts, :failed_at)` | 15 min |
| C2. In-memory store | Simple array with max size, FIFO eviction | 30 min |
| C3. Queue integration | Move failed requests to DLQ instead of dropping | 30 min |
| C4. Retry from DLQ | `retry_failed(n)` to reprocess failed requests | 30 min |
| C5. DLQ events | `RequestFailed`, `RequestRetried` events | 20 min |
| C6. Optional file persistence | Serialize to JSON for crash recovery | 30 min |

**Foundation provided:** Debugging failed requests, crash recovery.

---

### Track D: Scaling (DEFERRED)

**Distributed Rate Limiting** (~4-6 hrs) — *Not recommended for gem scope*

| Subtask | Description | Effort |
|---------|-------------|--------|
| D1. Storage abstraction | Interface for memory/Redis backends | 1 hr |
| D2. Redis adapter | Connection pooling, Lua scripts for atomicity | 2 hrs |
| D3. Sliding window in Redis | Distributed sliding window implementation | 1 hr |
| D4. Configuration | Redis URL, pool size, key prefix | 30 min |

**Recommendation:** Defer. Single-process rate limiting is sufficient for a gem. Users deploying at scale can implement their own.

---

### Execution Order Recommendations

**If working solo (sequential):**
```
1. Track A (Liveness/Readiness) — Quick win, enables deployments
2. Track C (DLQ) — Builds on recent queue work while fresh
3. Track B (Tab Completion) — IRB polish
4. Track B (Spinners) — IRB polish
```

**If parallelizing (2 agents):**
```
Agent 1: Track A → Track C
Agent 2: Track B (all)
```

**If parallelizing (3 agents):**
```
Agent 1: Track A (Health)
Agent 2: Track B1-B4 (Tab Completion)
Agent 3: Track C (DLQ) → Track B5-B9 (Spinners)
```

---

### Foundation Already Complete

These foundations enable the remaining work:

| Foundation | Enables |
|------------|---------|
| Event system | Spinners subscribe to step/tool events |
| RequestQueue | DLQ captures failed requests |
| Interactive module | Tab completion hooks into IRB |
| Checks module | Liveness/Readiness extends existing health |
| LoggingSubscriber | Pattern for ProgressReporter |

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

# Thread: Background work
Thread.new { async_event_queue }

# Ractor: Code sandboxing
Ractor.new(code) { |c| sandbox.eval(c) }
```

---

## Completed Work

### 2026-01-18

**Track A: K8s-Style Health Checks**
- `live?` and `ready?` predicates for agents
- `liveness_probe` and `readiness_probe` JSON responses
- Checks: model present, memory present, model healthy, tools initialized

**Track C: Dead Letter Queue**
- FailedRequest data type with error details and retry tracking
- In-memory store with configurable max size, FIFO eviction
- Auto-capture failures in RequestQueue worker
- `retry_failed(n)` for reprocessing failed requests
- RequestFailed and RequestRetried events

**Quick Wins for 10/10 Scores**
- Help hint shown in IRB welcome banner
- ModelChanged event on model switch
- ConfigurationChanged event after configure block
- Custom .inspect for Agent and Builder

**IRB Experience & Reliability**
- Auto-enable LoggingSubscriber in IRB sessions
- Log levels changed from :debug to :info for visibility
- Tool setup, queue processing emit events
- Default bounded queue (100), graceful shutdown
- Discovery fallback to cached models

**Security Hardening**
- ArgumentValidator, DangerDetector, TypeValidator
- SpawnPolicy, SpawnContext for privilege escalation prevention
- RateLimitPolicy with 3 strategies

**Configuration Centralization**
- 38+ constants extracted to Config.defaults
- Categories: http, execution, isolation, memory, models, agents, security, health

**Event System**
- HealthCheckRequested/Completed, ModelDiscovered, ModelChanged
- CircuitStateChanged, RateLimitViolated, ConfigurationChanged
- ToolIsolationStarted/Completed, ResourceViolation
- QueueRequestStarted/Completed, ToolInitialized

**Infrastructure**
- Docker removed, Ruby-only executors
- Self-documenting registries for Events, Concerns, Builders
- Tool isolation with ThreadExecutor timeout pattern

---

## Backlog

### Research-Backed Features

| Feature | Research | Improvement |
|---------|----------|-------------|
| Pre-Act Planning | arXiv:2505.09970 | 70% |
| Self-Refine | arXiv:2303.17651 | 20% |
| STRATUS Checkpointing | NeurIPS 2025 | 150% |

### Deferred

| Item | Reason |
|------|--------|
| Multi-language execution | Ruby-only focus |
| Distributed rate limiting | Single-process sufficient for gem |
| GraphRAG | Complex, low priority |

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
