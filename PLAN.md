# smolagents-ruby

Highly-testable agents that think in Ruby 4.0.

---

## Current Status

| Metric | Value | Status |
|--------|-------|--------|
| Ruby Version | 4.0 | Target |
| RSpec Tests | 6410 | Passing |
| Line Coverage | 94.06% | Met |
| RuboCop Offenses | 2 | Minor |
| Executors | LocalRuby, Ractor | Simplified |

---

## Research Findings (2026-01-17)

Comprehensive architecture audit across 8 parallel research agents revealed:

### Critical Gaps (High Priority)

| Gap | Impact | Status |
|-----|--------|--------|
| **IRB silent-by-default** | Users see no output during 30+ second runs | Pending (UX phase) |
| **No discovery entry point** | Users don't know `Smolagents.help` exists | Pending (UX phase) |
| ~~**ModelHealth no events**~~ | ~~Can't observe health checks, model changes~~ | ✓ Done |
| ~~**CircuitBreaker no events**~~ | ~~Can't observe state transitions~~ | ✓ Done |
| ~~**RateLimiter callbacks only**~~ | ~~Events not integrated with event system~~ | ✓ Done |

### Architecture Strengths Confirmed

| Area | Status | Details |
|------|--------|---------|
| **Ruby 4.0 Concurrency** | ✓ Idiomatic | Fiber.scheduler, Ractor, Thread::Queue all correct |
| **Reliability Patterns** | ✓ Enterprise-grade | Backpressure, circuit breaker, fallback chains |
| **Zero sleep() calls** | ✓ Clean | Non-blocking throughout |
| **Testing Infrastructure** | ✓ Comprehensive | AutoGen, AgentSpec DSL, MockModel auto-stub |
| **Self-Documenting** | ✓ Complete | Events, Concerns, Builders all have registries |

### Medium Priority Gaps

| Gap | Impact | Notes |
|-----|--------|-------|
| ~~47 hard-coded constants~~ | ~~Users can't tune for environment~~ | ✓ Extracted to Config.defaults |
| Tool initialization inconsistent | SearchTool skips super() | Standardize pattern |
| ~~FiberExecutor redundant~~ | ~~Delegates to ThreadExecutor~~ | ✓ Removed |
| Token streaming missing | No model output streaming | Would improve UX |

### Cloud Patterns at Gem Scale

Reliability implementation maps to AWS/Kinesis patterns:

| Cloud Pattern | Gem Component | Status |
|---------------|---------------|--------|
| SQS/Kinesis backpressure | RequestQueue | ✓ |
| Exponential backoff | RetryPolicy | ✓ |
| Circuit breaker | Stoplight integration | ✓ |
| Failover/routing | ModelFallback | ✓ |
| Rate limiting | RateLimiter | ✓ |
| Dead Letter Queue | — | ❌ Missing |
| Distributed rate limiting | — | ❌ Missing |

---

## Recent Completions

### Security Hardening ✓ (2026-01-18)

Defense-in-depth security with multiple independent layers:

| Component | Purpose |
|-----------|---------|
| `ArgumentValidator` | Type checking, injection detection for tool inputs |
| `DangerDetector` | Shell metacharacters, SQL injection, path traversal |
| `ValidationRule` | Data.define for validation configuration |
| `SpawnPolicy` | Sub-agent spawning restrictions |
| `SpawnContext` | Depth tracking for privilege escalation prevention |
| `RateLimitPolicy` | Per-tool rate limiting with 3 strategies |

Rate limiting strategies: `token_bucket`, `sliding_window`, `fixed_window`

### Configuration Centralization ✓ (2026-01-18)

Consolidated 38+ hard-coded constants into `Config.defaults`:

| Category | Settings |
|----------|----------|
| `http` | timeout_seconds, rate_limit_status_codes, retriable_status_codes |
| `execution` | max_operations, max_output_length, max_message_iterations |
| `isolation` | default_timeout_seconds, max_memory_bytes, max_ast_depth |
| `memory` | chars_per_token, max_reflections |
| `models` | per-provider defaults (OpenAI: 8192, Anthropic: 4096) |
| `agents` | refinement_max_iterations, refinement_feedback_source |
| `security` | max_prompt_length, max_validation_errors |
| `health` | healthy_latency_ms, degraded_latency_ms, timeout_ms |

Access via `Config.default(:http, :timeout_seconds)` or `Config.defaults_for(:health)`.

### Event System Completeness ✓ (2026-01-18)

All reliability concerns now emit events:

| Event | Emitted By |
|-------|------------|
| `HealthCheckRequested` | ModelHealth::Checks |
| `HealthCheckCompleted` | ModelHealth::Checks |
| `ModelDiscovered` | ModelHealth::Discovery |
| `CircuitStateChanged` | CircuitBreaker |
| `RateLimitViolated` | RateLimiter |

### Concurrency Architecture Audit ✓

Comprehensive analysis of Fiber/Thread/Ractor usage:

| Primitive | Purpose | Correctness |
|-----------|---------|-------------|
| **Fiber** | Cooperative control flow (agent ↔ consumer) | ✓ Fixed context detection |
| **Thread** | Background I/O, parallel tools, async events | ✓ Proper mutex usage |
| **Ractor** | Memory-isolated code execution | ✓ Message-passing IPC |

### Docker Removal ✓

Simplified execution model to Ruby-only:

| Before | After |
|--------|-------|
| 3 executors (LocalRuby, Docker, Ractor) | 2 executors (LocalRuby, Ractor) |
| Multi-language (Ruby, Python, JS, TS) | Ruby only |
| Container orchestration | Native Ractor isolation |
| ~500ms container startup | ~20ms Ractor startup |

### Self-Documenting Infrastructure ✓

| System | API |
|--------|-----|
| Events | `Smolagents.events`, `Smolagents.event(:name)`, `Smolagents.event_docs` |
| Concerns | `Smolagents.concerns`, `Smolagents.concern(:name)`, `Smolagents.concern_graph` |
| Builders | `.summary`, `.available_methods`, `.ready_to_build?` |

### Tool Isolation Layer ✓

Defense-in-depth isolation for tool execution:

| Component | Purpose |
|-----------|---------|
| `ResourceLimits` | Data.define for timeout, memory, operations limits |
| `ResourceMetrics` | Track actual usage during execution |
| `IsolationResult` | Immutable result with success/violation state |
| `ToolIsolationStarted` | Event fired when isolation begins |
| `ToolIsolationCompleted` | Event fired on completion with metrics |
| `ResourceViolation` | Event fired when limits exceeded |
| `ToolIsolation` concern | Callbacks: `on_timeout`, `on_violation` |
| `ThreadExecutor` | Safe `Thread.join` pattern with timeout |
| Builder DSL | `on_tool_isolation_started`, `on_isolation`, `on_violation` |

---

## Architecture (Ruby 4.0)

### Execution Model

```
Agent (Fiber for control flow)
    │
    ▼
Code Executor
    │
    ├── LocalRuby (fast, BasicObject sandbox)
    │   └── ~0ms overhead
    │   └── TracePoint ops limit
    │   └── Same-process isolation
    │
    └── Ractor (secure, memory isolation)
        └── ~20ms overhead
        └── Message-passing for tools
        └── Full memory separation
```

### Concurrency Primitives

```ruby
# Fiber: Control flow (yield steps, request input)
Fiber.new { agent_loop }.resume

# Thread: Background work
Thread.new { async_event_queue }

# Ractor: Code sandboxing
Ractor.new(code) { |c| sandbox.eval(c) }

# Thread-local (shared across Fibers)
Thread.current.thread_variable_set(:key, value)

# Fiber-local (per-Fiber)
Thread.current[:key] = value
```

---

## Security & Isolation

### Completed ✓

| Layer | Components |
|-------|------------|
| **Types** | `ResourceLimits`, `ResourceMetrics`, `IsolationResult`, `ValidationRule` |
| **Events** | `ToolIsolationStarted`, `ToolIsolationCompleted`, `ResourceViolation` |
| **Concern** | `ToolIsolation` with `on_timeout`, `on_violation` callbacks |
| **Executor** | `ThreadExecutor` with safe `Thread.join` timeout pattern |
| **Builder DSL** | `on_tool_isolation_started`, `on_isolation`, `on_violation` handlers |
| **Argument Validation** | `ArgumentValidator`, `DangerDetector`, `TypeValidator` |
| **Rate Limiting** | `RateLimitPolicy`, 3 strategies (token_bucket, sliding_window, fixed_window) |
| **Spawn Restrictions** | `SpawnPolicy`, `SpawnContext`, depth/tool/step limits |

### Planned

| Feature | Priority | Description |
|---------|----------|-------------|
| Model output validation | Medium | Sanitize LLM responses before execution |
| Audit logging | Medium | Security event trail |

---

## Next Up

### 1. Interactive UX

After foundations are solid, improve IRB experience:

| Task | Impact | Code Location |
|------|--------|---------------|
| Auto-enable logging in IRB | Users see progress | `smolagents.rb` on load |
| Show discovery message | Users find help | `smolagents.rb` banner |
| Builder DSL for logging | `.logging(level:)` | `builders/agent_builder.rb` |
| Contextual help | Builder suggests next steps | `interactive/help.rb` |

**Pattern to implement:**
```ruby
# In smolagents.rb, detect IRB and auto-enable
if Interactive.session? && !ENV["SMOLAGENTS_QUIET"]
  Telemetry::LoggingSubscriber.enable(level: :info)
  puts "Smolagents loaded! Type Smolagents.help for guide"
end
```

### 2. Low Priority Events

| Concern | Missing Events |
|---------|----------------|
| Tool | `ToolInitialized` |
| Config | `ConfigurationChanged` |

### 3. Documentation

| Task | Reason |
|------|--------|
| Document Fiber scheduler setup | Users don't know how to enable |
| Tool initialization pattern | Standardize SearchTool pattern |

---

## Backlog

### Research-Backed Features (Blocked on Polish)

| Feature | Research | Improvement |
|---------|----------|-------------|
| Pre-Act Planning | arXiv:2505.09970 | 70% |
| Self-Refine | arXiv:2303.17651 | 20% |
| STRATUS Checkpointing | NeurIPS 2025 | 150% |
| Dynamic Tools | ToolMaker, TOOLFLOW | Context-aware |

### Deferred (Lacking Evidence)

| Item | Reason |
|------|--------|
| Multi-language execution | Removed Docker, Ruby-only focus |
| StateSnapshot | Overhead without proven value |
| Debate Pattern | Only 3% improvement |
| GraphRAG | Complex, low priority |

---

## Principles

- **Ruby 4.0 Only** - No backwards compatibility
- **Simple by Default** - One line for common cases
- **IRB-First** - Interactive sessions must work great out of the box
- **Event-Driven** - All state changes emit events; no silent operations
- **100/10 Rule** - Modules ≤100 lines, methods ≤10 lines
- **Test Everything** - MockModel for fast deterministic tests
- **Forward Only** - Delete unused code, no legacy shims
- **Ractor for Security** - Memory isolation for untrusted code
- **Defense in Depth** - Multiple independent security layers; no single point of failure
- **Cloud Patterns at Gem Scale** - Backpressure, circuit breakers, failover chains
