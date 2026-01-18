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
| Event Completeness | 9/10 | Tool/queue/health all emit |
| Reliability | 9/10 | Backpressure, fallback, graceful shutdown |
| IRB Experience | 9/10 | Auto-logging, visible progress |

---

## Next Up (Ordered by Effort)

### Quick Wins (< 30 min each)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | **Show help hint on IRB load** | ~15 min | Users discover `Smolagents.help` |
| 2 | **Emit event on model change** | ~20 min | Full observability for model switches |
| 3 | **ConfigurationChanged event** | ~30 min | Track config changes at runtime |

### Medium (1-2 hrs each)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 4 | **Custom .inspect for Agent/Builder** | ~1 hr | Readable REPL output |
| 5 | **Liveness vs Readiness health checks** | ~1-2 hrs | K8s-style health separation |

### Larger (3+ hrs)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 6 | **Dead Letter Queue** | ~2-3 hrs | Store failed requests for debugging |
| 7 | **Tab completion hints** | ~2-3 hrs | IRB method suggestions |
| 8 | **Inline progress (spinners)** | ~3-4 hrs | Visual feedback during runs |
| 9 | **Distributed rate limiting** | ~4-6 hrs | Redis-backed for multi-process |

### Not Pursuing

| Item | Reason |
|------|--------|
| Step types use Deconstructable | Works correctly, cosmetic only |
| Agent lifecycle events | Edge case for debugging |
| Token streaming | Significant model adapter changes |

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
- HealthCheckRequested/Completed, ModelDiscovered
- CircuitStateChanged, RateLimitViolated
- ToolIsolationStarted/Completed, ResourceViolation
- QueueRequestStarted/Completed

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
