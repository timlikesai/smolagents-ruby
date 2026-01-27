# smolagents-ruby Implementation Plan

**Branch:** feature/tool-future-lazy-eval
**Updated:** 2026-01-26
**Version:** 2.3 (Phase C Complete)

---

## Executive Summary

This plan synthesizes findings from Sonnet's Flux Design, consolidated research (70+ ideas), and gap analysis.

**Core Insight**: "Help the model by giving it less to think about, not more."

---

## Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| Event System | ✅ Excellent | 75+ event types, EventStore with replay |
| Execution Model | ✅ Excellent | Ractor-based lazy futures, wave resolution |
| Tool System | ✅ Good | Schema validation, retry, timeout, "Did You Mean?" |
| Builder DSL | ✅ Good | Three-tier (Simple/Builder/Advanced) |
| Model Integration | ✅ Good | Multi-model, retry, circuit breaker |
| Small Model Support | ✅ Good | Progressive disclosure, Chain of Draft, context signals |
| Observability | ✅ Good | EventStore, query, snapshots, JSONL persistence |
| Self-Healing | ✅ Good | Circuit breaker, loop detection, failure classification |
| Documentation | ⚠️ Partial | YARD, guides needed |

**Test Suite:** 15,046 examples, 95.7% coverage, ~5s parallel

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

---

## Phase D: Strategic Features

### 2.2 Checkpoint/Rollback Mechanism
**Impact:** Enables partial replay and recovery
**Effort:** 1 week
**Blocked by:** ✅ Event Sourcing (done)

```ruby
class ExecutionCheckpoint
  def self.capture(agent, step)
    new(
      step_number: step.step_number,
      memory_snapshot: agent.memory.to_snapshot,
      state_snapshot: agent.state.dup,
      timestamp: Time.now
    )
  end

  def restore_to(agent)
    agent.memory.restore_from(memory_snapshot)
    agent.state.merge!(state_snapshot)
  end
end
```

---

### 3.1 Time-Travel Debugging Console
**Impact:** Revolutionary debugging experience
**Effort:** 2-3 weeks
**Blocked by:** Checkpointing (2.2)

```ruby
class TimeTravel
  def initialize(event_store)
    @store = event_store
  end

  def goto(step:)
    @store.state_at(sequence: step_to_sequence(step))
  end

  def counterfactual(at_step:, with_action:)
    state = goto(step: at_step - 1)
    simulate_from(state, with_action)
  end

  def flame_graph
    @store.events.group_by(&:category).transform_values do |events|
      events.map { |e| { name: e.type, duration_ms: e.duration_ms } }
    end
  end
end
```

---

### 3.2 Semantic Circuit Breaker
**Impact:** Catches semantic failures, not just technical ones
**Effort:** 1 week
**Blocked by:** ✅ Failure Classification (done)

```ruby
module Concerns::Resilience::SemanticCircuitBreaker
  SEMANTIC_FAILURES = %i[
    incoherent_response irrelevant_answer loop_detected
    confidence_decay goal_drift
  ]

  def check_semantic_health(response, context)
    issues = []
    issues << :incoherent_response unless parseable?(response)
    issues << :goal_drift if goal_alignment_score(response, context) < 0.5

    trip_semantic_breaker(issues) if issues.any?
  end
end
```

---

### 3.3 Mixture-of-Agents (MoA) Pattern
**Impact:** Small model ensembles matching large models
**Effort:** 2 weeks

Research shows MoA achieves 65.8% win rate on benchmarks with small models.

```ruby
class MoAOrchestrator
  def execute(task)
    # Layer 1: Multiple proposers generate solutions
    proposals = @proposers.map { |p| p.async.run(task) }.map(&:value)

    # Layer 2: Aggregator synthesizes best answer
    @aggregator.run(task:, proposals:,
      instruction: "Synthesize the best answer from these proposals")
  end
end
```

---

## Phase E: Privacy & Polish

### 3.4 Privacy-First Architecture
**Impact:** PII protection as architectural concern
**Effort:** 2-3 weeks

```ruby
module Privacy
  class PIIDetector
    PATTERNS = {
      email: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z]{2,}\b/i,
      phone: /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/,
      ssn: /\b\d{3}-\d{2}-\d{4}\b/,
      credit_card: /\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b/
    }
  end

  class PIIProtection
    def protect(text, strategy: :tokenize) # :tokenize, :mask, :remove
    def restore(text) # Reverse tokenization
  end
end
```

---

### 4.4 Documentation
**Impact:** Adoption and maintainability
**Effort:** 1-2 weeks

| Task | Description |
|------|-------------|
| YARD docs | All DSL builder methods |
| Multi-model guide | Building agents with multiple models |
| Parallel agents guide | Sub-agent spawning patterns |
| Event patterns guide | Subscription, emission, error handling |
| Future system docs | AgentFuture vs RactorLazy::ToolFuture |

---

## Implementation Roadmap

| Phase | Status | Items |
|-------|--------|-------|
| A: Quick Wins | ✅ Complete | Loop detection, CoD, "Did You Mean?", type hints |
| B: Foundation | ✅ Complete | Budget signals, progressive disclosure, failure classification, EventStore |
| C: Testing | ✅ Complete | Test mode API, call logging, request logging, scenarios |
| D: Strategic | Pending | Checkpointing, time-travel debug, semantic breaker, MoA |
| E: Polish | Pending | Privacy architecture, documentation |

---

## What We're NOT Doing

1. **Full Ractor-based Event Bus** - Current Fiber-based approach works well
2. **Automatic Model Fingerprinting** - Needs data collection infrastructure
3. **Byzantine Fault Tolerance** - Edge case until multi-agent is mature
4. **Grammar-Constrained Decoding** - Requires model-level integration
5. **Distributed Session State** - Overkill for current use cases

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Small model (7B) success rate | ~50% | 80%+ |
| Average tokens per task | Baseline | -50% (with CoD) |
| Loop/stuck rate | Unknown | <5% |
| Time to debug failure | Hours | Minutes |
| Test coverage | 95.7% | 98%+ |

---

## Quick Reference

```bash
rake spec          # Run tests (~5s parallel)
rake spec_fast     # Skip slow/integration
rake ci            # Full CI
rake commit_prep   # Fix + Stage + Verify
```

---

*Updated: 2026-01-26*
*Version: 2.2 (Post Phase C Testing)*
