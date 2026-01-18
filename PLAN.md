# smolagents-ruby

Highly-testable agents that think in Ruby 4.0.

---

## Current Status

| Metric | Value | Status |
|--------|-------|--------|
| Ruby Version | 4.0 | Target |
| RSpec Tests | 6527 | Passing |
| Line Coverage | 94.36% | Met |
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

Track E: Pre-Act Planning ────────────────────────────────── ✓ COMPLETE
         arXiv:2505.09970 | 70% Action Recall improvement
         ✓ Plan injection into action generation prompts
         ✓ Plan divergence tracking with alignment scoring
         ✓ PlanDivergence event (mild/moderate/severe levels)

Track F: Self-Refine ─────────────────────────────────────── ✓ COMPLETE
         arXiv:2303.17651 | 20% quality improvement
         ✓ .refine() builder DSL with full config options
         ✓ SelfRefine concern integrated in AgentRuntime
         ✓ refine_config field in AgentConfig

Track G: Test & Code Quality ─────────────────────────────── ✓ COMPLETE
         Zero RuboCop offenses, 94.45% coverage, 184 new tests

Track H: Consolidation ───────────────────────────────────── ✓ COMPLETE
         Unified HTTP layer, deleted 3 redundant implementations
```

---

## Track G: Test & Code Quality ✓

### Completed (2026-01-18)

**1. RuboCop Zero Offenses**
- ✓ Removed stale NoSleep exclusions from `.rubocop.yml`
- ✓ Extracted `DiscoveryHttp` module from `discovery.rb` (111→100 lines)
- ✓ Refactored `queue.rb` with `build_queue_stats` helper (11→10 lines)
- ✓ Refactored `circuit_breaker.rb` with `build_stoplight` helper (13→10 lines)

**2. Coverage Improvements (+184 tests)**
- ✓ `discovery_http.rb`: 46% → 100% (28 tests)
- ✓ `async_queue.rb`: 31% → 100% (37 tests)
- ✓ `events/mappings.rb`: 24% → 100% (46 tests)
- ✓ `error_hints.rb`: 28% → 96% (47 tests)
- ✓ All files now above 30% per-file minimum

**3. Polish Items (completed)**
- ✓ BehaviorTracer: Added `tracer_factory:` dependency injection for test mocking
- ✓ RSpec/VerifiedDoubles: Disabled globally in `spec/.rubocop.yml` (56 inline disables removed)

---

## Track H: Consolidation ✓

### Completed (2026-01-18)

**HTTP Layer Unified**

Reduced from 4 parallel HTTP implementations to 2:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        HTTP IMPLEMENTATIONS (After)                      │
├─────────────────────┬──────────────┬───────────────┬────────────────────┤
│ Implementation      │ Library      │ SSRF Protected│ Location           │
├─────────────────────┼──────────────┼───────────────┼────────────────────┤
│ Primary (Faraday)   │ Faraday      │ ✓ Yes         │ lib/smolagents/http/│
│ Local Discovery     │ Net::HTTP    │ N/A (local)   │ discovery/         │
│                     │              │               │ http_client.rb     │
└─────────────────────┴──────────────┴───────────────┴────────────────────┘
```

**Changes:**
- ✓ Deleted `discovery_http.rb` - Discovery now uses `Concerns::Http`
- ✓ Deleted `ractor_safe_client.rb` - Agents use tools for HTTP (architectural decision)
- ✓ Deleted `ractor_model.rb` - No longer needed without ractor HTTP
- ✓ Added `timeout:` parameter to `Http::Requests.get/post` and `Http::Connection`
- ✓ Documented `discovery/http_client.rb` exemption (local-only for LM Studio/Ollama)

**Concerns Consolidation (completed)**
- ✓ `RequestBase` module extracts common control flow pattern (confirmation/user_input/escalation)
- ✓ `Utilities::Similarity` unifies 3 Jaccard implementations across codebase
- ✓ `Results::Formatting` merges BasicFormatting/MetadataFormatting with `include_metadata:` option
- ✓ Deleted unused facades: Parsing, Monitoring, Isolation, Sandbox (sub-modules used directly)
- ✓ Simplified namespace modules: Support, Validation, Models, Tools (removed 400+ lines of duplicate docs)

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

**Track E: Pre-Act Planning Enhancement**
- Plan injection into action generation prompts via `Planning::Injection`
- Plan divergence tracking with tool alignment scoring via `Planning::Divergence`
- `PlanDivergence` event with severity levels (mild/moderate/severe)
- Automatic decrement of off-topic counter when steps realign

**Track F: Self-Refine Integration**
- `.refine()` builder DSL with full configuration options
- `refine_config` field added to `AgentConfig`
- `SelfRefine` concern included in `AgentRuntime`
- `initialize_self_refine` wired in agent initialization
- Supports `:execution`, `:self`, `:evaluation` feedback sources

**Track H: HTTP Consolidation**
- Deleted `discovery_http.rb` — Discovery uses `Concerns::Http` with SSRF protection
- Deleted `ractor_safe_client.rb` — Agents use tools for HTTP (architectural decision)
- Deleted `ractor_model.rb` — No longer needed
- Added `timeout:` parameter propagation through HTTP stack
- Documented `discovery/http_client.rb` exemption (local-only discovery)

**Track H: Concerns Consolidation**
- Created `RequestBase` module with `yield_request` for DRY control flow
- Created `Utilities::Similarity` with unified `jaccard`, `string`, `terms` methods
- Merged `BasicFormatting`/`MetadataFormatting` into single `Formatting` module
- Deleted 4 unused facade files: `parsing.rb`, `monitoring.rb`, `isolation.rb`, `sandbox.rb`
- Simplified 5 namespace modules: `support.rb`, `validation.rb`, `models.rb`, `tools.rb`, `agents.rb`

**Track G: Test Infrastructure Polish**
- Added `tracer_factory:` dependency injection to `BehaviorTracer` for test mocking
- Disabled `RSpec/VerifiedDoubles` globally (duck-typed interfaces incompatible with strict verification)
- Removed 56 inline RuboCop disables now handled by global config

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
