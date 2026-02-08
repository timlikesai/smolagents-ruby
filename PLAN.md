# smolagents-ruby Implementation Plan

**Branch:** feature/tool-future-lazy-eval
**Updated:** 2026-02-07
**Version:** 5.1 (Ruby-Native Prompt Formatting)

---
## Executive Summary

**Core Insight**: "Help the model by giving it less to think about, not more."

**Current Priority**: Phase I (Ruby-native prompt formatting) complete. Prompt pipeline now speaks Ruby 4.0 — YARD docs for tools, Ruby vocabulary throughout, `it` keyword coaching. Next: real local GPU model evaluation to measure the impact.

---
## Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| Event System | ✅ Solid | 44 events, 17 categories, 11 user-tier, 33 internal-tier. Tiers, bounded store, buffered JSONL. |
| Execution Model | ✅ Excellent | Ractor-based lazy futures, wave resolution |
| Tool System | ✅ Good | Schema validation, retry, timeout, "Did You Mean?" |
| Builder DSL | ✅ Excellent | Three-tier (Simple/Builder/Advanced) + MoA, 34 builder methods |
| Model Integration | ✅ Validated | Server capability detection tested with real LM Studio/llama.cpp |
| Evaluation Framework | ✅ Complete | YAML suites, matrix runner, result persistence |
| Production Readiness | ✅ P0 Complete | Checklist, health checks, cost tracking, thread safety docs |
| Resilience | ✅ Complete | Retry (exp backoff), circuit breaker, rate limiting, failover, health checks |
| Memory System | ✅ Complete | Working memory, reflection memory (LRU), budget strategies |
| Multi-Agent | ✅ Complete | Spawn, delegate, parallel, team builder, wave scheduling |
| Phase H Diagnostics | ✅ Complete | Debug mode, stats tracking, failure capture, config profiles, memory inspection |
| Phase I Prompt Formatting | ✅ Complete | YARD-style tool rendering, Ruby 4.0 identity, `it` keyword coaching, `.inspect` observations, block param hints |

**Test Suite:** 15,363 examples, 0 failures, ~7s parallel
**Architecture:** 59 concerns, 86 Data.define types, 44 events (50 ceiling)

---
## Completed Phases (Summary)

| Phase | What Was Done |
|-------|---------------|
| **A: Quick Wins** | Loop detection, Chain of Draft, "Did You Mean?", tool result type hints |
| **B: Foundation** | Budget/context signals, progressive tool disclosure, failure classification, event sourcing |
| **C: Testing** | Test mode API, call logging, scenarios, matchers, request logging |
| **D: Strategic** | Checkpointing, semantic circuit breaker, Mixture-of-Agents, Phase D events |
| **E-1: Production (P0)** | Production checklist, cost tracking, health checks, thread safety docs, server capability detection, API reference docs |
| **F.1: Capability Detection** | LM Studio 0.4.0 probing, llama.cpp conflict detection, model capability queries |
| **F.2: Local Model Testing** | Eval framework (YAML suites, matrix runner, CLI), initial model capability matrix |
| **F.3: Model Empathy** | System prompt simplification, upfront capability statements, error recovery specificity, tool description excellence, prompt efficiency & token budget |
| **F.4: Test Harness** | Tool execution tracking, circuit breaker isolation, model availability detection, diagnostic improvements, nemotron investigation, native tool calling mode |
| **G.1: Event Reduction** | 87→77→45 events. Removed dead events, consolidated lifecycle patterns with phase predicates |
| **G.2: Tool Consolidation** | 5 search tools extracted to plugins (-1740 lines from core) |
| **G.3: Testing Cleanup** | ~7,600 lines of dev-only code moved to experiments/testing/ |
| **G.4: Ruby 4.0 Types** | Factory builders, state predicates, pattern matching, validator centralization (-275 lines) |
| **G.5: Concern Consolidation** | 12 sub-files merged into parents, RuboCop exclusions for 4 consolidated files |
| **G.6: Event Solidification** | Tier 1: bug fixes (race condition, category misassignments, dead events). Tier 2: event tiers (:user/:internal), bounded EventStore (max_events circular buffer), CoordTaskLifecycle split, buffered JSONL backend (evented, non-blocking). 43→44 events. |
| **H: Local-GPU-Ready** | Debug mode (`.debug`), agent stats, verbose subscriber, failure capture, config profiles, memory inspection, GPU test fixtures, resource tracking |
| **I: Prompt Formatting** | YARD-style tool rendering (RUBY_TYPE_MAP, typed @return tags), Ruby 4.0 identity ("You are a Ruby 4.0 agent"), RUBY4_PATTERNS P2 section (`it` keyword, pattern matching, safe navigation), `.inspect` for Hash/Array observations, block param code hint (nudges `{ \|x\| x[...] }` → `{ it[...] }`), Ruby vocabulary throughout (keyword arguments, instance variables, AVAILABLE METHODS header) |

### Event System Design Principles (Locked In)

1. **Don't add events speculatively.** Every new event must have at least one consumer.
2. **Lifecycle pattern is default.** Add a phase to an existing lifecycle event first. Only create new event types when the data shape is fundamentally different.
3. **44 events, 50 ceiling.** New features should reuse existing events. If we exceed 50, audit and consolidate.
4. **No performance optimization needed.** LLM calls are 100-5000ms. Event overhead (<1ms/step) is noise.
5. **User events vs internal events.** 11 user-tier events for subscribers, 33 internal for infrastructure.
6. **Fully evented, non-blocking.** No sleep, no polling. Queue#pop for blocking waits, instant wakeup on push/close.

---
## Phase H: Local-GPU-Ready Enhancements ✅

**Goal:** Make the framework transparent and debuggable so users can confidently run agents on local GPU models.

**Why now:** The foundation is solid (events, resilience, memory, multi-agent all complete). But users running local models need: (1) visibility into what the agent is doing, (2) tools to diagnose failures from flaky local servers, (3) configuration tuned for local constraints, and (4) test fixtures that simulate local GPU scenarios. Without these, users waste energy debugging opaque agents.

**What already works well (NOT in scope):**
- Resilience: Retry (exponential backoff), circuit breaker (Stoplight), rate limiting (3 strategies), failover, health checks — all COMPLETE
- Memory: Working memory + reflection memory (LRU eviction) + budget strategies — COMPLETE
- Multi-agent: Spawn, delegate, parallel, team builder, wave scheduling — COMPLETE
- Testing: MockModel, CallLog, shared examples, validators, matchers — COMPLETE
- Tool discovery: Tools.names, tool.help, CLI command, IRB completion — COMPLETE
- Event observability: 44 events, Emitter/Consumer, category/tier subscriptions — COMPLETE

**Effort:** 2-3 weeks across 4 sub-phases
**Priority:** P1 — prerequisite for productive local GPU usage

---

### Architecture Rules for Phase H

All new code follows existing patterns:

| Pattern | Rule |
|---------|------|
| Types | `Data.define` in `lib/smolagents/types/`, factory `.default` method, frozen |
| Concerns | ≤100 lines, registered in `concerns/registrations/`, category/provides/dependencies |
| Events | Reuse existing events (44/50 ceiling). No new events unless data shape is fundamentally different |
| Builder methods | Immutable via `derive()`. `check_frozen!` guard. YARD docs |
| Testing | Instant-fast (<120ms). No sleep/polling. Queue#pop for blocking. WebMock blocks network |
| Non-blocking | No `sleep`, no `Timeout.timeout`. Evented wakeup patterns only |

---

### H.1: Debug Mode & Agent Introspection ✅

**Goal:** Users can see what their agent is doing and inspect its state at any point.

**What exists:** `AgentLogger` (DEBUG/INFO/WARN/ERROR), `.logging(level:)` builder method, event system with 11 user-tier events, `agent.inspect` (basic).

**What's missing:** No built-in verbose subscriber that prints human-readable step output. No `.debug` builder shortcut. No agent stats (tokens, steps, duration). No memory budget visibility.

#### H.1.1: VerboseSubscriber Concern ✅

New concern that subscribes to user-tier events and prints human-readable output.

**Files:**
- `lib/smolagents/concerns/agents/verbose_subscriber.rb` (≤100 lines)
- `spec/smolagents/concerns/agents/verbose_subscriber_spec.rb`

**Design:**
```ruby
# Subscribes via on_user_events (from G.6 tier system)
# Prints formatted output for each event type:
#   [Step 1] Calling search(query: "Ruby 4.0")
#   [Step 1] Tool returned: "Ruby 4.0 was released..."  (truncated to 200 chars)
#   [Step 2] Model generated 145 tokens (250ms)
#   [Step 2] Final answer: "Ruby 4.0 includes..."
#   [Error] ToolError: search timed out (retrying...)
```

**Concern registration:** Category `:diagnostics`, provides `[:verbose_output]`, no dependencies.

**Events consumed:** Uses `on_user_events` (subscribes to all 11 user-tier events). Formats each event type differently. Output goes to `@logger` (same logger the agent uses).

#### H.1.2: `.debug` Builder Method ✅

Add `.debug(level = :verbose)` to AgentBuilder that wires VerboseSubscriber + sets log level.

**Files:**
- `lib/smolagents/builders/agent_builder.rb` (add method, ~5 lines)
- `spec/smolagents/builders/agent_builder_spec.rb` (add test)

**Design:**
```ruby
# .debug is sugar for: .logging(level: :debug).include_concern(:verbose_subscriber)
# .debug(:verbose) sets verbose level (default)
# .debug(:quiet) disables (for toggling off)
```

**Builder method pattern:** `derive(debug_level: level)` — immutable.

#### H.1.3: AgentStats Type + StatsTracking Concern ✅

Track runtime statistics via events. Expose via `.stats` on agent.

**Files:**
- `lib/smolagents/types/agent_stats.rb` — Data.define
- `lib/smolagents/concerns/agents/stats_tracking.rb` (≤100 lines)
- `spec/smolagents/types/agent_stats_spec.rb`
- `spec/smolagents/concerns/agents/stats_tracking_spec.rb`

**Type design:**
```ruby
AgentStats = Data.define(
  :steps_taken, :total_tokens, :tool_calls, :tool_errors,
  :model_calls, :duration_ms, :errors
) do
  def self.zero = new(steps_taken: 0, total_tokens: 0, tool_calls: 0,
                      tool_errors: 0, model_calls: 0, duration_ms: 0, errors: 0)
end
```

**Concern design:** Subscribes to `:step_completed`, `:tool_call_completed`, `:model_generation`, `:error_occurred`. Accumulates counts in instance variables. Exposes `#stats` returning AgentStats snapshot. Thread-safe via Mutex (stats are read/written from different threads in async mode).

#### H.1.4: Memory Inspection ✅

Add budget visibility to existing memory concerns.

**Files:**
- `lib/smolagents/concerns/agents/working_memory.rb` (add 2-3 methods)
- `lib/smolagents/concerns/agents/reflection_memory.rb` (add 1-2 methods)
- Specs for both

**Methods to add:**
```ruby
# On working memory:
def memory_budget_usage  # => { used: 1200, total: 5000, percent: 24.0 }
def memory_summary       # => "Working memory: 1.2K/5K tokens (24%), 3 reflections stored"

# On reflection memory:
def reflection_count     # => 3
def reflections_summary  # => "3 reflections (2 failures, 1 success)"
```

Small additions (≤10 lines each) to existing concerns. No new files needed.

#### H.1.5: Builder Pre-Build Validation ✅

Warn about common misconfigurations before `.build`.

**Files:**
- `lib/smolagents/builders/agent_builder.rb` (add validation in `build`, ~10 lines)
- Spec additions

**Warnings (via logger, not exceptions):**
- No model configured → raise (already exists)
- No tools configured → warn "Agent has no tools — it can only generate text"
- Very low max_steps (< 3) → warn "max_steps=N is very low"
- Debug mode without tools → warn "Debug mode is most useful with tools"

---

### H.2: Failure Diagnostics & Testing ✅

**Goal:** Users can diagnose why their local model failed and test against realistic local GPU constraints.

**What exists:** Auditable concern (request_id, duration, status), ErrorOccurred event, structured ToolError with hints, StepMonitor for timing.

**What's missing:** Full request/response capture on API failures. Standard test fixtures for local GPU scenarios. Agent-level resource tracking.

#### H.2.1: API Failure Capture Concern ✅

Capture full request/response context when model API calls fail.

**Files:**
- `lib/smolagents/types/failure_snapshot.rb` — Data.define
- `lib/smolagents/concerns/resilience/failure_capture.rb` (≤100 lines)
- `spec/smolagents/types/failure_snapshot_spec.rb`
- `spec/smolagents/concerns/resilience/failure_capture_spec.rb`

**Type design:**
```ruby
FailureSnapshot = Data.define(
  :timestamp, :model_id, :error_class, :error_message,
  :request_summary, :response_summary, :step_number
) do
  def self.from_error(error, context:)
    # Factory method that extracts relevant context
  end
end
```

**Concern design:** Subscribes to `:error_occurred` events. Stores last N failures (configurable, default 5) in circular buffer. Exposes `#last_failures` (array of FailureSnapshot) and `#last_failure` (most recent). Captures: model_id, error class/message, truncated request body (first 500 chars), response status + body (first 500 chars), step number.

**Concern registration:** Category `:diagnostics`, provides `[:failure_capture]`.

#### H.2.2: Local GPU Test Fixtures ✅

Standard MockModel configurations for common local GPU scenarios.

**Files:**
- `lib/smolagents/testing/fixtures.rb` (≤100 lines)
- `spec/smolagents/testing/fixtures_spec.rb`

**Design:**
```ruby
module Smolagents::Testing::Fixtures
  # Pre-configured MockModel for testing against local GPU constraints
  def self.slow_model(latency_ms: 2000, responses: [])
    # MockModel with configurable artificial latency
  end

  def self.limited_context_model(max_tokens: 2048, responses: [])
    # MockModel that truncates prompts exceeding max_tokens
  end

  def self.unreliable_model(failure_rate: 0.3, responses: [])
    # MockModel that fails intermittently (uses fail_then_succeed pattern)
  end

  def self.no_tool_calling_model(responses: [])
    # MockModel that forces code-based approach (no native tool calling)
  end

  def self.local_gpu_model(responses: [])
    # Combines: slow (500ms), limited context (4096), occasional failures
  end
end
```

**Note:** These are factory methods returning configured MockModel instances. They reuse MockModel's existing `fail_then_succeed`, queue, and response patterns. No new model classes needed.

#### H.2.3: Agent Resource Tracking ✅

Track total resource usage across an agent run.

**Files:**
- `lib/smolagents/types/resource_usage.rb` — Data.define
- `spec/smolagents/types/resource_usage_spec.rb`

**Type design:**
```ruby
ResourceUsage = Data.define(
  :total_tokens, :prompt_tokens, :completion_tokens,
  :total_duration_ms, :model_duration_ms, :tool_duration_ms,
  :api_calls, :tool_calls
) do
  def self.zero = new(total_tokens: 0, prompt_tokens: 0, completion_tokens: 0,
                      total_duration_ms: 0, model_duration_ms: 0, tool_duration_ms: 0,
                      api_calls: 0, tool_calls: 0)
end
```

**Integration:** StatsTracking concern (H.1.3) returns this as part of `#stats`. Could merge with AgentStats or keep separate — decision at implementation time based on concern line count.

---

### H.3: Configuration Profiles ✅

**Goal:** Users can switch between local GPU and cloud API settings without changing code.

**What exists:** Global `Smolagents.configuration` with 30+ settings (timeouts, max_steps, isolation, memory, health thresholds). ModelPalette for named model factories. Validation on configuration changes.

**What's missing:** No way to define named profiles (`:local_gpu`, `:development`, `:production`) that inherit from defaults.

#### H.3.1: Config Profiles ✅

Named configuration profiles with inheritance from defaults.

**Files:**
- `lib/smolagents/types/config_profile.rb` — Data.define
- `lib/smolagents/config/profiles.rb` (≤100 lines)
- `lib/smolagents/config/configuration.rb` (add `#apply_profile` method)
- `spec/smolagents/config/profiles_spec.rb`
- `spec/smolagents/types/config_profile_spec.rb`

**Type design:**
```ruby
ConfigProfile = Data.define(:name, :description, :overrides) do
  def self.default = new(name: :default, description: "Default settings", overrides: {})
end
```

**Built-in profiles:**
```ruby
# :local_gpu — tuned for local model constraints
{ http: { timeout_seconds: 60 },       # Local models are slower
  max_steps: 10,                         # Conserve context window
  health: { latency_healthy_ms: 3000 } } # Higher latency tolerance

# :development — verbose output for debugging
{ log_level: :debug }

# :cloud_api — optimized for cloud providers
{ http: { timeout_seconds: 30 },
  max_steps: 20 }
```

**API:**
```ruby
Smolagents.configure(:local_gpu)                    # Apply built-in profile
Smolagents.configure(:local_gpu) { |c| c.max_steps = 5 }  # Profile + overrides
Smolagents.register_profile(:custom, overrides: { ... })   # Custom profile
```

#### H.3.2: Configuration Documentation ✅

YARD docs on all configuration options with valid ranges and defaults.

**Files:**
- `lib/smolagents/config/configuration.rb` (YARD docs only)
- `lib/smolagents/config/defaults.rb` (YARD docs only)

No code changes — documentation only. Include in Wave 3 as polish.

---

### H.4: Persistent Memory (DEFERRED)

**Status:** Working memory + reflection memory are fully implemented with LRU eviction and budget strategies. Persistent storage across sessions (file/SQLite/Redis backends) is a larger architectural decision that doesn't block local GPU usage. Defer to post-H.

---

### Wave Execution Plan

Tasks are organized into waves for parallel agent execution. Each wave's tasks are independent — agents won't collide.

#### Wave 1: Types & Standalone Concerns (5 parallel agents)

All tasks create new files only — no overlapping edits.

| Agent | Task | Files Created | Dependencies |
|-------|------|--------------|-------------|
| A | H.1.3: AgentStats type | `types/agent_stats.rb`, spec | None |
| B | H.2.1: FailureSnapshot type | `types/failure_snapshot.rb`, spec | None |
| C | H.2.3: ResourceUsage type | `types/resource_usage.rb`, spec | None |
| D | H.3.1: ConfigProfile type | `types/config_profile.rb`, spec | None |
| E | H.2.2: Test fixtures | `testing/fixtures.rb`, spec | None |

**Estimated:** 30-60 minutes. Pure type/factory creation, shared examples.

#### Wave 2: Concerns (4 parallel agents)

Each agent creates a new concern + spec. No overlapping files.

| Agent | Task | Files Created | Depends On |
|-------|------|--------------|-----------|
| A | H.1.1: VerboseSubscriber concern | `concerns/agents/verbose_subscriber.rb`, spec | None (uses existing `on_user_events`) |
| B | H.1.3: StatsTracking concern | `concerns/agents/stats_tracking.rb`, spec | Wave 1 Agent A (AgentStats type) |
| C | H.2.1: FailureCapture concern | `concerns/resilience/failure_capture.rb`, spec | Wave 1 Agent B (FailureSnapshot type) |
| D | H.3.1: Config profiles module | `config/profiles.rb`, spec | Wave 1 Agent D (ConfigProfile type) |

**Estimated:** 1-2 hours. Each concern is ≤100 lines with focused spec.

#### Wave 3: Concern Registration & Builder Integration (3 parallel agents)

Agents touch different files — no collisions.

| Agent | Task | Files Modified | Depends On |
|-------|------|---------------|-----------|
| A | Register new concerns | `concerns/registrations/agents.rb` (VerboseSubscriber, StatsTracking), `concerns/registrations/resilience.rb` (FailureCapture) | Wave 2 |
| B | H.1.2: `.debug` builder method + H.1.5: pre-build validation | `builders/agent_builder.rb`, spec | Wave 2 Agent A (VerboseSubscriber) |
| C | H.3.1: Configuration `#apply_profile` integration | `config/configuration.rb`, spec | Wave 2 Agent D (profiles module) |

**Estimated:** 1-2 hours. Small modifications to existing files.

#### Wave 4: Memory Inspection & Polish (2 parallel agents)

| Agent | Task | Files Modified | Depends On |
|-------|------|---------------|-----------|
| A | H.1.4: Memory inspection methods | `concerns/agents/working_memory.rb`, `concerns/agents/reflection_memory.rb`, specs | None (adds to existing) |
| B | H.3.2: Config docs + event docs audit | YARD docs only | Wave 3 |

**Estimated:** 30-60 minutes. Small additions, documentation.

#### Wave 5: Integration Verification (1 agent)

| Agent | Task | Depends On |
|-------|------|-----------|
| A | Full CI (`rake ci`), verify all 15K+ tests pass, 0 rubocop offenses, update PLAN.md status | All waves |

---

### Dependency Graph

```
Wave 1 (types)          Wave 2 (concerns)       Wave 3 (wiring)        Wave 4 (polish)
─────────────           ─────────────────       ───────────────        ───────────────
AgentStats ──────────→ StatsTracking ─────┐
FailureSnapshot ─────→ FailureCapture ────┤
                                          ├──→ Register concerns
                       VerboseSubscriber ─┤
                                          ├──→ .debug builder ─────→ Memory inspection
ConfigProfile ───────→ Config profiles ───┤
                                          └──→ Configuration ──────→ Config docs
ResourceUsage (standalone)
Test fixtures (standalone)
```

### File Collision Analysis

No two agents in the same wave touch the same file:

| File | Modified In |
|------|------------|
| `types/agent_stats.rb` | Wave 1 only (create) |
| `types/failure_snapshot.rb` | Wave 1 only (create) |
| `types/resource_usage.rb` | Wave 1 only (create) |
| `types/config_profile.rb` | Wave 1 only (create) |
| `testing/fixtures.rb` | Wave 1 only (create) |
| `concerns/agents/verbose_subscriber.rb` | Wave 2 only (create) |
| `concerns/agents/stats_tracking.rb` | Wave 2 only (create) |
| `concerns/resilience/failure_capture.rb` | Wave 2 only (create) |
| `config/profiles.rb` | Wave 2 only (create) |
| `concerns/registrations/agents.rb` | Wave 3 Agent A only |
| `concerns/registrations/resilience.rb` | Wave 3 Agent A only |
| `builders/agent_builder.rb` | Wave 3 Agent B only |
| `config/configuration.rb` | Wave 3 Agent C only |
| `concerns/agents/working_memory.rb` | Wave 4 Agent A only |
| `concerns/agents/reflection_memory.rb` | Wave 4 Agent A only |

### Event Budget

Phase H adds **0 new events**. All new concerns consume existing events:
- VerboseSubscriber: consumes 11 user-tier events via `on_user_events`
- StatsTracking: consumes `:step_completed`, `:tool_call_completed`, `:model_generation`, `:error_occurred`
- FailureCapture: consumes `:error_occurred`

Current: 44 events. After Phase H: 44 events. Well within 50 ceiling.

---
## Phase E-2: Privacy & Polish (DEFERRED)

**Priority:** P2 (after H) | **Effort:** 3-4 weeks

- PII detection (email, phone, SSN, credit card) with `:tokenize`, `:mask`, `:remove` strategies
- Reversible tokenization, integration with agent memory and tool I/O
- YARD docs for all DSL builder methods
- Guides: multi-model, local model setup, event patterns

---
## What We're NOT Doing

1. **Background Job Adapters** — Deferred
2. **Metrics Adapter Layer** — Deferred until core model reliability proven
3. **Full Ractor-based Event Bus** — Current Thread::Queue approach works
4. **Automatic Model Fingerprinting** — Needs data collection infrastructure
5. **Grammar-Constrained Decoding** — Requires model-level integration
6. **Rails Integration** — Tracked separately
7. **RBS Type Annotations** — Large effort, YARD docs serve well, IDE support via IRB completion
8. **Persistent Memory Storage** — Deferred to post-H. Working + reflection memory sufficient for now
9. **Agent-to-Agent Communication** — Deferred. ManagedAgentTool delegation works for current needs

---
## Execution Order

```
G.6 Event System Solidification ✅ COMPLETE
 ↓
H Phase: Local-GPU-Ready Enhancements ✅ COMPLETE
 ↓
I Phase: Ruby-Native Prompt Formatting ✅ COMPLETE
 ↓
E-2 Privacy & Polish ← final layer
```

---
## Success Metrics

| Metric | Baseline (2026-02-07) | Target |
|--------|----------------------|--------|
| granite-4.0-h-small tool calling | 100% | Maintain |
| gemma-3n-e4b tool calling | 100% | Maintain |
| nemotron-3-nano tool calling | 75% | 90%+ |
| glm-4.7-flash-mlx tool calling | 25-50% | 80%+ |
| glm-4.7-flash (GGUF) tool calling | 0% | 50%+ (or via native tool calling) |
| Event count | 44 (100% utilized) | ≤50 ceiling (0 new in Phase H) |
| Test suite | 15,158 examples, 0 failures | Maintain green |
| RuboCop | 0 offenses | Maintain clean |
| Architecture | 56 concerns, 82 types | Grows by ~4 concerns, ~4 types |

---
## Quick Reference

```bash
rake spec          # Run tests (~6s parallel)
rake spec_fast     # Skip slow/integration
rake ci            # Full CI (rubocop + tests + yard:doctest)
rake commit_prep   # Fix + Stage + Verify
```

**Key Docs:**
- `docs/references/llama_cpp_api.md` — llama.cpp OpenAI-compatible API
- `docs/references/lm_studio_api.md` — LM Studio local server API
- `docs/RUBY4_REVIEW.md` — Ruby 4.0 codebase review findings

---
*Updated: 2026-02-07*
*Version: 5.1 (Ruby-Native Prompt Formatting)*
