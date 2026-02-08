# smolagents-ruby Implementation Plan

**Branch:** feature/tool-future-lazy-eval
**Updated:** 2026-02-08
**Version:** 8.2 (Model Integration Resilience Complete)

---
## Executive Summary

**Core Insight**: "Help the model by giving it less to think about, not more."

**Vision**: An engine for people to build their own Claude Code — the core agent runtime provides the thinking, tool calling, error recovery, and coordination. Everything else is UI.

**Current Priority**: Phase M (Model Integration Resilience) complete. Server-type-aware resilience defaults automatically tune retry and circuit breaker behavior per server type. HTTP 5xx errors (model loading) no longer trip the circuit breaker — only infrastructure failures do. llama_cpp gets 5 retries, 10-failure circuit threshold, 60s cool-off. Next: Model Testing.

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
| Testing | ✅ Adversarial | 15,643 deterministic tests. MockModel supports conditional responses + adversarial factories. Adversarial, cascading failure, and spawn execution integration tests. |

**Test Suite:** 15,643 examples, 0 failures, ~6s parallel
**Architecture:** 68 concerns, 90 Data.define types, 49 events (50 ceiling)

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
## Phase J: Adversarial Testing & Failure Hardening

**Goal:** Make the system provably robust against real-world failure modes. Expand testing beyond happy paths while keeping the suite instant-fast (~10s). Every test must be ≤120ms (200ms for `:slow` tag).

**Why now:** The architecture is complete. 15,363 tests prove the happy path works. But when real models drive this system, they will produce malformed output, hallucinate tool names, generate infinite loops, return empty answers, and fail intermittently. If we can't verify recovery from these failures deterministically, model testing will be debugging in the dark.

**Priority:** P0 — prerequisite for model testing and initial release.

### Testing Philosophy

The test suite is our primary feedback loop. It must be:

1. **Instant-fast** (~10s total). Short iteration cycles let agents try things, see results, and adjust. This is the core advantage over slow test suites — agents can run `rake spec` dozens of times per session without losing momentum.

2. **Silent on success.** No debug output, no progress bars, no warnings. Clean output means clean context. If something appears in test logs that isn't a failure, that's a bug in our tests or our code — fix it, don't tolerate noise.

3. **Diagnostic on failure.** When tests fail, the full output must contain everything needed to diagnose: stack traces, timing, assertion context. Never pipe or filter test output — it destroys diagnostic information.

4. **Deterministic.** No randomness, no timing dependencies, no network calls. MockModel provides exact responses in exact order. Adversarial tests use pre-determined adversarial inputs, not random fuzzing.

5. **Adversarial by default.** For every feature, test: (a) the happy path, (b) the most common failure mode, (c) the recovery path. The adversarial test proves the system handles the failure; the recovery test proves it can continue after handling it.

### Architecture Rules (Same as All Phases)

| Pattern | Rule |
|---------|------|
| Types | `Data.define` in `types/`, factory `.default` method, frozen |
| Concerns | ≤100 lines, registered in `concerns/registrations/` |
| Events | Reuse existing (44/50 ceiling). Budget: +2 events max for J |
| Testing | Instant-fast (<120ms). No sleep/polling. Queue#pop for blocking |
| Non-blocking | No `sleep`, no `Timeout.timeout`. Evented wakeup patterns only |

---

### J.1: Adversarial MockModel Extensions

**Goal:** MockModel can simulate real-world model misbehavior deterministically.

#### J.1.1: Conditional Response Logic

Add `when_input_matches` to MockModel for context-aware responses:

```ruby
model = MockModel.new
model.when_input_matches(/error/) { |messages| "final_answer(answer: 'recovered')" }
model.when_input_matches(/search/) { |messages| 'search(query: "Ruby")' }
model.default_response("final_answer(answer: 'fallback')")
```

**Files:**
- `lib/smolagents/testing/mock_model/conditional.rb` (≤80 lines)
- `spec/smolagents/testing/mock_model/conditional_spec.rb`

**Design:** Conditional responses checked BEFORE queue. If no match, falls through to FIFO queue. This preserves backward compatibility — existing tests using `queue_*` methods work unchanged.

#### J.1.2: Adversarial Response Factories

Pre-built adversarial response patterns:

```ruby
# Model returns non-Ruby garbage
model.queue_malformed("Here's what I think: the answer is 42")

# Model returns code that calls nonexistent tools
model.queue_hallucinated_tool("nonexistent_tool(arg: 'value')")

# Model returns empty/nil content
model.queue_empty_response

# Model returns final_answer with nil/empty
model.queue_empty_final_answer

# Model ignores tools and just returns text
model.queue_text_only("I think the answer is 42, but I can't use any tools")
```

**Files:**
- `lib/smolagents/testing/mock_model/adversarial.rb` (≤80 lines)
- `spec/smolagents/testing/mock_model/adversarial_spec.rb`

**Design:** Factory methods that queue responses in specific adversarial formats. Each maps to a real failure mode observed in local GPU testing.

---

### J.2: Adversarial Integration Tests

**Goal:** Prove the agent loop handles real-world model failures gracefully.

#### J.2.1: Format Drift & Recovery Tests

```ruby
# spec/integration/adversarial_agent_spec.rb
describe "format drift recovery" do
  it "recovers from non-code model response" do
    model.queue_malformed("Just some text without code blocks")
    model.queue_final_answer("recovered")

    result = agent.run("task")
    expect(result).to be_success
    expect(result.output).to eq("recovered")
  end

  it "recovers from hallucinated tool names" do
    model.queue_hallucinated_tool("fake_tool(x: 1)")
    model.queue_final_answer("recovered after error")

    result = agent.run("task")
    expect(result).to be_success
    # Error feedback should have guided model to real tools
  end

  it "rejects nil final_answer" do
    model.queue_code_action("final_answer(answer: nil)")
    model.queue_final_answer("real answer")

    result = agent.run("task")
    expect(result.output).not_to be_nil
  end

  it "rejects empty final_answer" do
    model.queue_code_action('final_answer(answer: "")')
    model.queue_final_answer("real answer")

    result = agent.run("task")
    expect(result.output).not_to be_empty
  end
end
```

**Files:**
- `spec/integration/adversarial_agent_spec.rb` (~200 lines)

#### J.2.2: Repetition & Circular Reasoning Tests

```ruby
describe "repetition detection" do
  it "detects and recovers from circular tool calls" do
    3.times { model.queue_code_action('search(query: "same query")') }
    model.queue_final_answer("broke out of loop")

    result = agent.run("task", max_steps: 6)
    expect(result).to be_success
    # Repetition concern should have injected guidance
  end

  it "detects identical code execution loops" do
    3.times { model.queue_code_action("x = 1") }
    model.queue_final_answer("done")

    result = agent.run("task", max_steps: 6)
    expect(result).to be_success
  end
end
```

#### J.2.3: Cascading Failure Tests

```ruby
describe "cascading failures" do
  it "survives tool error → retry → different tool → success" do
    failing_tool = build_test_tool(name: "flaky", raises: RuntimeError.new("timeout"))
    backup_tool = build_test_tool(name: "reliable", returns: "data")

    model.queue_code_action('flaky()')
    model.queue_code_action('reliable()')  # After seeing error, tries different tool
    model.queue_final_answer("done")

    agent = build_test_agent(model:, tools: [failing_tool, backup_tool])
    result = agent.run("task")
    expect(result).to be_success
  end
end
```

#### J.2.4: Spawn Execution Tests

```ruby
describe "spawn execution" do
  it "spawns sub-agent, executes, and returns result" do
    child_model = build_mock_model(responses: ['final_answer(answer: "child result")'])
    parent_model = build_mock_model(responses: [
      'researcher(task: "find info")',
      'final_answer(answer: result)'
    ])

    agent = Smolagents.agent
      .model { parent_model }
      .managed_agent(
        Smolagents.agent.model { child_model }.tools(:search).build,
        as: "researcher"
      )
      .build

    result = agent.run("research task")
    expect(result).to be_success
  end

  it "handles sub-agent failure gracefully" do
    child_model = build_mock_model(responses: [])  # Exhausted immediately
    # ... verify parent receives error and can recover
  end
end
```

**Files:**
- `spec/integration/spawn_execution_spec.rb` (~150 lines)

---

### J.3: Default Completion Validation

**Goal:** Reject obviously invalid final answers by default.

**Files:**
- `lib/smolagents/concerns/agents/react_loop/completion.rb` (modify `validate_completion`)
- `spec/smolagents/concerns/agents/react_loop/completion_spec.rb`

**Design:** Make `validate_completion` reject nil and empty string answers by default:

```ruby
def validate_completion(step, _task, memory:)
  output = step.action_output
  return true if output.is_a?(String) && !output.strip.empty?
  return true if output && !output.is_a?(String)  # Non-string outputs (Hash, Array, Integer) are valid

  step.error = "[HINT: final_answer received empty/nil. Provide a substantive answer.]"
  step.observations = step.error
  false  # Reject — loop continues, model sees hint
end
```

This is a ~10-line change that prevents the most common local GPU failure mode. The agent gets one more chance to provide a real answer instead of silently succeeding with nothing.

---

### J.4: Event System Hardening

**Goal:** Fill the gaps identified in shakedown for UI builders.

#### J.4.1: Token Usage in User-Tier Events

Add `token_usage` field to `StepCompleted` event. Currently internal-only.

**Files:**
- `lib/smolagents/events.rb` (modify StepCompleted definition)
- `lib/smolagents/concerns/agents/react_loop/execution/monitoring.rb` (populate field)
- Spec updates

**Budget:** 0 new events. Modifies existing StepCompleted.

#### J.4.2: Context Pressure Event

Add context pressure percentage to existing `TaskLifecycle` event as optional field, or emit via existing `StepCompleted`:

```ruby
# Option A: Add context_usage_percent field to StepCompleted
# Option B: New ContextPressure event (costs 1 from budget)
```

Prefer Option A (0 event cost). Decision at implementation time.

**Files:**
- `lib/smolagents/events.rb` (add field)
- `lib/smolagents/concerns/execution/budget_tracking.rb` (emit data)
- Spec updates

---

### J.5: Loop Hardening

#### J.5.1: Parsing Retry Budget

Add a small inner retry for parse failures that doesn't consume a full step:

```ruby
# In step execution, before counting as a full step:
MAX_PARSE_RETRIES = 1

def execute_with_parse_retry(action_step)
  result = generate_and_parse(action_step)
  return result unless result.parse_failure? && @parse_retries < MAX_PARSE_RETRIES

  @parse_retries += 1
  action_step.observations = "[Parse error: not valid Ruby. Try again with a ```ruby code block.]"
  generate_and_parse(action_step)  # One free retry
end
```

This gives the model ONE free retry on parse failures without burning a step. Conservative — just 1 retry, with a clear hint about what went wrong.

**Files:**
- `lib/smolagents/concerns/execution/code_execution.rb` (modify, ~10 lines)
- Spec additions

---

### Phase J Wave Execution Plan

#### Wave J1: MockModel Extensions (2 parallel agents)

| Agent | Task | Files Created | Dependencies |
|-------|------|--------------|-------------|
| A | J.1.1: Conditional response logic | `testing/mock_model/conditional.rb`, spec | None |
| B | J.1.2: Adversarial response factories | `testing/mock_model/adversarial.rb`, spec | None |

#### Wave J2: Core Hardening (3 parallel agents)

| Agent | Task | Files | Dependencies |
|-------|------|-------|-------------|
| A | J.3: Default completion validation | `concerns/agents/react_loop/completion.rb` (modify), spec | None |
| B | J.4.1 + J.4.2: Event token usage + context pressure | `events.rb`, `monitoring.rb`, `budget_tracking.rb`, specs | None |
| C | J.5.1: Parsing retry budget | `concerns/execution/code_execution.rb` (modify), spec | None |

#### Wave J3: Adversarial Integration Tests (3 parallel agents)

| Agent | Task | Files Created | Dependencies |
|-------|------|--------------|-------------|
| A | J.2.1 + J.2.2: Format drift + repetition tests | `spec/integration/adversarial_agent_spec.rb` | Wave J1 (adversarial factories) |
| B | J.2.3: Cascading failure tests | `spec/integration/cascading_failure_spec.rb` | Wave J2 (completion validation) |
| C | J.2.4: Spawn execution tests | `spec/integration/spawn_execution_spec.rb` | None |

#### Wave J4: Verification (1 agent)

| Agent | Task | Depends On |
|-------|------|-----------|
| A | `rake ci`, verify all tests pass, verify test count growth, update PLAN.md | All J waves |

### Phase J Dependency Graph

```
Wave J1 (test infra)     Wave J2 (hardening)      Wave J3 (integration tests)    Wave J4
────────────────         ────────────────         ─────────────────────────      ────────
Conditional mock ──────────────────────────────→ Adversarial agent tests ──┐
Adversarial factories ─────────────────────────→ Adversarial agent tests  ├──→ rake ci
                         Completion validation ──→ Cascading failure tests ┤
                         Event hardening          Spawn execution tests ───┘
                         Parse retry budget
```

### Phase J Event Budget

+0 to +1 new events (context pressure, if Option B chosen). Target: ≤45 events total.

### Phase J Test Budget

Target: +200-400 new test examples. Suite must remain ≤12s total. All new tests ≤120ms each.

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
## Phase L: Pre-Model Hardening

**Goal:** Close every remaining structural gap that would cause failures with real models. After this phase, the engine has complete event coverage, timeout safety at every model call site, and resilience wired into the default runtime. Model testing becomes debugging model behavior, not debugging the engine.

**Why now:** The Opus 4.6 six-agent shakedown (2026-02-08) validated that all 48 events are emitted, all concerns compose correctly, and the ReAct loop handles adversarial inputs. But three categories of gap remain: (1) model.generate() has no timeout protection at 10+ call sites, (2) parse retry emits no event for UI visibility, (3) resilience concerns exist but aren't wired into the default agent. These are the gaps that will cause silent failures with real models.

**Priority:** P0 — prerequisite for model testing.

### Architecture Rules (Same as All Phases)

| Pattern | Rule |
|---------|------|
| Types | `Data.define` in `types/`, factory `.default` method, frozen |
| Concerns | ≤100 lines, registered in `concerns/registrations/` |
| Events | Reuse existing (48/50 ceiling). Budget: +1 event max for L (ParseRetryAttempted) |
| Testing | Instant-fast (<120ms). No sleep/polling. Queue#pop for blocking |
| Non-blocking | No `sleep`, no `Timeout.timeout`. Evented wakeup patterns only |

### Shakedown Findings (Second Review, 2026-02-08)

Six parallel Opus 4.6 exploration agents reviewed: looping constructs, sub-agent coordination, eventing completeness, error handling, test coverage, and builder DSL. Key validated findings:

**Verified complete (no action needed):**
- All 48 events ARE emitted at their intended sites (Haiku agents falsely flagged ~10 as missing)
- ReAct loop has proper fiber-based bidirectional control (Fiber.yield + control requests)
- Sub-agent coordination supports parent→child (SpawnAgentTool), static delegation (ManagedAgentTool), and team patterns (TeamBuilder with parallel/sequential stages)
- Completion validation rejects nil/empty answers (J.3)
- Cancellation checked at step boundaries (K.2)
- Token budget enforced at step boundaries (Post-K)
- Context compression triggers before generation (K.3)

**Gaps requiring action (documented below as L.1–L.5):**

| ID | Gap | Status | Resolution |
|----|-----|--------|------------|
| L.1 | `model.generate()` unwrapped at 10+ call sites — no timeout | ✅ DONE | GenerationTimeout concern wraps 9 active call sites via `with_generation_timeout`. Queue#pop(timeout:) pattern, worker thread, no sleep. |
| L.2 | Parse retry emits no event — UI has no visibility into retry attempts | ✅ DONE | ParseRetryAttempted event (user-tier) emitted on every retry. Default retries increased from 1 to 2. |
| L.3 | Resilience concerns NOT in default AgentRuntime | ✅ N/A | RetryExecution is model-level (wraps model.generate). Available via `.with_retry()` on model builder. Agent-level has GenerationTimeout + ParseRetry. |
| L.4 | No compound integration tests | ✅ DONE | 6 compound tests: timeout passthrough, multi-step with timeout, parse retry events, multi-retry recovery, timeout firing. |
| L.5 | Builder has no `validate_required!` on `build()` | ✅ N/A | Already implemented in `resolve_model()` (model_concern.rb:114). Checks both `model_pool_config` and `model_block`. |

---

### L.1: Model Generation Timeout (Evented, Non-Blocking)

**Problem:** `@model.generate(messages)` is called at 10+ sites with no timeout wrapper. A hung model (common with local GPU inference) blocks the agent forever. No event is emitted, no error is raised, the user sees nothing.

**Call sites identified:**
- `code_generation.rb:30` — main step generation (most critical)
- `planning.rb:74,88` — initial plan + plan update
- `evaluation.rb:46` — step evaluation
- `self_refine/prompts.rb:31,77` — self-critique + refinement
- `mixed_refinement.rb:91,104` — feedback + correction
- `observation_router/summarizer.rb:19` — observation summarization
- `native_tool_execution.rb:42` — native tool calling
- `streaming.rb:41,51` — streaming generation

**Design: GenerationTimeout concern (evented, non-blocking)**

The timeout MUST NOT use `Timeout.timeout` (it's unsafe, uses Thread#raise). Instead, use a dedicated watchdog thread with Queue-based evented wakeup:

```ruby
module GenerationTimeout
  DEFAULT_GENERATION_TIMEOUT = 120 # seconds

  private

  def initialize_generation_timeout(timeout: DEFAULT_GENERATION_TIMEOUT)
    @generation_timeout = timeout
  end

  # Wrap a model.generate call with evented timeout.
  # Uses a watcher thread + Queue for instant wakeup (no polling).
  #
  # @param context [Symbol] Call site identifier for event emission
  # @yield The model.generate call
  # @return [Object] Generation result
  # @raise [GenerationTimeoutError] If generation exceeds timeout
  def with_generation_timeout(context: :step, &block)
    return yield unless @generation_timeout&.positive?

    done_queue = Queue.new
    result = nil
    error = nil

    worker = Thread.new do
      result = yield
    rescue StandardError => e
      error = e
    ensure
      done_queue.push(:done) # Instant wakeup, no polling
    end

    # Block on queue with timeout — NOT sleep, NOT polling
    signal = done_queue.pop(timeout: @generation_timeout)

    if signal
      worker.join # Already finished, instant
      raise error if error
      result
    else
      worker.kill # Timeout expired
      emit :error_occurred, error_class: "GenerationTimeoutError",
           error_message: "Model generation timed out after #{@generation_timeout}s",
           context: { call_site: context }, recoverable: true
      raise GenerationTimeoutError.new(context, @generation_timeout)
    end
  end
end
```

**Key design decisions:**
1. `Queue#pop(timeout:)` — Ruby 4.0's built-in timeout on Queue, no external Timeout needed
2. Worker thread runs the generation — if it finishes, pushes to queue for instant wakeup
3. If timeout expires, `Queue#pop` returns nil, worker is killed, event is emitted
4. `GenerationTimeoutError` is a typed error that the agent loop can handle (not raw RuntimeError)
5. Context parameter identifies which call site timed out (for debugging)

**Integration:** Each call site wraps its `@model.generate()`:

```ruby
# Before:
response = @model.generate(messages, stop_sequences: nil)

# After:
response = with_generation_timeout(context: :step) {
  @model.generate(messages, stop_sequences: nil)
}
```

**Testing:** Use MockModel with a `queue_slow_response` factory that sleeps in a thread (testing only, not production code). Test verifies timeout fires within 120ms threshold.

```ruby
# MockModel addition for testing timeouts
def queue_slow_response(duration_ms:)
  queue_response_proc { Thread.new { sleep(duration_ms / 1000.0) }.join; "result" }
end
```

Wait — we cannot use sleep in tests. The test must be instant-fast. The correct pattern:

```ruby
# MockModel: blocks on a Queue until test releases it
def queue_blocking_response
  gate = Queue.new
  queue_response_proc { gate.pop; "result" }
  gate # Return gate so test can control timing
end
```

Test:
```ruby
it "emits error and raises on timeout", :slow do
  gate = model.queue_blocking_response
  agent = build_agent(model:, generation_timeout: 0.01) # 10ms timeout

  expect { agent.run("task") }.to raise_error(GenerationTimeoutError)
  gate.push(:release) # Clean up blocked thread
end
```

**Files:**
- `lib/smolagents/concerns/execution/generation_timeout.rb` (≤60 lines)
- `lib/smolagents/types/generation_timeout_error.rb` (≤10 lines)
- `spec/smolagents/concerns/execution/generation_timeout_spec.rb`
- Modify 10+ call sites to wrap with `with_generation_timeout`

**Event budget:** 0 new events — reuses existing `:error_occurred` with context.

**Config threading:** Builder `.generation_timeout(seconds)` → AgentConfig → AgentRuntime → concern initialization. Follow `token_budget` pattern.

---

### L.2: Parse Retry Event Emission

**Problem:** `ParseRetry#can_retry_parse?` (parse_retry.rb:33-43) increments the counter and sets observations, but emits NO event. UI builders have no visibility into parse retry attempts. This is the only concern that modifies agent behavior without emitting an event.

**Design:** Emit event from `can_retry_parse?` when a retry is consumed:

```ruby
def can_retry_parse?(action_step, result)
  @parse_retries ||= 0
  max = @parse_max_retries || DEFAULT_MAX_RETRIES
  return false if @parse_retries >= max
  return false unless retryable_parse_failure?(result)

  @parse_retries += 1
  action_step.error = nil
  action_step.observations = "[Parse error: #{result.message}. Respond with a ```ruby code block.]"

  # NEW: Emit event for UI visibility
  emit :parse_retry_attempted,
       retry_number: @parse_retries,
       max_retries: max,
       reason: result.reason,
       message: result.message
  true
end
```

**New event: ParseRetryAttempted**

```ruby
define_event :ParseRetryAttempted,
             fields: %i[retry_number max_retries reason message],
             category: :execution,
             tier: :user,
             description: "Model output failed to parse, retrying with guidance"
```

This is a user-tier event because format drift is something users need to know about — it indicates the model is struggling with the code format.

**Files:**
- `lib/smolagents/events.rb` (add ParseRetryAttempted definition)
- `lib/smolagents/concerns/execution/parse_retry.rb` (add emit call)
- `spec/smolagents/concerns/execution/parse_retry_spec.rb` (verify emission)
- `spec/smolagents/events/registry_spec.rb` (add to registry expectations)
- `spec/smolagents/events/emitter_consumer_spec.rb` (add to emission tests)

**Event budget:** +1 event (48→49, under 50 ceiling).

**Also:** Increase default `DEFAULT_MAX_RETRIES` from 1 to 2. One retry is too conservative for local GPU models that frequently drift. Two retries gives the model a real chance to self-correct while keeping step budgets tight. The builder override `.parse_max_retries(n)` remains for custom configuration.

---

### L.3: Default Resilience Wiring

**Problem:** The resilience concerns (RetryExecution, CircuitBreaker, RateLimiter, Fallback, FailureClassification) exist and are tested individually, but are NOT included in the default `AgentRuntime`. Users who don't explicitly wire them via builder get NO model-call resilience. A single API timeout or 429 error kills the agent run.

**Current AgentRuntime includes (verified at runtime.rb:44-66):**
- ReActLoop, Control, Repetition, Evaluation, SelfRefine
- StepExecution, Planning, StepContext, GoalTracking, WorkingMemory
- ContextOrchestration, ObservationRouter, CompletionValidation
- CodeExecution, NativeToolExecution, GoalDrivenLoop
- EarlyYield, GoalAwareYield, MultiTurn, Cancellation, CostAccounting

**NOT included:** CircuitBreaker, RetryExecution, RateLimiter, Fallback, FailureClassification, ToolIsolation

**Design: Wire basic retry into default runtime**

Add `RetryExecution` to default AgentRuntime includes. This gives every agent automatic retry with exponential backoff on transient model failures (HTTP 429, 500, 502, 503, timeout). Other resilience concerns (circuit breaker, rate limiter) remain opt-in — they require configuration that varies by deployment.

**Why only retry:** Retry is universally useful and safe with sensible defaults (3 attempts, exponential backoff starting at 1s). Circuit breaker needs threshold tuning. Rate limiter needs per-provider limits. Fallback needs a secondary model. These require explicit user decisions.

**Builder integration:** The retry concern should initialize with sensible defaults when included in AgentRuntime, and be overridable via `.with_retry(max_attempts: 5, backoff: :linear)` on the model builder (already exists) or via agent-level retry configuration.

**Files:**
- `lib/smolagents/agents/runtime.rb` (add `include RetryExecution` — verify concern compatibility)
- `spec/smolagents/agents/runtime_spec.rb` (verify retry is active by default)
- `spec/integration/default_resilience_spec.rb` (integration test: transient failure → retry → success)

**Important:** Before adding the include, verify RetryExecution doesn't conflict with existing concerns. Check method name collisions, initialization requirements, and event emissions. RetryExecution wraps `model.generate()` — ensure it composes with GenerationTimeout (L.1) correctly: timeout should be per-attempt, retry should wrap the timeout.

**Composition order:** `retry { with_generation_timeout { model.generate() } }` — each retry attempt gets its own timeout. If a single attempt times out, retry kicks in. If all retries timeout, the error propagates.

---

### L.4: Complex Deterministic Integration Tests

**Problem:** Post-K added 6 integration tests for common workflows, but no test exercises the full engine with nested spawn + cancellation + compression + token budget in combination. These interaction paths could have subtle bugs.

**Design:** Add focused integration tests for compound scenarios:

```ruby
# spec/integration/compound_workflow_spec.rb

describe "compound engine workflows", type: :integration do
  it "parent spawns child, child uses multiple steps, parent compresses and completes" do
    # 8-step parent + 3-step child
    # After child completes, parent memory exceeds 75% → compression triggers
    # Parent continues with compressed context
  end

  it "cancellation during sub-agent execution propagates cleanly" do
    # Parent spawns child, cancellation fires mid-child-step
    # Both parent and child emit proper lifecycle events
    # Result is RunResult.cancelled
  end

  it "token budget exhaustion in child propagates to parent" do
    # Child hits token budget → emits TokenBudgetExhausted
    # Parent receives error, can recover or propagate
  end

  it "parse retry + completion validation + planning in single run" do
    # Step 1: model returns malformed → parse retry fires (emits ParseRetryAttempted)
    # Step 2: model returns nil final_answer → completion validation rejects
    # Step 3: planning update fires (step 3 planning interval)
    # Step 4: model returns valid final_answer → success
  end

  it "multi-turn with compression across turns" do
    # Turn 1: 5 steps, memory fills to 80%
    # Turn 2: compression triggers, 3 more steps
    # Verify context continuity across compression + turn boundary
  end

  it "streaming generation with timeout protection" do
    # Model streams tokens, then hangs mid-stream
    # GenerationTimeout fires, proper cleanup
    # Verify ModelTokenGenerated events emitted before timeout
  end
end
```

**Files:**
- `spec/integration/compound_workflow_spec.rb` (~250 lines)

**Testing pattern:** All tests use MockModel with pre-scripted responses. No sleep, no real timeouts. For timeout tests, use `queue_blocking_response` + short timeout (10ms) to verify the timeout path without waiting.

---

### L.5: Builder Validation

**Problem:** `AgentBuilder#build()` doesn't validate that required configuration (model) is present. Missing model produces a confusing `NoMethodError: undefined method 'generate' for nil` deep in the ReAct loop instead of a clear error at build time.

**Design:** Add `validate_required!` to build():

```ruby
def build
  validate_required!
  # ... existing build logic
end

private

def validate_required!
  raise ArgumentError, "Model is required. Use .model { MyModel.new } to set it." unless @config[:model]
end
```

**Files:**
- `lib/smolagents/builders/agent_builder.rb` (add validation, ~5 lines)
- `spec/smolagents/builders/agent_builder_spec.rb` (verify error message)

---

### Phase L Wave Execution Plan

#### Wave L1: Core Infrastructure (2 parallel agents)

| Agent | Task | Files | Dependencies |
|-------|------|-------|-------------|
| A | L.1: GenerationTimeout concern + error type + config threading | `concerns/execution/generation_timeout.rb`, `types/generation_timeout_error.rb`, modify `agent_builder.rb`, `agent_config.rb`, `runtime.rb`, spec | None |
| B | L.2: ParseRetryAttempted event + emission + increase default retries | `events.rb`, `parse_retry.rb`, specs (registry, emitter_consumer, parse_retry) | None |

#### Wave L2: Wiring + Validation (2 parallel agents)

| Agent | Task | Files | Dependencies |
|-------|------|-------|-------------|
| A | L.3: Wire RetryExecution into default AgentRuntime + verify composition with L.1 | `runtime.rb`, `runtime_spec.rb`, `default_resilience_spec.rb` | Wave L1 (timeout must exist for composition) |
| B | L.5: Builder validate_required! | `agent_builder.rb`, `agent_builder_spec.rb` | None |

#### Wave L3: Timeout Integration (1 agent)

| Agent | Task | Files | Dependencies |
|-------|------|-------|-------------|
| A | L.1 continued: Wrap all 10+ model.generate() call sites with `with_generation_timeout` | Modify `code_generation.rb`, `planning.rb`, `evaluation.rb`, `self_refine/prompts.rb`, `mixed_refinement.rb`, `observation_router/summarizer.rb`, `native_tool_execution.rb`, `streaming.rb` | Wave L1 (concern must exist) |

#### Wave L4: Compound Tests + Verification (2 parallel agents)

| Agent | Task | Files | Dependencies |
|-------|------|-------|-------------|
| A | L.4: Compound integration tests | `spec/integration/compound_workflow_spec.rb` | Waves L1-L3 |
| B | `rake ci`, verify all tests pass, verify test count growth, update metrics | — | All L waves |

### Phase L Dependency Graph

```
Wave L1 (infrastructure)        Wave L2 (wiring)           Wave L3 (integration)     Wave L4
────────────────────           ─────────────────           ─────────────────────     ─────────
GenerationTimeout concern ───→ Wire retry+timeout ──────→ Wrap all call sites ──┐
ParseRetryAttempted event       Builder validation                               ├──→ rake ci
                                                                                 │
                                                          Compound tests ────────┘
```

### Phase L Event Budget

+1 new event (ParseRetryAttempted). 48→49 total (under 50 ceiling).

### Phase L Test Budget

Target: +100-200 new test examples. Suite must remain ≤12s total. All new tests ≤120ms each (200ms for `:slow` tagged timeout tests).

### Phase L Metrics Targets

| Metric | Current | Target |
|--------|---------|--------|
| Test suite | 15,620 | ~15,800 |
| Suite speed | ~6s | ≤12s |
| Events | 48 | 49 |
| Concerns | 67 | 68 (+GenerationTimeout) |
| Types | 90 | 91 (+GenerationTimeoutError) |
| RuboCop | 0 offenses | 0 offenses |

---
## Phase M: Model Integration Resilience ✅ COMPLETE

**Goal:** Make the gem gracefully handle model loading/swapping on local servers (llama.cpp, LM Studio) without user intervention. Server-type-aware resilience should be automatic.

**Root cause:** During live model testing, HTTP 500 errors from model swapping tripped the circuit breaker after 3 failures (9 total HTTP requests with retries, ~9 seconds), blocking ALL subsequent requests for 30 seconds. The gem was unusable for anyone running local models with model swapping.

**Key insight:** `Faraday::TimeoutError` inherits from `Faraday::ServerError` — a blanket class check would inadvertently make timeouts non-circuit. Solution: check `response_status` to distinguish transient 5xx (model loading, has status code) from infrastructure failure (timeout, nil status).

### M.1: Server Error Non-Circuit Classification ✅

- Added `ServiceUnavailableError` to `NON_CIRCUIT_ERRORS`
- Added `transient_server_error?` method: `Faraday::ServerError` with 5xx `response_status` is non-circuit
- `Faraday::TimeoutError` (nil response_status) still trips circuit correctly

### M.2: Server-Type Resilience Defaults ✅

- **M.2a:** Added `resilience_defaults` field to `ServerType = Data.define(:name, :base_capabilities, :resilience_defaults)`
  - llama_cpp: `{ retry: { max_attempts: 5, base_interval: 2.0, max_interval: 60.0 }, circuit_breaker: { threshold: 10, cool_off: 60 } }`
  - All others: `{}` (gem defaults)
- **M.2b:** Added `circuit_threshold:` and `circuit_cool_off:` kwargs to `ApiClient#api_call`
- **M.2c:** OpenAIModel reads server-type defaults via `build_server_type_retry_policy` and `server_type_circuit_config`

### M.3: Tests ✅

8 new tests covering circuit breaker non-circuit errors, ServerType resilience_defaults, OpenAIModel retry policy, and integration (500 sequence with circuit staying closed).

### Files Modified

| File | Change |
|------|--------|
| `lib/smolagents/concerns/resilience/circuit_breaker.rb` | `ServiceUnavailableError` in NON_CIRCUIT_ERRORS, `transient_server_error?` |
| `lib/smolagents/types/server_capability.rb` | `resilience_defaults` field on ServerType, llama_cpp config |
| `lib/smolagents/concerns/api/client.rb` | `circuit_threshold:`, `circuit_cool_off:` kwargs |
| `lib/smolagents/models/openai_model.rb` | Server-type retry policy + circuit config helpers |
| 3 spec files | 8 new tests |

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
G.6 Event System Solidification ✅ COMPLETE
 ↓
H Phase: Local-GPU-Ready Enhancements ✅ COMPLETE
 ↓
I Phase: Ruby-Native Prompt Formatting ✅ COMPLETE
 ↓
J Phase: Adversarial Testing & Failure Hardening ✅ COMPLETE
 ↓
K Phase: Engine Completeness ("Build Your Own Claude Code") ✅ COMPLETE
 ↓
Post-K Hardening (event wiring, config threading, safety) ✅ COMPLETE
 ↓
L Phase: Pre-Model Hardening ← CURRENT
 ↓
Model Testing (with J.1 adversarial mocks as regression baseline)
 ↓
E-2 Privacy & Polish
```

---
## Success Metrics

| Metric | Baseline | Phase J | Phase K | Post-K | Phase L |
|--------|----------|---------|---------|--------|---------|
| Test suite | 15,363 | 15,405 (+42) | 15,608 (+203) | 15,620 (+12) | 15,635 (+15) |
| Suite speed | ~7s | ~6s | ~6s | ~6s | ~6s |
| Events | 44 | 44 | 46 (+2) | 48 (+2) | 49 (+1) |
| Concerns | 59 | 59 | 67 (+8) | 67 | 68 (+1) |
| Types | 86 | 86 | 90 (+4) | 90 | 90 |
| Shakedown gaps (S2) | 5 | — | — | — | 0 |
| RuboCop | 0 offenses | 0 offenses | 0 offenses | 0 offenses | 0 offenses |

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
*Version: 8.0 (Pre-Model Hardening)*
