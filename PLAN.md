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

**Test Suite:** 15,582 examples, 93%+ coverage, ~7s parallel

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
**Effort:** 2-3 weeks (~26h)
**Status:** ✅ Complete (2026-02-06)
**Prerequisite:** G.2 Tool Consolidation (fewer tools = less context wasted on tool descriptions)
**Absorbs:** ~~H.9~~ (Model-Specific Optimizations, 100% overlap), ~~H.2~~ model-facing parts (error classification, graceful degradation), ~~H.1~~ (tool schema introspection), ~~H.3~~ (context budgeting)

**Philosophy:** No model-size differentiation. ONE system that works beautifully for all models — small and large alike. Better prompts, better errors, better structure. Ruby magic, not conditional branching.

**Key Insight:** Tool calling failures are **syntactic** (models can't produce the right Ruby code format), not semantic (they understand the tasks). Prompt improvements directly address the #1 failure mode.

**Eval Baseline (pre-improvements):**

| Model | Size | Reasoning | Tool Calling | Notes |
|-------|------|-----------|-------------|-------|
| granite-4.0-h-small | ~4B | 100% | 100% | Best overall |
| gemma-3n-e4b | ~4B | 80-100% | 100% | Fastest inference |
| nemotron-3-nano | ~3B | 90% | 75% | Needs warm-up |
| glm-4.7-flash-mlx | ~7B | 70% | 25-50% | Timeout hangs |
| glm-4.7-flash (GGUF) | ~7B | 60% | 0% | Never produces tool syntax |

#### F.3.1 System Prompt Simplification
**Problem:** INTRO section packs ~10 concepts into ~300 tokens. Concise, focused instructions help every model perform better. Key confusion points: "results are hashes" but `calculate()` returns scalar; "STOP after closing ```" is ambiguous; "multiple tool calls run in parallel" describes framework magic models can't control.
**Files:** `lib/smolagents/utilities/prompts/agent/sections.rb`

| Task | Effort | Description |
|------|--------|-------------|
| Split INTRO into 3 focused blocks | 2h | Identity/Role, Code Format, Tool Rules — each <=100 tokens |
| Fix tool return type inconsistency | 1h | Document that tools return various types, not just hashes |
| Clarify "STOP after ```" instruction | 1h | Replace with "Write ONE code block per turn. Do not write text after it." |
| Remove parallel execution mention from model prompt | 0.5h | Models don't control parallelism — this is framework behavior |
| Reduce Chain of Draft arrow notation | 1h | Arrow chains (`A -> B -> C`) may confuse small tokenizers; use numbered steps |
| A/B test with eval framework | 1h | Run granite + gemma + nemotron before/after to measure improvement |

#### F.3.2 Upfront Capability Statement
**Problem:** Models discover sandbox constraints by trial-and-error (file I/O, network, shell). Each failed attempt wastes a step and confuses the model. No upfront list of what's allowed vs forbidden. Semantic breaker aborts silently — model never knows why it stopped.
**Files:** `lib/smolagents/concerns/agents/semantic_breaker.rb`, `lib/smolagents/executors/`

| Task | Effort | Description |
|------|--------|-------------|
| Add "You CAN / You CANNOT" block to system prompt | 1.5h | List: can call tools, can assign variables, can use Ruby stdlib. Cannot: file I/O, network, shell, require gems |
| Make semantic breaker non-silent | 1h | When breaker fires, inject system message: "Execution stopped: your responses appear to have drifted from the task. Re-read the original question and try a focused approach." |
| Add sandbox error suggestions | 1h | When NameError/NoMethodError in sandbox, suggest: "This operation is not available. Use the provided tools instead." |

#### F.3.3 Error Recovery Specificity
**Problem:** Generic errors say "Try a different approach" — too vague for any model. Rate limit errors correctly suggest specific alternatives, but sandbox errors, loop detection, and general failures don't. Models waste steps repeating the same mistake.
**Files:** `lib/smolagents/concerns/execution/error_feedback.rb`, `lib/smolagents/concerns/agents/react_loop/repetition.rb`, `lib/smolagents/concerns/execution/code_hints.rb`

| Task | Effort | Description |
|------|--------|-------------|
| Categorize errors into actionable buckets | 2h | Syntax error → show correct format; tool not found → show available tools; wrong args → show expected signature |
| Improve loop detection feedback | 1.5h | Current: "Try a different approach." Better: "You've repeated similar actions 3 times. The results haven't changed. Try: [specific alternative based on tool history]" |
| Add "did you mean?" for common code mistakes | 1.5h | `puts result` → "Use `final_answer(answer: result)` to return your answer"; `x = tool()` without using x → "Remember to use the result" |
| Extend code_hints for common model patterns | 1h | Add hints for: bare `return` (not in a method), `print`/`puts` (not how to answer), missing `final_answer` at end |

#### F.3.4 Tool Description Excellence
**Problem:** Tool descriptions lack return type information. Progressive disclosure is too sparse — models benefit from seeing one concrete example inline. The default format should be the best format for everyone.
**Files:** `lib/smolagents/tools/formatting/`, `lib/smolagents/utilities/prompts/agent/sections.rb`

| Task | Effort | Description |
|------|--------|-------------|
| Add return type to tool descriptions | 1.5h | Every tool says "Returns: String" or "Returns: Hash with keys :title, :url" |
| Make default format include one usage example | 2h | Description + one example call + return type as the ONE standard format |
| Improve final_answer tool description | 0.5h | Make it prominent: "YOU MUST call final_answer(answer: your_result) to complete the task" |
| Consolidate format modes into one excellent default | 1h | Eliminate format proliferation — one format that's concise, complete, and clear |

#### F.3.5 Prompt Efficiency & Token Budget
**Problem:** System prompt can consume 30-50% of context. Token counting is heuristic (chars/4) which over-counts. Wasted context hurts every model — not just small ones.
**Files:** `lib/smolagents/utilities/prompts/`, `lib/smolagents/concerns/agents/prompt_building/`, `lib/smolagents/utilities/token_counting.rb`

| Task | Effort | Description |
|------|--------|-------------|
| Tighten the system prompt | 2h | Essential rules only, 1 strong example (not 3 mediocre ones), no redundancy — make every token earn its place |
| Improve token counting accuracy | 1.5h | Better estimation that works across tokenizers |
| Budget-aware prompt assembly | 1.5h | If system prompt exceeds context budget, trim gracefully with warning event — good engineering for all models |

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
**Problem:** Agent uses code actions (Ruby) not native OpenAI tool_calls. Some models (glm-4.7-flash GGUF) score 0% on tool calling because they can't produce Ruby code syntax, but may handle native JSON tool_calls fine.
**Research Complete (2026-02-06):**
- Code action approach IS intentional: enables variable assignment, multi-tool composition, conditional logic, lazy evaluation via Futures
- Ruby code generation is significantly harder than JSON tool_calls for small models
- Code extraction is robustly flexible (handles malformed fences, ChatML tokens, thinking tags)
- Trade-off: code actions are more powerful but have higher syntactic barrier for <4B models
- llama.cpp has a critical conflict: can't use `tools` parameter AND `response_format` simultaneously

**Decision:** Keep code actions as primary mode. Add native tool calling as optional fallback for models that can't generate Ruby.

| Task | Status |
|------|--------|
| Research: Is code action approach intentional? | Done — yes, enables composition/futures |
| Design native tool calling adapter | Pending — maps tool_calls to/from internal ToolPause |
| Handle llama.cpp tools/response_format conflict | Pending — server_capabilities already tracks this |
| Prototype native tool calling flow | Pending |
| Compare performance: code actions vs native | Pending — use eval framework |
| Add `.tool_calling_mode(:code \| :native \| :auto)` to ModelBuilder | Pending |

---
## Phase G: Simplification

**Goal:** Reduce complexity while preserving essential functionality.

**Why:** Fewer tools, events, and modules directly reduce context pressure for small models. **G.2 is a prerequisite for F.3.4/F.3.5** — extracting rarely-used tools shrinks the tool description block that consumes model context.

**See `docs/RUBY4_REVIEW.md` for detailed findings from the full codebase review (2026-02-06).**

### G.1 Event System Reduction
**Priority:** P1
**Effort:** 3-5 days

Reduce from 52 registered to ~41 focused events:

| Action | Impact |
|--------|--------|
| ~~Remove 11 never-emitted events from registry~~ | ✅ Done (-144 lines, 52→41 events) |
| ~~Replace AsyncQueue.DrainSignal with Ruby Queue~~ | ✅ Done (-22 lines) |
| ~~Merge dispatch_event/dispatch_event_sync in Emitter~~ | ✅ Done (-15 lines) |
| ~~Delete `events/registry/built_in.rb`~~ | N/A (used by Registry for DSL introspection) |
| Consolidate task coordination: 13 → 4 events | Clearer API |
| Replace mappings.rb lambda indirection with autoload | ~0 net savings (wash) |
| Document essential 20 events prominently | Better DX |
| Event filtering and subscription refinement | More precise handlers (from old H.7) |
| Event persistence for audit trails | Historical data (from old H.7, P3) |

**Essential events to preserve:**
- Core lifecycle: task_started, task_complete, step_complete, error
- Tools: tool_call, tool_complete
- Models: model_generate_requested, model_generate_completed
- Planning: plan_generated, plan_updated
- Resilience: retry, failover

### G.2 Tool Consolidation ⬆️ PREREQUISITE FOR F.3
**Priority:** P1 (raised from P2 — directly enables F.3.4/F.3.5)
**Effort:** 1-2 days
**Status:** ✅ Complete (2026-02-06)
**Do before:** F.3.4 (Tool Descriptions), F.3.5 (Prompt Profiles)

| Action | Impact |
|--------|--------|
| Keep: DuckDuckGo (free), Google (premium) | Core search |
| Extract: ArXiv, Wikipedia, Bing, Brave, SearXNG | Move to examples or plugin |
| Impact | -400 lines from core, **-5 tool descriptions from model context** |

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

### G.4 Ruby 4.0 Type & Concern Simplification
**Priority:** P1
**Effort:** 3-5 days

Ruby 4.0 codebase review identified ~4,700 lines of recoverable boilerplate:

| Action | Impact |
|--------|--------|
| ~~Delete manual `with()` overrides~~ | ✅ Done (-14 lines, 6 types) |
| ~~FactoryBuilder adoption~~ | ✅ Done (-59 lines, 4 types — actual scope ~150 lines, not 2,000) |
| ~~Expand StatePredicates adoption~~ | ✅ Done (-62 lines, 11 types — actual scope ~60 predicates) |
| ~~ImmutableUpdate module~~ | N/A (remaining `with_*` methods add semantic value) |
| ~~Replace `_2` with named block params~~ | ✅ Done (4 instances in 2 files) |
| ~~Adopt pattern matching (case/in)~~ | ✅ Done (2 methods: resolve_dependencies, primitive?) |
| Bundle builder concerns (14 → 5 groups) | Clarity |
| Centralize builder validators | -30 lines, DRY |

**Completed:** Items 1-6 (net -275 lines). Original estimates were inflated.
**Remaining:** Builder bundling, validators

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
## Phase H: Enhancements (POST-F, POST-G)

**Goal:** Improve framework usability and robustness after model reliability and simplification are solid.

**Reorganization (2026-02-06):** Original H.1–H.10 consolidated to 4 focused areas after absorbing overlapping work into F.3:

| Original Section | Disposition |
|------------------|-------------|
| ~~H.9 Model-Specific Optimizations~~ | **100% absorbed into F.3** (prompt profiles, model-specific config, prompt engineering) |
| ~~H.2 Error Handling (model-facing)~~ | **Absorbed into F.3.2 + F.3.3** (error classification, graceful degradation) |
| ~~H.1 Tool Discovery (schema parts)~~ | **Absorbed into F.3.4** (return types, schema introspection for prompts) |
| ~~H.3 Memory (context budgeting)~~ | **Absorbed into F.3.5** (budget-aware prompt assembly, token counting) |
| ~~H.7 Event System~~ | **Merged into G.1** (event filtering, persistence as follow-on tasks) |
| H.1 (user-facing), H.10 | → **H.1 Developer Experience & Tool Discovery** |
| H.4, H.8 | → **H.2 Testing, Diagnostics & Monitoring** |
| H.2 (infra), H.5 | → **H.3 Infrastructure & Configuration** |
| H.3 (non-context), H.6 | → **H.4 Advanced Features** |

### H.1 Developer Experience & Tool Discovery
**Priority:** P2
**Effort:** 3-4 weeks
**From:** Old H.10 (Development Experience) + H.1 (Tool Discovery, user-facing parts)

| Area | Tasks |
|------|-------|
| Tool Discovery | Tool browsing/search by name, description, or capability; auto-generated API references |
| IDE & Tooling | Auto-completion support, debugging utilities, REPL integration |
| Documentation | Comprehensive guides, inline help, examples for all builder methods |

### H.2 Testing, Diagnostics & Monitoring
**Priority:** P2
**Effort:** 3-4 weeks
**From:** Old H.4 (Enhanced Testing) + H.8 (Performance Monitoring)

| Area | Tasks |
|------|-------|
| Testing | Tool-specific mocking, agent state testing, integration test framework, standard fixtures |
| Diagnostics | Verbose step-by-step mode, API request/response logging on failure |
| Monitoring | Metrics collection, profiling support, resource usage tracking, benchmarks |

### H.3 Infrastructure & Configuration
**Priority:** P3
**Effort:** 2-3 weeks
**From:** Old H.2 (Error Handling, infrastructure parts) + H.5 (Configuration Management)

| Area | Tasks |
|------|-------|
| Resilience | Retry strategies with exponential backoff, timeout handling, infrastructure-level error recovery |
| Configuration | Config inheritance, environment-based loading, validation and documentation |

### H.4 Advanced Features
**Priority:** P3
**Effort:** 6-8 weeks
**From:** Old H.3 (Memory, non-context parts) + H.6 (Multi-Agent Coordination)

| Area | Tasks |
|------|-------|
| Memory | Long-term persistent storage, LRU eviction policies, memory profiling, flexible strategies |
| Multi-Agent | Communication protocols, state synchronization, enhanced delegation, task prioritization |

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
**Depends on:** F.3.5 (prompt profiles for local model guide), G.2 (tool consolidation)

| Task | Description |
|------|-------------|
| YARD docs | All DSL builder methods |
| Multi-model guide | Building agents with multiple models |
| Local model guide | llama.cpp and LM Studio setup, **prompt profiles for small models** |
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
## Recommended Execution Order

```
G.2 Tool Consolidation (1-2 days)       ✅ Complete
 ↓
F.3 Model Empathy (2-3 weeks)           ✅ Complete
 ↓
F.4 Test Harness (3-5 days)             ← NEXT: measure F.3 improvements with eval framework
 ↓
G.1, G.3–G.5 Simplification (1-2 weeks) ← clean up while patterns fresh
 ↓
H.1–H.4 Enhancements (as needed)       ← build on solid foundation
 ↓
E-2 Privacy & Polish                    ← final layer
```

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

| Metric | Baseline (2026-02-06) | Target |
|--------|----------------------|--------|
| granite-4.0-h-small tool calling | 100% | Maintain |
| gemma-3n-e4b tool calling | 100% | Maintain |
| nemotron-3-nano tool calling | 75% | 90%+ |
| glm-4.7-flash-mlx tool calling | 25-50% | 80%+ |
| glm-4.7-flash (GGUF) tool calling | 0% | 50%+ (or via native tool calling) |
| Average tokens per task | TBD | -30% (with prompt profiles) |
| Loop/stuck rate | TBD | <5% |
| Event count | 41 | 35-40 |
| Core gem size | ~16k lines | ~11-12k lines (-25-30%) via G |
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
| G.2: Tool Consolidation | ✅ Complete | P1 | 5 search tools extracted, -1740 lines from core |
| F.3: Model Empathy | ✅ Complete | P0 | Prompt simplification, error recovery, budget-aware assembly |
| **F.4: Test Harness** | **Next** | **P0** | **Eval improvements, native tool calling** |
| G: Simplification (rest) | Pending | P1 | Event reduction, testing cleanup, concern consolidation |
| H: Enhancements (4 areas) | Pending | P2-P3 | DX & tools, testing & monitoring, infra & config, advanced features |
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
*Updated: 2026-02-06*
*Version: 4.0 (Model Empathy Research + Phase Reorganization)*