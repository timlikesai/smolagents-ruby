# smolagents-ruby Implementation Plan

**Branch:** feature/tool-future-lazy-eval
**Updated:** 2026-02-08
**Version:** 9.0 (Internal Orchestration Architecture)

---
## Executive Summary

**Core Insight**: "Help the model by giving it less to think about, not more."

**Vision**: An engine for people to build their own Claude Code — the core agent runtime provides the thinking, tool calling, error recovery, and coordination. Everything else is UI.

**Current Priority**: Phase N (Internal Orchestration Architecture) complete. Confidence-based tool routing enables fast dispatcher models to handle routine tool calls while primary models handle complex reasoning. **Critical insight: Single-model efficiency is the sensible default** — the orchestration layer makes agents token-efficient and fast even without a dispatcher. Multi-model routing is an optional enhancement for users who want to add FunctionGemma, LFM, or other small models as fast internal engines.

---
## Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| Event System | ✅ Complete | 49 events, 17 categories, user/internal tiers. ParseRetryAttempted added (L.2). |
| Execution Model | ✅ Hardened | Ractor-based lazy futures, wave resolution. Parse retry configurable (default 2). GenerationTimeout wraps all 9 call sites. |
| Tool System | ✅ Good | Schema validation, retry, timeout, "Did You Mean?" |
| Builder DSL | ✅ Excellent | Three-tier (Simple/Builder/Advanced) + MoA, 35+ builder methods. `.generation_timeout()` added. |
| Model Integration | ✅ Validated | Server capability detection tested with real LM Studio/llama.cpp |
| Resilience | ✅ Complete | Retry, circuit breaker, rate limiting, failover, health checks. Cascading failures tested. Retry at model-level via `.with_retry()`, timeout at agent-level via GenerationTimeout. Server-type resilience defaults (M). HTTP 5xx non-circuit (M.1). |
| Memory System | ✅ Complete | Working memory, reflection memory (LRU), budget strategies. Context compression (K.3). Multi-turn (K.1). |
| Multi-Agent | ✅ Complete | Spawn, delegate, team builder, wave scheduling. Parallel sub-agent dispatch (K.4). Cancellation (K.2). Cost accounting (K.5). Gaps: no sibling communication. |
| Agent Loop | ✅ Hardened | Single ReAct loop with parse retry, completion validation, planning/evaluation/repetition. Multi-turn, cancellation, token budget at step boundaries. |
| Phase H Diagnostics | ✅ Complete | Debug mode, stats tracking, failure capture, config profiles, memory inspection |
| Phase I Prompt Formatting | ✅ Complete | YARD-style tool rendering, Ruby 4.0 identity, `it` keyword coaching, `.inspect` observations, block param hints |
| Phase J Adversarial Testing | ✅ Complete | MockModel conditional + adversarial factories, completion validation, parse retry, StepCompleted enrichment, adversarial + cascading + spawn integration tests |
| Phase K Engine Completeness | ✅ Complete | Multi-turn, cancellation, compression, parallel dispatch, cost accounting, streaming |
| Post-K Hardening | ✅ Complete | Token budget wiring, context window check, configurable parse retry, complex workflow tests |
| Phase N Orchestration | ✅ Complete | ToolRouter, RoutedToolExecution, ConfidenceScorer, ModelProfiles. Single-model-first with optional dispatcher enhancement. |
| Testing | ✅ Adversarial | 15,772 deterministic tests. MockModel supports conditional responses + adversarial factories. Adversarial, cascading failure, spawn, and routing integration tests. |

**Test Suite:** 15,772 examples, 0 failures, ~6s parallel
**Architecture:** 69 concerns, 94 Data.define types, 51 events (55 ceiling)

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
| **M: Model Integration Resilience** | HTTP 5xx non-circuit classification (transient_server_error? checks response_status), ServerType resilience_defaults (llama_cpp: 5 retries, threshold 10, 60s cool-off), ApiClient circuit config kwargs, OpenAIModel server-type-aware retry/circuit config |
| **N: Internal Orchestration** | ToolRouter, RoutedToolExecution, ConfidenceScorer, ModelProfiles, SpeculativeToolCall, routing events. Single-model-first design with optional fast dispatcher enhancement. |

### Event System Design Principles (Locked In)

1. **Don't add events speculatively.** Every new event must have at least one consumer.
2. **Lifecycle pattern is default.** Add a phase to an existing lifecycle event first. Only create new event types when the data shape is fundamentally different.
3. **44 events, 50 ceiling.** New features should reuse existing events. If we exceed 50, audit and consolidate.
4. **No performance optimization needed.** LLM calls are 100-5000ms. Event overhead (<1ms/step) is noise.
5. **User events vs internal events.** 11 user-tier events for subscribers, 33 internal for infrastructure.
6. **Fully evented, non-blocking.** No sleep, no polling. Queue#pop for blocking waits, instant wakeup on push/close.

---
## Phase H: Local-GPU-Ready Enhancements ✅ (Compact)

Debug mode (`.debug`), VerboseSubscriber, AgentStats/StatsTracking, FailureCapture (bounded circular buffer), config profiles (`:local_gpu`, `:development`, `:cloud_api`), memory inspection (`memory_budget_usage`, `memory_summary`), builder pre-build validation, GPU test fixtures (`GpuFixtures.unreliable_model`, etc.), ResourceUsage type. **0 new events** — all concerns consume existing events. See git history for detailed design docs.

---
## Shakedown Findings

### First Shakedown (Opus 4.6, 2026-02-07)

Full codebase review by 6 parallel Opus 4.6 exploration agents (~475K tokens of analysis, ~280 file reads). Identified failure states, structural gaps, and testing blind spots. All findings addressed in Phases J, K, and Post-K.

### Critical Failure States (Will Break With Real Models)

| ID | Failure | Risk | Location | Status |
|----|---------|------|----------|--------|
| F1 | **No parsing retry** — each parse failure costs a full step from budget | HIGH | `concerns/execution/parse_retry.rb` | ✅ J.5 |
| F2 | **No output validation** — `validate_completion()` is a no-op stub, accepts nil/empty answers | HIGH | `concerns/agents/completion_validation.rb` | ✅ J.3 |
| F3 | **Ractor has no memory limit** — model-generated code can OOM the process | MEDIUM | `executors/ractor.rb:78-105` | ✅ K.5 |
| F4 | **30s timeout not interruptible** — tight CPU loops won't yield to interrupt | LOW | `execution/code_execution.rb:72` | Deferred |
| F5 | **Spawn execution untested** — config validated but actual spawn+execute+failure never tested | HIGH | `spec/integration/spawn_execution_spec.rb` | ✅ J.2.4 |
| F6 | **Cascading failures untested** — individual resilience components tested, interaction paths not | MEDIUM | `spec/integration/cascading_failure_spec.rb` | ✅ J.2.3 |
| F7 | **No circular fallback chain detection** — fallback model fails → infinite loop possible | LOW | `concerns/resilience/fallback.rb` | Deferred |

### Event System Gaps

| ID | Gap | Impact | Status |
|----|-----|--------|--------|
| E1 | Token usage not in user-tier events (`StepCompleted`, `TaskLifecycle`) | UI can't show cost | ✅ J.4 |
| E2 | No correlation IDs linking step → model call → tool execution | UI can't render causal chains | ✅ K |
| E3 | No context window pressure event (budget tracking only injects into observations) | UI can't show "context 78% full" | ✅ J.4 |
| E4 | Sub-agent events lack hierarchy depth field | UI can't render nesting depth | ✅ K |
| E5 | No agent_id filter on event subscriptions — must filter in handler | Performance at scale | Deferred |

### Loop & Coordination Gaps

| ID | Gap | Impact | Status |
|----|-----|--------|--------|
| L1 | **No inner thinking loop** — every step is think+act in one model call | Can't separate reasoning from execution | Deferred (K) |
| L2 | **No adaptive step budgeting** — fixed at config time | Agent can't request more steps for complex tasks | Deferred (K) |
| L3 | **No agent cancellation** — once `run()` starts, only max_steps or final_answer stops it | Users can't abort runaway agents | ✅ K.2 |
| L4 | **No multi-turn conversation** — each `run()` is independent, no `continue()` | Can't build conversational agents | ✅ K.1 |
| L5 | **No context compression** — older steps not summarized as context fills | Long-running agents hit context wall | ✅ K.3 |
| L6 | **No parallel sub-agent execution** — team coordinator calls sub-agents sequentially | Can't dispatch research swarm concurrently | ✅ K.4 |
| L7 | **No sibling communication** — sub-agents talk only to parent | Can't build writer+tester iteration patterns | Deferred |
| L8 | **No cost accounting across hierarchy** — token limits per-agent, not per-tree | Budget overruns in agent trees | ✅ K.5 |

### Testing Gaps

| ID | Gap | Severity | Status |
|----|-----|----------|--------|
| T1 | **No adversarial model tests** — all integration tests pre-script model responses | HIGH | ✅ J.2.1 |
| T2 | **MockModel can't do conditional responses** — pure FIFO, ignores input content | HIGH | ✅ J.1.1 |
| T3 | **No circular reasoning detection test** — repetition detection exists but untested in loop | MEDIUM | ✅ K |
| T4 | **No cascading failure integration test** — tool fail → retry → circuit break → recovery | MEDIUM | ✅ J.2.3 |
| T5 | **No model format drift test** — model returns wrong format, verify graceful degradation | HIGH | ✅ J.2.1 |
| T6 | **SpyTool has no tests** — implementation exists at `testing/helpers/spy_tool.rb` | LOW | ✅ K |
| T7 | **Shared examples too high-level** — don't test resilience, events, or error recovery contracts | MEDIUM | ✅ K |

### Second Shakedown (Opus 4.6, 2026-02-08)

Post-K review by 6 parallel Opus 4.6 agents: looping constructs, sub-agent coordination, eventing completeness, error handling, test coverage, builder DSL. Validated all 48 events are emitted correctly. Corrected false findings from earlier Haiku agents (~10 events falsely flagged as "not emitted"). Identified 5 remaining gaps → Phase L.

| ID | Gap | Risk | Status |
|----|-----|------|--------|
| S2-1 | `model.generate()` unwrapped at 10+ call sites (no timeout) | HIGH | → L.1 |
| S2-2 | Parse retry emits no event (UI has no visibility) | MEDIUM | → L.2 |
| S2-3 | Resilience concerns NOT in default AgentRuntime | MEDIUM | → L.3 |
| S2-4 | No compound integration tests (spawn+cancel+compress combined) | MEDIUM | → L.4 |
| S2-5 | Builder has no `validate_required!` on `build()` | LOW | → L.5 |

---
## Phase J: Adversarial Testing & Failure Hardening ✅ COMPLETE

**Goal:** Make the system provably robust against real-world failure modes.

**Completed:** 2026-02-07 | **Results:** +42 tests, MockModel adversarial factories, completion validation, parse retry.

| Deliverable | Status |
|------------|--------|
| J.1: Conditional MockModel responses | ✅ `when_input_matches`, adversarial factories |
| J.2: Adversarial integration tests | ✅ Format drift, cascading failures, spawn execution |
| J.3: Default completion validation | ✅ Rejects nil/empty final_answer |
| J.4: Event system hardening | ✅ Token usage in StepCompleted |
| J.5: Parse retry budget | ✅ 2 retries default, configurable |

### Testing Philosophy (Locked In)

1. **Instant-fast** (~10s total) — agents run `rake spec` dozens of times per session
2. **Silent on success** — clean output = clean context
3. **Diagnostic on failure** — never pipe/filter test output
4. **Deterministic** — MockModel, no randomness, no network
5. **Adversarial by default** — every feature: happy path + failure + recovery

### Architecture Rules (All Phases)

| Pattern | Rule |
|---------|------|
| Types | `Data.define` in `types/`, factory `.default` method, frozen |
| Concerns | ≤100 lines, registered in `concerns/registrations/` |
| Events | Reuse existing (55 ceiling). Budget carefully. |
| Testing | Instant-fast (<120ms). No sleep/polling. Queue#pop for blocking |
| Non-blocking | No `sleep`, no `Timeout.timeout`. Evented wakeup patterns only |

---
## Phase K: Engine Completeness — "Build Your Own Claude Code" ✅ COMPLETE

**Goal:** Fill the structural gaps for the agent engine vision. After Phase J proves robustness, Phase K adds the capabilities needed for sophisticated, long-running, interactive agents.

**Completed:** 2026-02-07 | **Results:** +203 tests, +8 concerns, +4 types, +2 events, CI green.

**Delivered capabilities:**
- Multi-turn conversation (user asks follow-ups) ✅
- Agent cancellation (user can abort a runaway agent) ✅
- Context compression (long conversations don't hit walls) ✅
- Parallel sub-agent dispatch (research swarm runs concurrently) ✅
- Cost visibility and control (track spend across agent tree) ✅
- Streaming output (token-by-token to UI) ✅

**Shakedown gaps also closed:** E2 (correlation IDs), E4 (sub-agent depth), F3 (OOM protection), T3 (repetition integration), T6 (SpyTool tests), T7 (shared examples).

### K.1: Multi-Turn Conversation ✅

`MultiTurn` concern + `ConversationTurn` type. `agent.continue("follow-up")` preserves memory, resets step counter per turn. Turn tracking, max_turns enforcement, lazy initialization.

### K.2: Agent Cancellation ✅

`Cancellation` concern + `CancellationToken` (Mutex-based, thread-safe). `agent.cancel!` from any thread, checked at step boundaries. Returns `RunResult.cancelled`. Added `:cancelled` to Outcome states.

### K.3: Context Compression ✅

`Memory::Summarization` module + `SummaryStep` type. When memory exceeds threshold (default 75%), oldest action steps summarized via model call and replaced with SummaryStep. Strategies: `:summarize`, `:hybrid`. `ContextCompressed` event emitted.

### K.4: Parallel Sub-Agent Execution ✅

`ParallelDispatch` module (Thread-based) + `Orchestration::ParallelExecution` concern. Error isolation per agent. SubAgentLaunched/Completed events per agent.

### K.5: Cost Accounting Across Hierarchy ✅

`CostAccounting` concern + `TokenBudgetExceeded` error. `consume_tokens()` accepts Integer, Hash, or TokenUsage-like objects. `remaining_token_budget`, `check_token_budget!`. SpawnContext extended with `remaining_tokens`.

### K.6: Streaming Output ✅

`Streaming` module. `generate_with_streaming()` uses `generate_stream` when available, emits `ModelTokenGenerated` events per token. Falls back to standard `generate` when streaming unavailable.

---
## Post-K Hardening (2026-02-08)

**Goal:** Wire shakedown findings into the engine — event emission, config threading, pre-generation safety.

**Completed:** 2026-02-08 | **Results:** +12 tests, +2 events, +1 configurable concern, CI green.

### P0: Critical Wiring (all ✅)
1. **Token budget enforcement** — `CostAccounting` concern included in `AgentRuntime`, `check_token_budget_if_enabled` called at step boundaries
2. **ContextCompressed event** — `compress_context_before_generation` in `CodeGeneration`, emits `ContextCompressed` event when memory compresses
3. **Pre-generate context window check** — `check_context_window` estimates tokens (4 chars/token heuristic), emits `ContextWindowExceeded` event when exceeding model window. Soft warning (no block) since estimation is heuristic. `context_window` threaded through `ModelConfig` → `Model::Configuration` → `ModelBuilder`
4. **Complex deterministic workflow tests** — 6 new integration tests: 6-step tool chain, malformed recovery, planning+multi-step, token budget enforcement, max_steps exhaustion, token usage tracking

### P1: Operational Polish (all ✅)
5. **TokenBudgetExhausted event** — Emitted in `cost_accounting.rb` before `finalize()`, enabling UI to show budget exhaustion
6. **Configurable parse retry** — `parse_max_retries` threaded through `AgentBuilder` → `AgentConfig` → `AgentRuntime` → `ParseRetry`. Default 1, range 0-10. Builder DSL: `.parse_max_retries(3)`
7. **`.as()` validation** — Already implemented (raises `ArgumentError` with available names). No changes needed.

---
## Phase L: Pre-Model Hardening ✅ COMPLETE

**Goal:** Close every remaining structural gap that would cause failures with real models.

**Completed:** 2026-02-08 | **Results:** GenerationTimeout at 9 call sites, ParseRetryAttempted event, compound workflow tests.

| ID | Deliverable | Status |
|----|-------------|--------|
| L.1 | GenerationTimeout concern wrapping all model.generate() calls | ✅ |
| L.2 | ParseRetryAttempted event (user-tier) for UI visibility | ✅ |
| L.3 | Resilience wiring (model-level via `.with_retry()`) | ✅ N/A |
| L.4 | Compound integration tests (6 scenarios) | ✅ |
| L.5 | Builder validation (already in `resolve_model()`) | ✅ N/A |

---
## Phase M: Model Integration Resilience ✅ COMPLETE

**Goal:** Graceful model loading/swapping on local servers. Server-type-aware resilience.

**Completed:** 2026-02-08 | **Results:** HTTP 5xx non-circuit, llama_cpp resilience defaults (5 retries, 60s circuit).

| Deliverable | Status |
|------------|--------|
| M.1: Server 5xx non-circuit classification (`transient_server_error?`) | ✅ |
| M.2: ServerType `resilience_defaults` + model builder integration | ✅ |
| M.3: 8 integration tests (500 sequence, circuit stays closed) | ✅ |

---
## Phase N: Internal Orchestration Architecture ✅ COMPLETE

**Goal:** Provide a flexible internal orchestration layer that makes agents token-efficient and fast with sensible defaults, while optionally enabling fast dispatcher models for enhanced performance.

**Critical Insight:** The system must work excellently with a SINGLE model as the sensible default. Good orchestration should be token-efficient and fast even without a tiny dispatcher model. Only THEN can users optionally plug in FunctionGemma, LFM, or other small models as a fast internal engine.

### Design Philosophy

**Single-Model-First Architecture:**

1. **Default path (no dispatcher):** Standard NativeToolExecution with token-efficient context management. Every agent works well out of the box with just the primary model.

2. **Enhanced path (with dispatcher):** Optional ToolRouter enables a fast small model to predict tool calls, with confidence-based routing to determine execution strategy.

3. **Graceful fallback:** Any dispatcher failure automatically routes to the primary model. The system never fails because of dispatcher issues.

**Why This Matters:**

- Most users have ONE capable model configured
- Adding complexity shouldn't be required for good performance
- Dispatcher models are an optimization, not a requirement
- The engine should "help the model by giving it less to think about"

### Components Built

| Component | Purpose | Location |
|-----------|---------|----------|
| `ToolRouter` | Orchestrates dispatcher/primary with configurable thresholds | `routing/tool_router.rb` |
| `RoutedToolExecution` | Extends NativeToolExecution with optional routing | `concerns/execution/routed_tool_execution.rb` |
| `ConfidenceScorer` | Scores tool calls based on semantic and syntactic validity | `models/function_gemma/confidence_scorer.rb` |
| `ModelProfiles` | Empirically-tuned thresholds per dispatcher model | `routing/model_profiles.rb` |
| `SpeculativeToolCall` | Confidence-wrapped tool call with validation predicates | `types/speculative_tool_call.rb` |
| `ToolRouterConfig` | Configuration for routing behavior | `types/tool_router_config.rb` |
| `RouteResult` | Result of routing decision with source/confidence/timing | `types/route_result.rb` |
| `RoutingConcern` | Builder DSL for configuring dispatcher | `builders/agent_builder/routing_concern.rb` |
| Routing Events | ToolRouted, DispatcherError for observability | `events/routing.rb` |

### Routing Flow

```
User Task
    │
    ▼
┌───────────────────────────────────────────────────────────┐
│ Agent.execute_native_step                                  │
│                                                            │
│   tool_routing_enabled? ─────────────────────────────────┐│
│         │                                                ││
│         ▼ NO                                             ││
│   ┌─────────────────┐                                    ││
│   │ NativeToolExec  │  ← Standard path (single model)    ││
│   │ Primary only    │                                    ││
│   └─────────────────┘                                    ││
│         │ YES                                            ││
│         ▼                                                ││
│   ┌─────────────────┐                                    ││
│   │ ToolRouter.route│  ← Enhanced path (dispatcher)      ││
│   └────────┬────────┘                                    ││
│            │                                             ││
│            ▼                                             ││
│   ┌────────────────────┐                                 ││
│   │ Dispatcher.generate│  Fast small model prediction    ││
│   └────────┬───────────┘                                 ││
│            │                                             ││
│            ▼                                             ││
│   ┌────────────────────┐                                 ││
│   │ ConfidenceScorer   │  Validate tool + args + types   ││
│   └────────┬───────────┘                                 ││
│            │                                             ││
│            ▼                                             ││
│   ┌────────────────────────────────────────┐             ││
│   │ Confidence >= high_threshold (0.75)?   │             ││
│   │   YES → Execute directly               │             ││
│   │   MEDIUM → Validate with primary       │             ││
│   │   LOW → Delegate entirely to primary   │             ││
│   └────────────────────────────────────────┘             ││
│                                                          ││
│   Any error? → Graceful fallback to primary ─────────────┘│
└───────────────────────────────────────────────────────────┘
```

### Configuration

**Builder DSL (optional dispatcher):**

```ruby
# Default: single model, no dispatcher
agent = Smolagents.agent
  .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
  .tools(:search, :calculate)
  .build

# Enhanced: with fast dispatcher
agent = Smolagents.agent
  .model { OpenAIModel.lm_studio("qwen-7b") }
  .dispatcher { OpenAIModel.lm_studio("lfm2.5-1.2b-instruct-mlx") }
  .tools(:search, :calculate)
  .build

# Custom thresholds
agent = Smolagents.agent
  .model { primary }
  .dispatcher(dispatcher, config: Types::ToolRouterConfig.new(
    high_threshold: 0.8,
    medium_threshold: 0.5,
    fallback_on_error: true
  ))
  .build
```

### Model Profiles (Empirically Tuned)

| Model | High Threshold | Medium Threshold | Notes |
|-------|---------------|-----------------|-------|
| lfm2.5-1.2b-instruct-mlx | 0.75 | 0.45 | Best balance of speed/accuracy |
| granite-micro-3b | 0.70 | 0.40 | More aggressive, faster |
| functiongemma-2b | 0.85 | 0.55 | Conservative, higher precision |
| Default (unknown) | 0.80 | 0.50 | Conservative fallback |

### Confidence Scoring

`ConfidenceScorer` evaluates SpeculativeToolCalls:

```ruby
# Scoring factors:
# +0.15  Valid tool exists and args match schema
# -0.40  Unknown tool name
# -0.15  Per missing required argument
# -0.05  Per unknown argument
# -0.10  Per type mismatch

result = ConfidenceScorer.score(speculative_call, tools)
result.confidence       # => 0.85
result.valid_tool?      # => true
result.args_valid?      # => true
result.missing_args     # => []
result.type_mismatches  # => []
result.executable?      # => true (confidence >= 0.5 and tool exists)
result.high_confidence? # => true (confidence >= 0.8)
```

### Events

Two new events for routing observability:

```ruby
:ToolRouted       # source, confidence, tool_count, latency_ms, fallback_used
:DispatcherError  # error, model_id, fallback_to
```

### Testing

35+ routing-specific tests covering:
- Default path (no dispatcher) works unchanged
- High confidence dispatcher execution
- Medium confidence primary validation
- Low confidence primary delegation
- Dispatcher error graceful fallback
- Unknown tool confidence penalties
- Type mismatch detection
- Builder DSL configuration

All tests are instant-fast (<120ms) using MockModel.

### Files Created/Modified

| File | Change |
|------|--------|
| `lib/smolagents/routing/tool_router.rb` | New: orchestrates routing decisions |
| `lib/smolagents/routing/model_profiles.rb` | New: per-model threshold profiles |
| `lib/smolagents/concerns/execution/routed_tool_execution.rb` | New: routing-aware execution |
| `lib/smolagents/models/function_gemma/confidence_scorer.rb` | New: tool call validation |
| `lib/smolagents/types/speculative_tool_call.rb` | New: confidence-wrapped tool call |
| `lib/smolagents/types/tool_router_config.rb` | New: routing configuration |
| `lib/smolagents/types/route_result.rb` | New: routing result type |
| `lib/smolagents/builders/agent_builder/routing_concern.rb` | New: builder DSL |
| `lib/smolagents/events/routing.rb` | New: routing events |
| 5 spec files | 35+ new tests |

### Metrics

| Metric | Before | After |
|--------|--------|-------|
| Test suite | 15,737 | 15,772 (+35) |
| Events | 49 | 51 (+2) |
| Concerns | 68 | 69 (+1) |
| Types | 90 | 94 (+4) |

---
## Phase O: Orchestration Research & Token Efficiency (NEXT)

**Goal:** Research and document the latest February 2026 patterns for internal orchestration, then implement token-efficient single-model optimizations as the foundation before enhancing with multi-model capabilities.

**Critical Design Principle:** Single-model efficiency is the sensible default. Multi-model routing is an optional enhancement.

### Research Findings (February 2026)

**Key Discoveries from 4 parallel research agents:**

1. **Hybrid Cascading Dominates 2026:**
   - Hybrid single/multi-agent systems improve accuracy 1.1-12% while reducing costs 20% ([arXiv 2505.18286](https://arxiv.org/abs/2505.18286))
   - Plan-and-Execute pattern: large model plans, small model executes = 90% cost reduction
   - "Efficient Agents" retains 96.7% performance with 28.4% cost improvement ([arXiv 2508.02694](https://arxiv.org/abs/2508.02694))

2. **Token Efficiency Techniques:**
   - ACON context compression: 26-54% memory reduction, 95%+ accuracy ([arXiv 2510.00615](https://arxiv.org/abs/2510.00615))
   - LLMLingua prompt compression: up to 20x compression preserving capability
   - Prompt caching: 41-80% API cost reduction, 13-31% TTFT improvement
   - Trajectory reduction: 36.9% token reduction maintaining accuracy

3. **Confidence Calibration:**
   - Semantic Entropy for uncertainty: SE(x) = -(1/|C|) Σ log p(Ci|x)
   - Semantic Entropy Probes (SEPs): "almost zero" overhead from hidden states
   - RouteLLM: 85% cost reduction, 95% GPT-4 performance via matrix factorization routing

4. **Tool Calling Optimization:**
   - PALADIN recovery: 89.68% recovery rate vs 32.76% baseline (+57%)
   - Recovery actions: retry, reformat, switch tools, terminate
   - Parallel execution: 4x latency reduction (4 calls in parallel = 300ms vs 1.2s)
   - SpecCache: 58x cache hit improvement, 3.2x overhead reduction

5. **Planning Efficiency:**
   - Pre-Act: 70-102% improvement in action accuracy over ReAct
   - GoalAct: 12.22% success rate improvement via hierarchical execution
   - Agentic plan caching: 76% cost reduction with 0.61% accuracy drop
   - Dynamic turn budgets: start low, extend adaptively for harder tasks

### Implementation Waves

**Wave O.1: Single-Model Token Efficiency** (Foundation)

| Deliverable | Technique | Expected Impact |
|-------------|-----------|-----------------|
| Context compression | ACON-style compression for older steps | 26-54% memory reduction |
| Tool schema caching | Cache compiled tool definitions | Reduce prompt tokens |
| Prompt structure optimization | Cache-friendly static/dynamic separation | 41-80% cache hits |
| Trajectory reduction | Remove redundant/expired observations | 36.9% token reduction |

**New Concerns:**
- `Concerns::Compression::Trajectory` — prune older observations
- `Concerns::Caching::ToolSchema` — cache tool definitions per session
- `Concerns::Formatting::CacheFriendly` — structure prompts for caching

**Wave O.2: Internal Decision Engine** (Intelligence)

| Deliverable | Technique | Expected Impact |
|-------------|-----------|-----------------|
| Operation classification | Deterministic vs model-needed routing | Reduce unnecessary LLM calls |
| Recovery actions | PALADIN-style retry/reformat/switch | 57% recovery improvement |
| Plan caching | Extract/reuse structured plan templates | 76% cost reduction |
| Adaptive step budget | Dynamic turn allocation by task complexity | Better cost/performance |

**New Concerns:**
- `Concerns::Routing::OperationClassifier` — route by operation type
- `Concerns::Recovery::PaladinStyle` — structured recovery actions
- `Concerns::Caching::PlanTemplate` — extract and reuse plans

**Wave O.3: Multi-Model Enhancement** (Optional)

| Deliverable | Technique | Expected Impact |
|-------------|-----------|-----------------|
| RouteLLM integration | Matrix factorization routing | 85% cost reduction |
| Semantic entropy probes | Low-overhead confidence estimation | Route by uncertainty |
| Speculative actions | Predict likely next tools in parallel | 30% speedup |
| Cascade routing | Small→large escalation on low confidence | 40% compute budget |

**Builds on Phase N:** ToolRouter, ConfidenceScorer, ModelProfiles already implemented.

**Wave O.4: Integration & Testing**

| Deliverable | Focus |
|-------------|-------|
| Token efficiency benchmark | Compare before/after on standard tasks |
| Latency measurements | End-to-end timing with/without optimizations |
| Cost tracking | Per-run token/cost accounting |
| Happy/sad path coverage | Recovery from compression, cache misses |

### Research Sources

**Token Efficiency:**
- [ACON Context Compression](https://arxiv.org/abs/2510.00615) — 26-54% memory reduction
- [LLMLingua](https://llmlingua.com/) — Up to 20x prompt compression
- [Efficient Agents](https://arxiv.org/abs/2508.02694) — 96.7% performance, 28.4% cost improvement

**Confidence & Routing:**
- [RouteLLM](https://github.com/lm-sys/RouteLLM) — 85% cost reduction, matrix factorization
- [Semantic Entropy Probes](https://arxiv.org/abs/2406.15927) — Low-overhead uncertainty
- [Cascade Routing](https://arxiv.org/pdf/2410.10347) — 8-14% improvement on RouterBench

**Tool Calling:**
- [PALADIN](https://arxiv.org/abs/2509.25238) — 89.68% recovery rate
- [Speculative Actions](https://arxiv.org/abs/2510.04371) — 30% agent speedup
- [ToolCacheAgent](https://openreview.net/pdf/05f7fe080121ee4044c4899cf9b69ac21b7738ba.pdf) — Adaptive caching

**Planning:**
- [Pre-Act](https://arxiv.org/abs/2505.09970) — 70-102% action accuracy improvement
- [GoalAct](https://arxiv.org/abs/2504.16563) — Hierarchical execution
- [Agentic Plan Caching](https://arxiv.org/abs/2506.14852) — 76% cost reduction

### Wave Execution Plan

#### Wave O.1 (2 parallel agents)

| Agent | Task | Dependencies |
|-------|------|--------------|
| A | Trajectory compression concern + tests | None |
| B | Tool schema caching + cache-friendly prompts | None |

#### Wave O.2 (3 parallel agents)

| Agent | Task | Dependencies |
|-------|------|--------------|
| A | Operation classifier (model-needed vs deterministic) | Wave O.1 |
| B | PALADIN-style recovery actions | None |
| C | Plan template caching | None |

#### Wave O.3 (2 parallel agents)

| Agent | Task | Dependencies |
|-------|------|--------------|
| A | RouteLLM-style routing integration | Phase N complete |
| B | Speculative action prediction | Wave O.2 |

#### Wave O.4 (1 agent)

| Agent | Task | Dependencies |
|-------|------|--------------|
| A | Benchmarks, testing, documentation | Waves O.1-O.3 |

---
## Phase E-2: Privacy & Polish (DEFERRED)

**Priority:** P3 (after K) | **Effort:** 3-4 weeks

- PII detection (email, phone, SSN, credit card) with `:tokenize`, `:mask`, `:remove` strategies
- Reversible tokenization, integration with agent memory and tool I/O
- YARD docs for all DSL builder methods
- Guides: multi-model, local model setup, event patterns

---
## What We're NOT Doing (Yet)

1. **Background Job Adapters** — Deferred. No production job queue integration until K.4 proves parallel execution.
2. **Metrics Adapter Layer** — Deferred until core model reliability proven via Phase J adversarial tests.
3. **Full Ractor-based Event Bus** — Current Thread::Queue approach works. Revisit only if performance issues emerge.
4. **Automatic Model Fingerprinting** — Needs data collection infrastructure. Captured in eval framework.
5. **Grammar-Constrained Decoding** — Requires model-level integration (llama.cpp grammar support). Out of scope for engine layer.
6. **Rails Integration** — Tracked separately. Engine-first, then framework adapters.
7. **RBS Type Annotations** — Large effort, YARD docs serve well, IDE support via IRB completion.
8. **Persistent Memory Storage** — Working + reflection memory sufficient. K.1 (multi-turn) is the stepping stone.
9. **Inner Thinking Loop** (L1) — Deferred. Current single-loop with optional planning/evaluation concerns is sufficient. Revisit after model testing reveals if models benefit from separate think/act phases.
10. **Sibling Agent Communication** (L7) — Deferred. Coordinator relay pattern works for current architectures.
11. **Distributed Agent Execution** — Out of scope. Single-process engine first. Remote agents are a different product.

---
## Execution Order

```
Previous Phases (A-M) ✅ COMPLETE
 ↓
N Phase: Internal Orchestration Architecture ✅ COMPLETE
 ↓
O Phase: Orchestration Research & Token Efficiency ← CURRENT
 ↓
Model Testing (with adversarial mocks as regression baseline)
 ↓
E-2 Privacy & Polish
```

---
## Success Metrics

| Metric | Phase K | Phase M | Phase N | Current |
|--------|---------|---------|---------|---------|
| Test suite | 15,608 | 15,737 | 15,772 | 15,772 |
| Suite speed | ~6s | ~6s | ~6s | ~6s |
| Events | 46 | 49 | 51 | 51 |
| Concerns | 67 | 68 | 69 | 69 |
| Types | 90 | 90 | 94 | 94 |
| RuboCop | 0 | 0 | 0 | 0 |

---
## Quick Reference

```bash
rake spec          # Run tests (~7s parallel)
rake spec_fast     # Skip slow/integration
rake ci            # Full CI (rubocop + tests + yard:doctest)
rake commit_prep   # Fix + Stage + Verify
```

**Key Docs:**
- `PLAN.md` — This file. Architecture decisions and implementation phases.
- `AGENTS.md` — Contributor guidance, code style, workflow.
- `spec/CLAUDE.md` — Testing conventions, timing rules, adversarial patterns.
- `docs/references/llama_cpp_api.md` — llama.cpp OpenAI-compatible API
- `docs/references/lm_studio_api.md` — LM Studio local server API
- `docs/RUBY4_REVIEW.md` — Ruby 4.0 codebase review findings

---
*Updated: 2026-02-08*
*Version: 9.0 (Internal Orchestration Architecture)*
