# smolagents-ruby

Highly-testable agents that think in Ruby 4.0.

---

## Current Status

| Metric | Value | Status |
|--------|-------|--------|
| Ruby Version | 4.0 | Target |
| RSpec Tests | 6492 | Passing |
| Line Coverage | 93.93% | Met |
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
| IRB Experience | 10/10 | Tab completion, progress, auto-logging |

---

## Track Status

```
Track A: Health ──────────────────────────────────────────── ✓ COMPLETE
         Liveness/Readiness health checks for K8s deployments

Track B: IRB UX ──────────────────────────────────────────── ✓ COMPLETE
         Tab Completion ──────┬─> Both use Interactive module
         Spinners/Progress ───┘   and event system

Track C: Reliability ───────────────────────────────────── ✓ COMPLETE
         Dead Letter Queue with retry, events, FIFO eviction

Track D: Scaling ─────────────────────────────────────────── DEFERRED
         Distributed Rate Limiting - out of scope for gem
```

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

**Track B: IRB UX - Tab Completion**
- Completion module hooks into IRB's completion system
- Builder method completion (`.model`, `.tools`, `.as`, `.with`, etc.)
- Tool/toolkit name completion after `.tools(`
- Persona completion after `.as(` or `.persona(`
- Specialization completion after `.with(`
- Auto-enabled on Interactive.activate!

**Track B: IRB UX - Progress Display**
- Spinner component with animated ANSI frames
- StepTracker for [Step 3/10] progress display
- TokenCounter for cumulative token usage tracking
- Progress module subscribes to instrumentation events
- Chains to previous subscriber (coexists with LoggingSubscriber)
- Auto-enabled in TTY sessions via Interactive.activate!

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
