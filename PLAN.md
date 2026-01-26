# EDAA Implementation Plan

**Branch:** feature/tool-future-lazy-eval
**Updated:** 2026-01-25

---

## Status Summary

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Foundation (events, work queue) | ✅ Complete |
| 2 | Multi-Model Support | ✅ Complete |
| 3 | Parallel Sub-Agents | ✅ Complete |
| 4 | Event-Driven Orchestration | ✅ Complete |
| 5 | Code Quality & Hardening | ✅ Complete |
| 5.1 | Pre-Release Fixes | ✅ Complete |
| 6 | Documentation | Not Started |
| 7 | Multi-Model Infrastructure Gaps | ✅ Complete (P1+P2) |

**Test Suite:** 14,500+ examples, 95.8% coverage, ~5s parallel

---

## Phase 7: Multi-Model Infrastructure Gaps

Identified through exploration of sophisticated multi-model agent architectures.
See `experiments/multi_model_agents/` for full details and 84 passing tests.

### Priority 1: Quick Wins (Low Effort, High Impact) ✅ COMPLETE

| Gap | Description | Effort | Status |
|-----|-------------|--------|--------|
| G1.1 | `base_url()` method on ModelBuilder | ~10 lines | ✅ Complete |
| G1.2 | MockModel failure injection | ~30 lines | ✅ Complete |
| G1.3 | Event sequence numbers | ~20 lines | ✅ Complete |

**G1.1: base_url() for Remote Servers** ✅

Added `base_url()` as alias for `endpoint()`:
```ruby
Smolagents.model(:openai)
  .base_url("http://mac-studio.local:1234/v1")
  .id("gpt-oss-20b")
  .build
```

**G1.2: MockModel Failure Injection** ✅

Added failure injection methods to MockModel:
```ruby
model = MockModel.new
model.fail_next(3, with: NetworkError)  # Next 3 calls fail
model.queue_final_answer("success")      # Then succeed

# Or inline
model.queue_failure(NetworkError, "Connection refused")

# Or fail-then-succeed pattern
model.fail_then_succeed(2, with: TimeoutError, then_respond: "Done")
```

**G1.3: Event Sequence Numbers** ✅

All events now include monotonically increasing sequence numbers:
```ruby
event1.sequence  # => 1
event2.sequence  # => 2
# Thread-safe, global counter via CreateFactory
```

### Priority 2: Core Improvements (Medium Effort) ✅ COMPLETE

| Gap | Description | Effort | Status |
|-----|-------------|--------|--------|
| G2.1 | Parallel execution in TeamBuilder | ~100 lines | ✅ Complete |
| G2.2 | Custom model purposes | ~30 lines | ✅ Complete |
| G2.3 | Health check model verification | ~40 lines | ✅ Complete |
| G2.4 | Tool access to model pool | ~50 lines | ✅ Complete |

**G2.1: Parallel Execution Control** ✅

TeamBuilder now supports explicit execution stages:
```ruby
Smolagents.team
  .agent(broad, as: "broad")
  .agent(deep, as: "deep")
  .agent(synth, as: "synthesizer")
  .parallel(:broad, :deep)       # Stage 1: Run in parallel
  .then(:synthesizer)            # Stage 2: Run sequentially
  .build
# Auto-generates coordination instructions from execution plan
```

**G2.2: Custom Model Purposes** ✅

Any symbol can now be used as a model purpose:
```ruby
Smolagents.agent
  .model(:triage) { fast_model }        # Custom purpose
  .model(:vision) { vision_model }      # Custom purpose
  .model(:reasoning) { big_model }      # Custom purpose
  .build
```

**G2.3: Health Check Model Verification** ✅

Health check can now verify model is loaded:
```ruby
.with_health_check(cache_for: 5, verify_model: true)
# Returns unhealthy if model_id not in /v1/models response
```

**G2.4: Tool Access to Model Pool** ✅

Tools can now request model injection from agent's pool:
```ruby
Smolagents.agent
  .model(:vision) { vision_model }
  .tool(:analyze_image, "Analyze image", inject_models: [:vision], url: String) do |url:, vision:|
    vision.generate([{ role: :user, content: "Analyze #{url}" }])
  end
  .build
```

### Priority 3: Advanced Features (Higher Effort)

| Gap | Description | Effort |
|-----|-------------|--------|
| G3.1 | Cost tracking and budget limits | ~150 lines |
| G3.2 | Checkpoint and resume | ~300 lines |
| G3.3 | Model cluster discovery | ~400 lines |

See `experiments/multi_model_agents/08_gap_analysis.md` for full details.

---

## Multi-Model Agent Experiments

Comprehensive exploration of distributed multi-model architectures.

### Experiments (84 tests)

| Experiment | Pattern | Tests |
|------------|---------|-------|
| 04_tiered_reasoning | Fast triage → Big reasoning | 14 |
| 05_research_swarm | Parallel research + synthesis | 18 |
| 06_visual_analysis_pipeline | Vision → Reasoning pipeline | 18 |
| 07_self_improving_agent | Meta-learning with reflection | 18 |
| 09_distributed_analyst | Combined full system | 16 |

### Architecture Patterns Validated

```
Tiered:    Query → [Fast] → Simple? → [Fast] / Complex? → [Big]
Swarm:     Query → [Coordinator] → [Broad, Deep, Academic] → [Synthesizer]
Pipeline:  Image → [Vision] → Description → [Reasoning] → Analysis
Learning:  Task → Execute → Evaluate → Reflect → Store → Apply
```

### What Works Well

- Multi-model DSL (`.model(:purpose) { }`) is expressive
- Resilience patterns compose naturally
- Event system provides excellent observability
- Testing infrastructure enables fast deterministic tests
- Team coordination with sub-agents as tools is clean

### Infrastructure Tested

| Machine | Role | Models |
|---------|------|--------|
| LLaMA Ultra | Fast triage | gpt-oss-20b (very fast) |
| MacBook Pro M4 | Workers + Reasoning | gpt-oss-20b (fast), gpt-oss-120b |
| Mac Studio | Fallback | gpt-oss-20b (medium) |

---

## What's Left

### Pre-Release Fixes (from Architecture Review)

| Issue | Severity | Location | Status |
|-------|----------|----------|--------|
| ThreadPool max_threads not enforced | High | `concerns/execution/thread_pool.rb` | ✅ Complete |
| Event handler errors suppressed | High | `events/consumer.rb` | ✅ Complete |
| Memory limit parameter ignored | Medium | `executors/ractor.rb` | ✅ Complete |

**Details:**

1. ~~**ThreadPool max_threads**~~ - RESOLVED: Implemented proper blocking using `ConditionVariable`. Pool now blocks when at capacity and signals when slots free up.

2. ~~**Event handler errors suppressed**~~ - RESOLVED: Added `HandlerFailure` type, `@failed_handlers` tracking, `handlers_failed?` method, and automatic `ErrorOccurred` event emission.

3. ~~**Memory limit parameter**~~ - RESOLVED: Removed misleading `memory_mb` parameter from executor interface. Added documentation noting that Ruby Ractors cannot enforce memory limits and external controls (cgroups, ulimit, containers) should be used for production deployments.

### Phase 6: Documentation

1. **YARD docs** for all DSL builder methods
2. **Guides** for multi-model, parallel agents, events
3. **Benchmarks** and performance profiling
4. **Two-layer future system** explanation (AgentFuture vs RactorLazy::ToolFuture)
5. **Event handler patterns** and error handling guidance

---

## Quick Reference

```bash
rake spec          # Run tests in parallel (~5s)
rake spec_fast     # Skip slow/integration tests
rake ci            # Full CI (lint + tests + doctest)
rake commit_prep   # Fix + Stage + Verify
```

### Custom RuboCop Cops (10 enabled)

| Cop | Purpose |
|-----|---------|
| NoSleep | Prevent blocking sleep calls |
| NoTimeoutBlock | Prevent Timeout.timeout |
| NoTimedWait | Prevent timed waits |
| NoBusyWait | Prevent busy-wait loops |
| NoTimingAssertion | Prevent timing-based tests |
| PreferDataDefine | Use Data.define for types |
| RequireDisableComment | Document cop disables |
| PreferEndlessMethod | Endless method syntax |
| TypeLocationRule | Types must be in types/ |
| NoReexportShim | No backwards-compat shims |
