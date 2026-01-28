# smolagents-ruby Implementation Plan

**Branch:** feature/tool-future-lazy-eval
**Updated:** 2026-01-27
**Version:** 3.0 (Production Readiness Focus)

---

## Executive Summary

This plan synthesizes findings from Sonnet's Flux Design, consolidated research (70+ ideas), gap analysis, and production readiness audits.

**Core Insight**: "Help the model by giving it less to think about, not more."

**Current Priority**: Get agents reliably working with local models (llama.cpp, LM Studio) before further feature work.

---

## Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| Event System | ⚠️ Over-engineered | 87 events, only 36 emitted. Target: 30-40 |
| Execution Model | ✅ Excellent | Ractor-based lazy futures, wave resolution |
| Tool System | ✅ Good | Schema validation, retry, timeout, "Did You Mean?" |
| Builder DSL | ✅ Excellent | Three-tier (Simple/Builder/Advanced) + MoA |
| Model Integration | ⚠️ Needs Work | Server capability detection untested with real servers |
| Small Model Support | ⚠️ Needs Validation | Progressive disclosure, CoD built but not validated |
| Production Readiness | ✅ P0 Complete | Checklist, health checks, cost tracking, thread safety docs |
| Gem Dependencies | ✅ Good | Already using stoplight, ruby-openai, ruby-anthropic |

**Test Suite:** 15,742 examples, 93%+ coverage, ~6s parallel

---

## Completed Work

### Phase A: Quick Wins ✅

| Feature | Location |
|---------|----------|
| Loop Detection | `concerns/agents/react_loop/repetition.rb` |
| Chain of Draft | `utilities/prompts/agent.rb` (CHAIN_OF_DRAFT_SUFFIX) |
| "Did You Mean?" | `concerns/tools/did_you_mean.rb` |
| Tool Result Type Hints | `types/input_schema.rb` |

### Phase B: Foundation ✅

| Feature | Location |
|---------|----------|
| Budget/Context Signals | `concerns/execution/budget_tracking.rb` |
| Progressive Tool Disclosure | `utilities/prompts/agent/tool_formatting.rb` |
| Failure Classification | `concerns/resilience/failure_classification.rb` |
| Event Sourcing Foundation | `events/store.rb`, `events/store/*.rb` |

### Phase C: Testing & Observability ✅

| Feature | Location |
|---------|----------|
| Test Mode API | `testing/test_mode.rb` |
| Call Logging | `testing/call_log.rb`, `testing/call_log_support.rb` |
| Test Scenarios | `testing/scenarios.rb` |
| CallLog Matchers | `testing/matchers/call_log_matchers.rb` |
| Request Logging | `models/model/request_logging.rb` |

### Phase D: Strategic Features ✅

| Feature | Location |
|---------|----------|
| Checkpointing | `concerns/agents/checkpoints.rb`, `types/checkpoint.rb` |
| Semantic Circuit Breaker | `concerns/agents/semantic_breaker.rb` |
| Mixture-of-Agents | `concerns/mixture_of_agents/*.rb`, `builders/moa_coordinator.rb` |
| Phase D Events | `events/phase_d.rb` (9 new events) |

### Phase E-1: Production Readiness (P0) ✅

| Feature | Location |
|---------|----------|
| Production Checklist | `PRODUCTION_CHECKLIST.md` |
| Cost Tracking | `telemetry/cost_tracker.rb` |
| Health Checks | `telemetry/health_check.rb` |
| Shared Examples | `testing/shared_examples.rb` |
| Thread Safety Docs | `README.md` (Thread Safety section) |
| Server Capability Detection | `types/server_capability.rb`, `concerns/resilience/capability_detection.rb` |
| API Reference Docs | `docs/references/llama_cpp_api.md`, `docs/references/lm_studio_api.md` |

---

## Phase F: Local Model Reliability (CURRENT PRIORITY)

**Goal:** Agents reliably doing real work with local inference servers.

**Why:** We've built features but haven't validated they work with real local models. Privacy-focused local models (llama.cpp, LM Studio/MLX) are critical for the target use case.

### F.1 Server Capability Detection Review
**Priority:** P0
**Effort:** 1-2 days

Review and fix capability detection based on actual API documentation:

| Task | Status |
|------|--------|
| Review `docs/references/llama_cpp_api.md` | Pending |
| Review `docs/references/lm_studio_api.md` | Pending |
| Audit `types/server_capability.rb` against real API behavior | Pending |
| Fix any incorrect assumptions about tools/response_format support | Pending |
| Add integration tests with real server responses | Pending |

**Key findings from research:**
- llama.cpp: Cannot use `tools` AND `response_format` simultaneously (conflict)
- llama.cpp: Requires `--jinja` flag for tools, which breaks structured output
- LM Studio: Has programmatic capability detection via `/v1/models` response
- LM Studio: Native tool support only for specific models (Qwen 2.5, Llama 3.x, etc.)

### F.2 End-to-End Local Model Testing
**Priority:** P0
**Effort:** 3-5 days

Create integration tests that validate agents can solve real problems:

| Task | Description |
|------|-------------|
| Simple reasoning test | Agent answers questions without tools |
| Tool use test | Agent uses a tool and incorporates results |
| Multi-step test | Agent completes a task requiring 3+ steps |
| Error recovery test | Agent handles tool failures gracefully |
| Context management test | Agent works within token limits |

**Target models:**
- llama.cpp: GLM, Qwen, Nemotron (GGUF)
- LM Studio: MLX models on Apple Silicon

### F.3 Model Empathy Improvements
**Priority:** P1
**Effort:** 1 week

Make prompts and interactions more helpful for smaller models:

| Task | Description |
|------|-------------|
| Simplify system prompts | Reduce cognitive load for 1-4B models |
| Improve tool descriptions | Clearer, more concise tool schemas |
| Better error messages | Help model recover from mistakes |
| Response format guidance | Clear examples of expected output |
| Graceful degradation | Fallback strategies when model struggles |

---

## Phase G: Simplification

**Goal:** Reduce complexity while preserving essential functionality.

**Why:** 87 events when 36 are used. 8 search tools when 2 suffice. Testing utilities that belong in dev, not production.

### G.1 Event System Reduction
**Priority:** P1
**Effort:** 3-5 days

Reduce from 87 to ~35 focused events:

| Action | Impact |
|--------|--------|
| Delete `events/registry/built_in.rb` | -603 lines (unused metadata) |
| Consolidate task coordination: 13 → 4 events | Clearer API |
| Remove unimplemented feature events | -20+ unused events |
| Document essential 20 events prominently | Better DX |

**Essential events to preserve:**
- Core lifecycle: task_started, task_complete, step_complete, error
- Tools: tool_call, tool_complete
- Models: model_generate_requested, model_generate_completed
- Planning: plan_generated, plan_updated
- Resilience: retry, failover

### G.2 Tool Consolidation
**Priority:** P2
**Effort:** 1-2 days

| Action | Impact |
|--------|--------|
| Keep: DuckDuckGo (free), Google (premium) | Core search |
| Extract: ArXiv, Wikipedia, Bing, Brave, SearXNG | Move to examples or plugin |
| Impact | -400 lines from core |

### G.3 Testing Utilities Cleanup
**Priority:** P2
**Effort:** 1-2 days

| Action | Impact |
|--------|--------|
| Keep in core: MockModel, basic matchers, helpers | Essential for users |
| Move to dev-only: Benchmarking, auto-gen, scenarios, tracers | Not needed in production gem |
| Impact | -800 lines from shipped gem |

### G.4 Concern Consolidation
**Priority:** P3
**Effort:** 2-3 days

| Action | Impact |
|--------|--------|
| Relax 100-line rule to 150 for cohesive code | Less artificial splitting |
| Merge tiny files (e.g., task_coordination: 2 files → 1) | -15 files |
| Move MoA wave scheduling to MoA-specific concerns | Clearer boundaries |

---

## Phase E-2: Privacy & Polish (DEFERRED)

### Privacy-First Architecture
**Priority:** P2 (after F and G)
**Effort:** 2-3 weeks

- PII detection (email, phone, SSN, credit card)
- Strategies: `:tokenize`, `:mask`, `:remove`
- Reversible tokenization
- Integration with agent memory and tool I/O

### Documentation
**Priority:** P2
**Effort:** 1-2 weeks

| Task | Description |
|------|-------------|
| YARD docs | All DSL builder methods |
| Multi-model guide | Building agents with multiple models |
| Local model guide | llama.cpp and LM Studio setup |
| Event patterns guide | Subscription, emission, error handling |

---

## What We're NOT Doing

1. **Background Job Adapters** - Deferred (files placeholder if needed)
2. **Metrics Adapter Layer** - Deferred until core model reliability proven
3. **Full Ractor-based Event Bus** - Current Fiber-based approach works
4. **Automatic Model Fingerprinting** - Needs data collection infrastructure
5. **Grammar-Constrained Decoding** - Requires model-level integration
6. **Rails Integration** - Tracked separately

---

## Gem Dependency Analysis (2026-01-27)

**Verdict:** Current approach is good. Custom code provides value gems don't.

| Area | Status | Notes |
|------|--------|-------|
| API Clients | ✅ Using ruby-openai, ruby-anthropic | Keep |
| Circuit Breaker | ✅ Using stoplight | Keep |
| HTTP | ✅ Custom SSRF protection | Keep (security value) |
| Retry/Rate Limit | Custom event-driven | Keep (gems are blocking) |
| Events | Custom but integrated | Keep (wisper would lose features) |
| Types | Data.define (native) | Keep (no gem needed) |

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Local model (7B) success rate | Unknown | 80%+ |
| Average tokens per task | Baseline | -50% (with CoD) |
| Loop/stuck rate | Unknown | <5% |
| Event count | 87 | 35-40 |
| Core gem size | ~16k lines | ~12k lines (-25%) |
| Test coverage | 93%+ | 95%+ |

---

## Implementation Roadmap

| Phase | Status | Priority | Items |
|-------|--------|----------|-------|
| A: Quick Wins | ✅ Complete | - | Loop detection, CoD, "Did You Mean?" |
| B: Foundation | ✅ Complete | - | Budget signals, progressive disclosure |
| C: Testing | ✅ Complete | - | Test mode API, call logging |
| D: Strategic | ✅ Complete | - | Checkpointing, semantic breaker, MoA |
| E-1: Production (P0) | ✅ Complete | - | Checklist, health checks, cost tracking |
| **F: Local Model Reliability** | **Active** | **P0** | **Capability detection, e2e tests, model empathy** |
| G: Simplification | Pending | P1 | Event reduction, tool consolidation |
| E-2: Privacy & Polish | Deferred | P2 | PII protection, documentation |

---

## Quick Reference

```bash
rake spec          # Run tests (~6s parallel)
rake spec_fast     # Skip slow/integration
rake ci            # Full CI
rake commit_prep   # Fix + Stage + Verify
```

**API Reference Docs (local):**
- `docs/references/llama_cpp_api.md` - llama.cpp OpenAI-compatible API
- `docs/references/lm_studio_api.md` - LM Studio local server API

---

*Updated: 2026-01-27*
*Version: 3.0 (Production Readiness Focus)*
