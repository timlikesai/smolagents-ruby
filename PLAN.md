# smolagents-ruby Implementation Plan

**Branch:** feature/tool-future-lazy-eval
**Updated:** 2026-02-07
**Version:** 6.0 (Post-Shakedown)

---
## Executive Summary

**Core Insight**: "Help the model by giving it less to think about, not more."

**Vision**: An engine for people to build their own Claude Code — the core agent runtime provides the thinking, tool calling, error recovery, and coordination. Everything else is UI.

**Current Priority**: Phases H+I complete. Full codebase shakedown (Opus 4.6, 6-agent parallel review) identified critical failure states and structural gaps. Phase J (Adversarial Testing & Failure Hardening) is next — harden the sad paths before real model testing.

---
## Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| Event System | ✅ Solid | 44 events, 17 categories, 11 user-tier, 33 internal-tier. StepCompleted now includes token_usage + context_usage_percent. Gaps: no correlation IDs. |
| Execution Model | ✅ Excellent | Ractor-based lazy futures, wave resolution. Parse retry gives one free retry on format drift. Gaps: no memory limit in Ractor. |
| Tool System | ✅ Good | Schema validation, retry, timeout, "Did You Mean?" |
| Builder DSL | ✅ Excellent | Three-tier (Simple/Builder/Advanced) + MoA, 34 builder methods |
| Model Integration | ✅ Validated | Server capability detection tested with real LM Studio/llama.cpp |
| Resilience | ✅ Complete | Retry (exp backoff), circuit breaker, rate limiting, failover, health checks. Cascading failures tested. Gaps: no circular fallback chain detection. |
| Memory System | ✅ Complete | Working memory, reflection memory (LRU), budget strategies. Gaps: no context compression, no multi-turn conversation support. |
| Multi-Agent | ✅ Complete | Spawn, delegate, team builder, wave scheduling. Spawn execution tested. Gaps: no cancellation, no parallel sub-agent execution, no sibling communication, no cost accounting across hierarchy. |
| Agent Loop | ✅ Hardened | Single ReAct loop with parse retry, completion validation (rejects nil/empty answers), optional planning/evaluation/repetition. Gaps: no inner thinking loop, no adaptive step budgeting. |
| Phase H Diagnostics | ✅ Complete | Debug mode, stats tracking, failure capture, config profiles, memory inspection |
| Phase I Prompt Formatting | ✅ Complete | YARD-style tool rendering, Ruby 4.0 identity, `it` keyword coaching, `.inspect` observations, block param hints |
| Phase J Adversarial Testing | ✅ Complete | MockModel conditional + adversarial factories, completion validation, parse retry, StepCompleted enrichment, adversarial + cascading + spawn integration tests |
| Testing | ✅ Adversarial | 15,405 deterministic tests. MockModel supports conditional responses + adversarial factories. Adversarial, cascading failure, and spawn execution integration tests. |

**Test Suite:** 15,405 examples, 0 failures, ~6s parallel
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
## Phase H: Local-GPU-Ready Enhancements ✅ (Compact)

Debug mode (`.debug`), VerboseSubscriber, AgentStats/StatsTracking, FailureCapture (bounded circular buffer), config profiles (`:local_gpu`, `:development`, `:cloud_api`), memory inspection (`memory_budget_usage`, `memory_summary`), builder pre-build validation, GPU test fixtures (`GpuFixtures.unreliable_model`, etc.), ResourceUsage type. **0 new events** — all concerns consume existing events. See git history for detailed design docs.

---
## Shakedown Findings (Opus 4.6, 2026-02-07)

Full codebase review by 6 parallel Opus 4.6 exploration agents (~475K tokens of analysis, ~280 file reads). Identified failure states, structural gaps, and testing blind spots.

### Critical Failure States (Will Break With Real Models)

| ID | Failure | Risk | Location | Status |
|----|---------|------|----------|--------|
| F1 | **No parsing retry** — each parse failure costs a full step from budget | HIGH | `concerns/execution/parse_retry.rb` | ✅ J.5 |
| F2 | **No output validation** — `validate_completion()` is a no-op stub, accepts nil/empty answers | HIGH | `concerns/agents/completion_validation.rb` | ✅ J.3 |
| F3 | **Ractor has no memory limit** — model-generated code can OOM the process | MEDIUM | `executors/ractor.rb:78-105` | Open |
| F4 | **30s timeout not interruptible** — tight CPU loops won't yield to interrupt | LOW | `execution/code_execution.rb:72` | Deferred |
| F5 | **Spawn execution untested** — config validated but actual spawn+execute+failure never tested | HIGH | `spec/integration/spawn_execution_spec.rb` | ✅ J.2.4 |
| F6 | **Cascading failures untested** — individual resilience components tested, interaction paths not | MEDIUM | `spec/integration/cascading_failure_spec.rb` | ✅ J.2.3 |
| F7 | **No circular fallback chain detection** — fallback model fails → infinite loop possible | LOW | `concerns/resilience/fallback.rb` | Deferred |

### Event System Gaps

| ID | Gap | Impact | Status |
|----|-----|--------|--------|
| E1 | Token usage not in user-tier events (`StepCompleted`, `TaskLifecycle`) | UI can't show cost | ✅ J.4 |
| E2 | No correlation IDs linking step → model call → tool execution | UI can't render causal chains | Open |
| E3 | No context window pressure event (budget tracking only injects into observations) | UI can't show "context 78% full" | ✅ J.4 |
| E4 | Sub-agent events lack hierarchy depth field | UI can't render nesting depth | Open |
| E5 | No agent_id filter on event subscriptions — must filter in handler | Performance at scale | Deferred |

### Loop & Coordination Gaps

| ID | Gap | Impact | Status |
|----|-----|--------|--------|
| L1 | **No inner thinking loop** — every step is think+act in one model call | Can't separate reasoning from execution | Deferred (K) |
| L2 | **No adaptive step budgeting** — fixed at config time | Agent can't request more steps for complex tasks | Deferred (K) |
| L3 | **No agent cancellation** — once `run()` starts, only max_steps or final_answer stops it | Users can't abort runaway agents | Open (K) |
| L4 | **No multi-turn conversation** — each `run()` is independent, no `continue()` | Can't build conversational agents | Open (K) |
| L5 | **No context compression** — older steps not summarized as context fills | Long-running agents hit context wall | Open (K) |
| L6 | **No parallel sub-agent execution** — team coordinator calls sub-agents sequentially | Can't dispatch research swarm concurrently | Deferred (K) |
| L7 | **No sibling communication** — sub-agents talk only to parent | Can't build writer+tester iteration patterns | Deferred (K) |
| L8 | **No cost accounting across hierarchy** — token limits per-agent, not per-tree | Budget overruns in agent trees | Deferred (K) |

### Testing Gaps

| ID | Gap | Severity | Status |
|----|-----|----------|--------|
| T1 | **No adversarial model tests** — all integration tests pre-script model responses | HIGH | ✅ J.2.1 |
| T2 | **MockModel can't do conditional responses** — pure FIFO, ignores input content | HIGH | ✅ J.1.1 |
| T3 | **No circular reasoning detection test** — repetition detection exists but untested in loop | MEDIUM | Open |
| T4 | **No cascading failure integration test** — tool fail → retry → circuit break → recovery | MEDIUM | ✅ J.2.3 |
| T5 | **No model format drift test** — model returns wrong format, verify graceful degradation | HIGH | ✅ J.2.1 |
| T6 | **SpyTool has no tests** — implementation exists at `testing/helpers/spy_tool.rb` | LOW | Open |
| T7 | **Shared examples too high-level** — don't test resilience, events, or error recovery contracts | MEDIUM | Open |

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
## Phase K: Engine Completeness — "Build Your Own Claude Code" (PLANNED)

**Goal:** Fill the structural gaps for the agent engine vision. After Phase J proves robustness, Phase K adds the capabilities needed for sophisticated, long-running, interactive agents.

**Priority:** P1 — after J. | **Effort:** 4-6 weeks across sub-phases.

**Vision check:** Someone using smolagents-ruby to build their own Claude Code needs:
- Multi-turn conversation (user asks follow-ups)
- Agent cancellation (user can abort a runaway agent)
- Context compression (long conversations don't hit walls)
- Parallel sub-agent dispatch (research swarm runs concurrently)
- Cost visibility and control (track spend across agent tree)
- Streaming output (token-by-token to UI)

### K.1: Multi-Turn Conversation

`agent.continue("follow-up question")` that preserves memory from previous run.

**Design sketch:**
```ruby
result1 = agent.run("Find Ruby 4.0 release notes")
result2 = agent.continue("What are the breaking changes?")  # Preserves context
result3 = agent.continue("Summarize for a blog post")       # Accumulated context
```

**Key decisions:** Memory budget across turns, when to summarize, how to handle step count reset.

### K.2: Agent Cancellation

External `agent.cancel!` that cleanly terminates the current step and returns partial results.

**Design sketch:**
```ruby
fiber = agent.run_fiber("complex research task")
Thread.new { sleep 30; agent.cancel! }  # Timeout externally

result = consume_fiber(fiber)
result.cancelled?  # => true
result.partial?    # => true
result.output      # => last known state
```

**Key decisions:** Thread safety, Ractor interruption, partial result construction.

### K.3: Context Compression

When context window approaches limits, summarize older steps.

**Design sketch:** New `ContextCompression` concern that monitors token usage and replaces older ActionStep observations with LLM-generated summaries. Triggered at configurable threshold (default: 75% context usage).

### K.4: Parallel Sub-Agent Execution

TeamBuilder supports concurrent dispatch with result aggregation.

**Design sketch:** Coordinator dispatches N sub-agents via Thread pool, aggregates results, feeds back to coordinator for synthesis. Uses existing Fiber bidirectional control for progress reporting.

### K.5: Cost Accounting Across Hierarchy

Token budgets enforced across the full agent tree, not just per-agent.

**Design sketch:** `SpawnContext` already tracks `remaining_steps`. Extend to track `remaining_tokens`. Propagate budget to children, deduct usage, fail gracefully when budget exhausted.

### K.6: Streaming Output

Token-by-token streaming from model to consumer.

**Design sketch:** Model adapters yield tokens as they arrive. Fiber mode yields partial ChatMessages. Event system emits `ModelTokenGenerated` (internal tier only — high frequency).

### Phase K Wave Structure (Preliminary)

Work is naturally parallel — each sub-phase touches different files:

| Wave | Tasks | Dependencies |
|------|-------|-------------|
| K-W1 | K.1 (multi-turn), K.2 (cancellation) in parallel | Phase J complete |
| K-W2 | K.3 (compression), K.5 (cost accounting) in parallel | K-W1 |
| K-W3 | K.4 (parallel sub-agents), K.6 (streaming) in parallel | K-W2 |
| K-W4 | Integration tests + verification | All K waves |

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
J Phase: Adversarial Testing & Failure Hardening ← CURRENT
 ↓
Model Testing (with J.1 adversarial mocks as regression baseline)
 ↓
K Phase: Engine Completeness ("Build Your Own Claude Code")
 ↓
E-2 Privacy & Polish
```

---
## Success Metrics

| Metric | Baseline (2026-02-07) | Phase J Target | Phase K Target |
|--------|----------------------|----------------|----------------|
| Test suite | 15,363 examples, 0 failures | +200-400 adversarial tests | +300-500 engine tests |
| Suite speed | ~7s parallel | ≤12s | ≤15s |
| Adversarial coverage | 0% (no adversarial tests) | 100% of F1-F6 failure states | Maintain |
| Spawn execution tests | Config only | Full spawn+execute+failure | Sub-agent cancellation |
| Event completeness | 44 events (UI gaps) | ≤45 (token usage, context pressure) | ≤48 (streaming, coordination) |
| Engine completeness | No multi-turn, no cancel, no compression | — | All K.1-K.6 delivered |
| RuboCop | 0 offenses | Maintain clean | Maintain clean |
| Architecture | 59 concerns, 86 types | +2-3 concerns | +5-8 concerns |

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
*Updated: 2026-02-07*
*Version: 6.0 (Post-Shakedown)*
