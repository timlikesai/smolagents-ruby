# smolagents-ruby Implementation Plan

**Branch:** feature/tool-future-lazy-eval
**Updated:** 2026-02-07
**Version:** 4.1 (Event System Solidification)

---
## Executive Summary

**Core Insight**: "Help the model by giving it less to think about, not more."

**Current Priority**: Solidify the event system, then move on to building features.

---
## Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| Event System | ✅ Solidifying | 43 events (from 77→45→43), Tier 1 complete. Tier 2 next. |
| Execution Model | ✅ Excellent | Ractor-based lazy futures, wave resolution |
| Tool System | ✅ Good | Schema validation, retry, timeout, "Did You Mean?" |
| Builder DSL | ✅ Excellent | Three-tier (Simple/Builder/Advanced) + MoA |
| Model Integration | ✅ Validated | Server capability detection tested with real LM Studio/llama.cpp |
| Evaluation Framework | ✅ Complete | YAML suites, matrix runner, result persistence |
| Production Readiness | ✅ P0 Complete | Checklist, health checks, cost tracking, thread safety docs |

**Test Suite:** 15,141 examples, 0 failures, ~6s parallel

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

---
## G.6 Event System Solidification (CURRENT PRIORITY)

**Goal:** Fix bugs, remove dead weight, and make intentional design decisions so the event system is locked down for the future.

**Why:** The event system is the foundation — every agent step, tool call, and model generation flows through it. It needs to be bulletproof before we build more features on top. After this, we don't touch events again unless adding new feature-specific events.

**Effort:** 2-3 days
**Status:** Tier 1 complete, Tier 2 next

### Event System Analysis (2026-02-07)

Deep analysis of all 45 events, 105 emit sites, and the full Emitter/Consumer/AsyncQueue architecture confirmed:

**What's working well:**
- Emit path is genuinely non-blocking (<20μs per event, lock-free)
- `should_emit?` guard prevents allocation when unobserved (zero overhead)
- Lifecycle pattern with phase predicates is clean and dominant (27/45 events)
- Handler failures isolated from main path (safe_call catches, records, continues)
- Per-step overhead is <0.01% of step time (~30μs vs 500-2000ms for LLM calls)
- ~42 events per typical agent run (25KB memory) — very lightweight

**The 80/20 split:** Only ~10 events account for most subscriptions (step, task, tool, error, model). The other ~35 are infrastructure events for specific subsystems. This is fine — but the system doesn't distinguish between user-facing and internal events.

### Tier 1: Fix Bugs & Remove Dead Weight ✅

| # | Task | Status |
|---|------|--------|
| 1 | **Removed `RateLimitHit`** — consolidated into `RateLimitViolated` (added `original_request` field) | ✅ Done |
| 2 | **Removed `ConfigurationChanged`** — 0 fields, 0 subscribers, deleted | ✅ Done |
| 3 | **Fixed `notify_subscribers` race** — `.dup` + mutex on subscribe/unsubscribe_all | ✅ Done |
| 4 | **Category subscriptions from Registry** — Consumer `on_*` methods now use `Registry.by_category()`. Fixed 3 category misassignments: ToolIsolation→:tools, ModelReliability→:models, RequestReliability→:errors | ✅ Done |

### Tier 2: Intentional Design Improvements

| # | Task | Why | Files |
|---|------|-----|-------|
| 5 | **Introduce event tiers: `:user` vs `:internal`** | Document and filter. User events: step, task, error, model, tool. Internal events: orchestration, coordination, work items. Helps users know what to subscribe to. | `events/dsl.rb`, `events/registry.rb`, all `define_event` sites |
| 6 | **Bound the EventStore** | In-memory backend grows forever. Add `max_events:` option with circular buffer. Default 1000. | `events/store.rb`, memory backend |
| 7 | **Split `CoordTaskLifecycle` (15 fields)** | Heaviest event by far. Task-created shouldn't carry `duration`, `output`, `error`. Split into definition-time and runtime-progress events. | `events/task_coordination.rb`, coordination concerns, specs |
| 8 | **Document file-based EventStore as debug-only** | Sync I/O with flush per event = 20-50ms per write. +10-25% overhead per step. Never for production. | `events/store.rb` YARD docs |

### Tier 3: Future Considerations (Not Now)

| # | Task | When |
|---|------|------|
| 9 | AsyncQueue backpressure (max_size + drop-oldest) | If high-frequency events or slow handlers ever become an issue |
| 10 | Dead event audit | Periodic — ~10 events have low/no test subscriptions |
| 11 | Unify symbol/class emit patterns | If the dual pattern causes confusion |

### Design Principles (Lock In)

After solidification, these rules govern future event work:

1. **Don't add events speculatively.** Every new event must have at least one consumer in mind.
2. **Lifecycle pattern is default.** New feature? Add a phase to an existing lifecycle event first. Only create new event types when the data shape is fundamentally different.
3. **43 events is the target ceiling.** New features should reuse existing events where possible. If we exceed 50, audit and consolidate.
4. **No performance optimization needed.** The bottleneck is always LLM calls (100-5000ms). Event overhead (<1ms/step) is noise. Don't add complexity for performance.
5. **User events vs internal events.** Users subscribe to ~10 events. The rest are infrastructure. Keep this distinction clear.

---
## Phase H: Enhancements (AFTER G.6)

**Goal:** Improve framework usability and robustness on the solid foundation.

### H.1 Developer Experience & Tool Discovery
**Priority:** P2 | **Effort:** 3-4 weeks

| Area | Tasks |
|------|-------|
| Tool Discovery | Tool browsing/search by name, description, or capability; auto-generated API references |
| IDE & Tooling | Auto-completion support, debugging utilities, REPL integration |
| Documentation | Comprehensive guides, inline help, examples for all builder methods |

### H.2 Testing, Diagnostics & Monitoring
**Priority:** P2 | **Effort:** 3-4 weeks

| Area | Tasks |
|------|-------|
| Testing | Tool-specific mocking, agent state testing, integration test framework, standard fixtures |
| Diagnostics | Verbose step-by-step mode, API request/response logging on failure |
| Monitoring | Metrics collection, profiling support, resource usage tracking, benchmarks |

### H.3 Infrastructure & Configuration
**Priority:** P3 | **Effort:** 2-3 weeks

| Area | Tasks |
|------|-------|
| Resilience | Retry strategies with exponential backoff, timeout handling, infrastructure-level error recovery |
| Configuration | Config inheritance, environment-based loading, validation and documentation |

### H.4 Advanced Features
**Priority:** P3 | **Effort:** 6-8 weeks

| Area | Tasks |
|------|-------|
| Memory | Long-term persistent storage, LRU eviction policies, memory profiling, flexible strategies |
| Multi-Agent | Communication protocols, state synchronization, enhanced delegation, task prioritization |

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

---
## Execution Order

```
G.6 Event System Solidification (2-3 days) ← NEXT
 ↓
H.1–H.4 Enhancements (as needed)          ← build features on solid foundation
 ↓
E-2 Privacy & Polish                       ← final layer
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
| Event count | 43 (100% utilized) | ≤50 ceiling |
| Test suite | 15,141 examples, 0 failures | Maintain green |
| RuboCop | 0 offenses | Maintain clean |

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
*Version: 4.1 (Event System Solidification)*
