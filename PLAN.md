# smolagents-ruby Implementation Plan

**Branch:** feature/tool-future-lazy-eval
**Updated:** 2026-01-31
**Version:** 3.1 (Production Readiness Focus)

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
| Model Integration | ✅ Validated | Server capability detection tested with real LM Studio/llama.cpp |
| Small Model Support | ⚠️ Partial | Some models work well (granite, gemma), others fail (nemotron) |
| Evaluation Framework | ✅ Complete | YAML suites, matrix runner, result persistence |
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
| Server Capability Detection | `types/server_capability.rb`, `concerns/resilience/capability_detection.rb`, `concerns/resilience/lm_studio_probe.rb` |
| API Reference Docs | `docs/references/llama_cpp_api.md`, `docs/references/lm_studio_api.md` |

---
## Phase F: Local Model Reliability (CURRENT PRIORITY)

**Goal:** Agents reliably doing real work with local inference servers.

**Why:** We've built features but haven't validated they work with real local models. Privacy-focused local models (llama.cpp, LM Studio/MLX) are critical for the target use case.

### F.1 Server Capability Detection Review
**Priority:** P0
**Effort:** 1-2 days
**Status:** ✅ Core fixes complete

Review and fix capability detection based on actual API documentation:

| Task | Status |
|------|--------|
| Review `docs/references/llama_cpp_api.md` | ✅ Complete |
| Review `docs/references/lm_studio_api.md` | ✅ Complete |
| Audit `types/server_capability.rb` against real API behavior | ✅ Complete |
| Fix any incorrect assumptions about tools/response_format support | ✅ Complete |
| Add integration tests with real server responses | ✅ `experiments/live/lm_studio_probe_test.rb` |

**Fixes implemented (2026-01-27):**
- Added `tools_response_format_conflict` flag to ServerCapability/ServerType
- llama.cpp: Marked with `tools_response_format_conflict: true` (CRITICAL conflict)
- LM Studio: Changed `tools` from `true` to `:model_dependent` (native for some models only)
- LM Studio: Added `supports_capability_query: true` (can probe `/v1/models`)
- RequestBuilder: Now drops `response_format` when both tools AND response_format requested for llama.cpp
- All 100 capability-related tests pass

**LM Studio 0.4.0 Probing (2026-01-28):**
- New `LmStudioProbe` module probes `/api/v1/models` endpoint for rich capability data
- `ModelCapabilities` Data.define: `trained_for_tool_use`, `vision`, `max_context_length`, `format`, `architecture`, `quantization`
- `ServerProbeResult` with flexible model matching (exact, prefix, substring in either direction)
- `ServerCapability.from_lm_studio_probe()` factory method with `:probed` confidence level
- Added `supports_vision`, `max_context_length`, `probed?`, `vision?` to ServerCapability
- `CapabilityDetection#detect_capabilities` now accepts `model_id:` parameter for probing
- Integration test (`experiments/live/lm_studio_probe_test.rb`) validates against real Tailscale endpoints
- Updated `docs/references/lm_studio_api.md` to version 0.4.0+ with probing documentation
- 47 capability-related tests pass, all Rubocop clean

**Key findings from research:**
- llama.cpp: Cannot use `tools` AND `response_format` simultaneously (conflict)
- llama.cpp: Requires `--jinja` flag for tools, which breaks structured output
- LM Studio 0.4.0: `/api/v1/models` returns detailed capability info per model
- LM Studio: Native tool support for Qwen 2.5/3, Llama 3.x, GLM 4.x (via `trained_for_tool_use`)
- LM Studio: Vision support detection via `vision` field (e.g., Gemma 3n)

### F.2 End-to-End Local Model Testing
**Priority:** P0
**Effort:** 3-5 days
**Status:** ✅ Framework complete, initial data collected

Created structured evaluation framework (`experiments/live/eval/`):

| Component | Status | Location |
|-----------|--------|----------|
| YAML test suites | ✅ | `eval/suites/*.yml` |
| Suite loader | ✅ | `eval/lib/suite_loader.rb` |
| Test evaluator | ✅ | `eval/lib/evaluator.rb` |
| Result persistence | ✅ | `eval/lib/result_store.rb` |
| Report generator | ✅ | `eval/lib/reporter.rb` |
| Matrix runner | ✅ | `eval/run_matrix.rb` |
| CLI interface | ✅ | `eval/run.rb` |

**Initial Model Capability Matrix (2026-01-28):**

| Model | Basic Reasoning | Tool Calling | Avg Speed |
|-------|-----------------|--------------|-----------|
| granite-4.0-h-small | **100%** | 75% | 3729ms |
| google/gemma-3n-e4b | 80% | **100%** | 2500ms |
| glm-4.7-flash-mlx | 70% | 38% | 9482ms |
| zai-org/glm-4.7-flash | 60% | 0% | 6270ms |
| nemotron-3-nano (both) | 0% | 0% | - |

**Key Discoveries:**
- Agent uses `code_action` (Ruby code) not native OpenAI `tool_calls`
- granite: Sometimes ignores tool instructions for simple math
- gemma-3n-e4b: Best tool-calling model (100%), fastest
- nemotron: Complete failures - needs investigation (format/parsing issues?)

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

### F.4 Test Harness & System Improvements (Lessons Learned)
**Priority:** P0
**Effort:** 3-5 days
**Status:** 🔄 In Progress

Based on evaluation framework testing, these improvements are needed:

#### F.4.1 Tool Execution Tracking (Immediate)
**Problem:** Eval framework parses `code_action` strings with regex to detect tool usage - fragile.
**Solution:** Track actual tool executions via events.

| Task | Status |
|------|--------|
| Subscribe to `tool_execution_completed` events in evaluator | Pending |
| Add `tools_executed` to AgentResult | Pending |
| Remove regex parsing from evaluator | Pending |

#### F.4.2 Circuit Breaker Isolation (Immediate)
**Problem:** One 400 error trips circuit breaker, all subsequent tests fail instantly (0ms).
**Solution:** ✅ Reset circuit breakers on evaluator init + model warm-up prevents timeouts.

| Task | Status |
|------|--------|
| Build eval models without circuit breaker | N/A (reset works) |
| Or: Add circuit breaker reset between tests | ✅ Done in Evaluator#initialize |
| Distinguish circuit breaker opens from test failures | Partial (warm-up prevents most) |

#### F.4.3 Model Availability Detection (Short-term)
**Problem:** Tests fail with 400 "insufficient resources" when model not loaded.
**Solution:** Pre-check model availability before running suite.

| Task | Status |
|------|--------|
| Add `--verify-model` pre-check to CLI | Pending |
| Parse 400 error bodies to classify failures | Pending |
| Add `ModelNotLoadedError`, `InsufficientMemoryError` | Pending |
| Distinguish "model unavailable" from "test failed" in results | Pending |

#### F.4.4 Diagnostic Improvements (Short-term)
**Problem:** "expectation not met" isn't helpful for debugging.
**Solution:** Capture more context on failures.

| Task | Status |
|------|--------|
| Capture full model output in results | Pending |
| Capture generated `code_action` in results | Pending |
| Add `--verbose` mode showing step-by-step | Pending |
| Log API request/response on failure | Pending |

#### F.4.5 Nemotron Investigation (Immediate)
**Problem:** Nemotron models score 0% on all tests - complete failure.
**Root Cause:** ✅ Model loading time! Live loading takes 30-60s, test timeout was 15s.
**Solution:** ✅ Added model warm-up step (120s timeout) before running tests.

| Task | Status |
|------|--------|
| Capture raw nemotron outputs | ✅ Done |
| Check if output format differs from expected | ✅ N/A - format is fine |
| Check if model is generating valid code actions | ✅ Yes, works well |
| Document nemotron-specific requirements if any | ✅ Just needs warm-up |

**Actual Results:** Nemotron scores 90% reasoning, 75% tools (comparable to granite)

#### F.4.6 Native Tool Calling Mode (Medium-term)
**Problem:** Agent uses code actions (Ruby) not native OpenAI tool_calls. Some models are optimized for native format.
**Solution:** Investigate adding optional native tool calling mode.

| Task | Status |
|------|--------|
| Research: Is code action approach intentional? | Pending |
| Prototype native tool calling flow | Pending |
| Compare performance: code actions vs native | Pending |
| Document trade-offs | Pending |

---
## Phase G: Simplification

**Goal:** Reduce complexity while preserving essential functionality.

**Why:** 87 events when 36 are used. 8 search tools when 2 suffice. Testing utilities that belong in dev, not production.

**See `docs/RUBY4_REVIEW.md` for detailed findings from the full codebase review (2026-02-06).**

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
| Replace mappings.rb lambda indirection with autoload | -50 lines, cleaner loading |
| Replace AsyncQueue.DrainSignal with Ruby Queue | -20 lines |
| Merge dispatch_event/dispatch_event_sync in Emitter | -15 lines |

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
| Move to dev-only: Benchmarking, auto-gen, scenarios, tracers | Not needed in production |
| ~~Remove duplicate shared_examples.rb~~ (not duplicates — different purpose) | N/A |
| Use pattern matching in CallLog.matches? | -30 lines, +clarity |
| Impact | -800 lines from shipped gem |

### G.4 Ruby 4.0 Type & Concern Simplification (NEW)
**Priority:** P1
**Effort:** 3-5 days

Ruby 4.0 codebase review identified ~4,700 lines of recoverable boilerplate:

| Action | Impact |
|--------|--------|
| Delete manual `with()` overrides (Data.define provides it) | -200 lines across 20+ types |
| Create PresetFactory macro for type factories | -2,000 lines across 50+ types |
| Expand StatePredicates adoption | -1,500 lines across 50+ types |
| Create ImmutableUpdate support module | -60 lines across 20+ types |
| Standardize `it` block parameter (replace `_2`) | Consistency |
| Bundle builder concerns (14 → 5 groups) | Clarity |
| Centralize builder validators | -30 lines, DRY |
| Adopt pattern matching (case/in) where applicable | Idiomatic Ruby 4.0 |

**Quick wins (< 1 day):** Items 1, 3 (partial), 4, `it` standardization
**High-value refactors (1-2 days each):** Items 2, 3 (full), builder bundling

### G.5 Concern Consolidation
**Priority:** P3
**Effort:** 2-3 days

| Action | Impact |
|--------|--------|
| Relax 100-line rule to 150 for cohesive code | Less artificial splitting |
| Merge tiny files (e.g., task_coordination: 2 files → 1) | -15 files |
| Move MoA wave scheduling to MoA-specific concerns | Clearer boundaries |
| Simplify BaseConcern define_composite | -30 lines, less metaprogramming |

---
## Phase H: Feature Gap Enhancement (NEW)

**Goal:** Address identified gaps to improve usability and robustness of the framework.

**Why:** The framework is strong but can benefit from several improvements to make it more user-friendly and production-ready.

### H.1 Enhanced Tool Discovery and Documentation
**Priority:** P2
**Effort:** 2-3 weeks

**Current Gap:** Limited tool discovery and integrated documentation capabilities.

**Tasks:**
| Action | Impact |
|--------|--------|
| Implement tool discovery mechanisms | Better tool browsing experience |
| Add integrated tool documentation | Inline help and examples |
| Create auto-generated API references | Complete documentation coverage |
| Add tool search capabilities | Find tools by name, description, or functionality |
| Improve tool schema introspection | Better understanding of tool capabilities |

### H.2 Improved Error Handling and Recovery
**Priority:** P2
**Effort:** 2-3 weeks

**Current Gap:** Basic error handling with limited recovery mechanisms.

**Tasks:**
| Action | Impact |
|--------|--------|
| Enhance error recovery mechanisms | Better handling of model unavailability |
| Implement sophisticated error classification | More granular error types |
| Add retry strategies with exponential backoff | More resilient execution |
| Create graceful degradation policies | Fallback when primary fails |
| Implement timeout handling | Better resource management |

### H.3 Advanced Memory Management
**Priority:** P3
**Effort:** 3-4 weeks

**Current Gap:** Basic memory management with limited strategies.

**Tasks:**
| Action | Impact |
|--------|--------|
| Implement sophisticated context management | Better LRU eviction policies |
| Add flexible memory strategies | Different approaches for different use cases |
| Create long-term memory support | Persistent storage for important context |
| Implement memory profiling | Better understanding of memory usage patterns |
| Add memory size monitoring | Prevent memory overflows |

### H.4 Enhanced Testing Capabilities
**Priority:** P2
**Effort:** 2-3 weeks

**Current Gap:** Limited testing utilities for advanced use cases.

**Tasks:**
| Action | Impact |
|--------|--------|
| Add tool-specific mocking | Better isolated testing |
| Implement agent state testing | Test agent behavior in different states |
| Create integration testing framework | Test with various model configurations |
| Add comprehensive test fixtures | Standard scenarios for testing |
| Implement performance testing utilities | Benchmark different configurations |

### H.5 Better Configuration Management
**Priority:** P3
**Effort:** 2-3 weeks

**Current Gap:** Basic configuration management with limited features.

**Tasks:**
| Action | Impact |
|--------|--------|
| Add configuration inheritance | Better organization of settings |
| Implement environment-based loading | Configuration per deployment environment |
| Add configuration validation | Better error messages for invalid settings |
| Create configuration documentation | Clear understanding of available options |

### H.6 Enhanced Multi-Agent Coordination
**Priority:** P3
**Effort:** 4-5 weeks

**Current Gap:** Basic multi-agent support with limited coordination patterns.

**Tasks:**
| Action | Impact |
|--------|--------|
| Add sophisticated communication protocols | Better agent-to-agent communication |
| Implement agent state synchronization | Shared state management |
| Create enhanced delegation mechanisms | More sophisticated task assignment |
| Add coordination pattern libraries | Standard patterns for common scenarios |
| Implement task prioritization | Better resource allocation |

### H.7 Enhanced Event System
**Priority:** P2
**Effort:** 3-4 weeks

**Current Gap:** Event system is good but could be expanded.

**Tasks:**
| Action | Impact |
|--------|--------|
| Add more granular event types | Better observability |
| Implement event filtering | More precise subscription mechanisms |
| Add event persistence | Audit trails and historical data |
| Create event processing pipelines | Complex event handling |
| Implement event validation | Ensure data integrity |

### H.8 Better Performance Monitoring
**Priority:** P3
**Effort:** 2-3 weeks

**Current Gap:** Limited performance monitoring capabilities.

**Tasks:**
| Action | Impact |
|--------|--------|
| Add detailed metrics collection | Better performance understanding |
| Implement integration with monitoring tools | Standard monitoring solutions |
| Create profiling and debugging support | Better tool for finding bottlenecks |
| Add performance benchmarks | Standard measurements |
| Implement resource usage tracking | Monitor memory, CPU, I/O |

### H.9 Language Model Specific Optimizations
**Priority:** P3
**Effort:** 4-5 weeks

**Current Gap:** Limited model-specific features and optimizations.

**Tasks:**
| Action | Impact |
|--------|--------|
| Add model-specific configuration options | Better control over different models |
| Implement advanced prompt engineering | More sophisticated prompt techniques |
| Create model integration utilities | Easier integration with various providers |
| Add model-specific features | Features tailored to individual model capabilities |
| Implement provider-specific optimizations | Better performance with different providers |

### H.10 Improved Development Experience
**Priority:** P2
**Effort:** 2-3 weeks

**Current Gap:** Basic development experience without advanced tooling.

**Tasks:**
| Action | Impact |
|--------|--------|
| Add IDE support and auto-completion | Better coding experience |
| Implement debugging tools | Easier troubleshooting |
| Enhance REPL integration | Better interactive development |
| Add development utility helpers | Simplified development workflow |
| Create comprehensive documentation | Better learning experience |

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
| Core gem size | ~16k lines | ~11-12k lines (-25-30%) via G.3+G.4 |
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
| **H: Feature Gap Enhancement** | **Pending** | **P2-P3** | **Enhanced tool discovery, error handling, memory management, etc.** |
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
*Updated: 2026-01-31*
*Version: 3.1 (Evaluation Framework & Lessons Learned)*