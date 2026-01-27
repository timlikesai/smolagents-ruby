# smolagents-ruby Implementation Plan

**Branch:** feature/tool-future-lazy-eval
**Updated:** 2026-01-26
**Version:** 2.4 (Phase D Complete)

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
| Builder DSL | ✅ Excellent | Three-tier (Simple/Builder/Advanced) + MoA |
| Model Integration | ✅ Good | Multi-model, retry, circuit breaker |
| Small Model Support | ✅ Good | Progressive disclosure, Chain of Draft, context signals |
| Checkpointing | ✅ Good | State capture, restore, persistence |
| Semantic Analysis | ✅ Good | Semantic circuit breaker, failure detection |
| MoA Pattern | ✅ Good | Proposer coordination, aggregation strategies |
| Observability | ✅ Good | EventStore, query, snapshots, JSONL persistence |
| Self-Healing | ✅ Good | Circuit breaker, loop detection, failure classification |
| Documentation | ⚠️ Partial | YARD, guides needed |

**Test Suite:** 15,420 examples, 95.7% coverage, ~6s parallel

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
| Checkpoint Types | `types/checkpoint.rb`, `types/execution_state_snapshot.rb`, `types/checkpoint_config.rb` |
| Checkpoints Concern | `concerns/agents/checkpoints.rb`, `concerns/agents/checkpoints/*.rb` |
| Semantic Detection Types | `types/semantic_detection_result.rb`, `types/semantic_detection_config.rb` |
| Semantic Circuit Breaker | `concerns/agents/semantic_breaker.rb`, `concerns/agents/semantic_breaker/*.rb` |
| MoA Types | `types/proposal.rb`, `types/aggregation_result.rb`, `types/moa_config.rb` |
| MoA Concerns | `concerns/mixture_of_agents/*.rb` |
| MoA Builder | `builders/mixture_of_agents_builder.rb`, `builders/moa_coordinator.rb` |
| Phase D Events | `events/phase_d.rb` (9 new events) |
| Builder Integration | `builders/agent_builder/checkpoint_concern.rb` |

---

## Phase E: Privacy & Polish

### 3.4 Privacy-First Architecture
**Impact:** PII protection as architectural concern
**Effort:** 2-3 weeks

Key features:
- PII detection (email, phone, SSN, credit card, etc.)
- Multiple strategies: `:tokenize`, `:mask`, `:remove`
- Reversible tokenization for secure processing
- Integration with agent memory and tool I/O

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
| MoA guide | Mixture-of-Agents patterns |
| Checkpoint guide | State management and recovery |

---

## Implementation Roadmap

| Phase | Status | Items |
|-------|--------|-------|
| A: Quick Wins | ✅ Complete | Loop detection, CoD, "Did You Mean?", type hints |
| B: Foundation | ✅ Complete | Budget signals, progressive disclosure, failure classification, EventStore |
| C: Testing | ✅ Complete | Test mode API, call logging, request logging, scenarios |
| D: Strategic | ✅ Complete | Checkpointing, semantic breaker, MoA |
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
rake spec          # Run tests (~6s parallel)
rake spec_fast     # Skip slow/integration
rake ci            # Full CI
rake commit_prep   # Fix + Stage + Verify
```

---

*Updated: 2026-01-26*
*Version: 2.4 (Phase D Complete)*
