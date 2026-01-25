# Cleanup & Organization Plan

**Generated:** 2025-01-25
**Branch:** feature/tool-future-lazy-eval
**Status:** EDAA Phases 1-4 Complete - Ready for Phase 5 (Polish)

---

# Event-Driven Agent Architecture (EDAA)

**Vision:** Events as the fundamental atom of agent building blocks.

## Executive Summary

This design establishes Events as the primary orchestration mechanism for smolagents-ruby.
Rather than direct method calls between components, all significant operations emit events
that can trigger downstream workflows, enable parallel execution, and provide complete
observability.

**Key Principles:**
1. **Events are atoms** - Every significant action produces an event; events trigger workflows
2. **Models are services** - Agents don't own models; they request generation via events
3. **Parallel by default** - Sub-agents, tool calls, and model requests can run concurrently
4. **Multi-model native** - Different models for different purposes (planning, execution, evaluation)
5. **Provider-agnostic** - Same event flow works across OpenAI, Anthropic, local, hybrid

---

## Implementation Status

### Phase 1: Foundation (Events + Work Queue) ✅ COMPLETE

- `types/work_item.rb` - WorkItem type with factory methods
- `types/work_result.rb` - WorkResult type with outcomes
- 7 new orchestration events
- `concerns/orchestration/work_queue.rb` - Priority queue with events
- 169 test examples

### Phase 2: Multi-Model Support ✅ COMPLETE

- `types/model_pool_config.rb` - Purpose-to-factory mapping
- `concerns/orchestration/model_pool.rb` - Lazy resolution, caching
- `.model(:purpose) { }` DSL extension
- 168 mocked tests

### Phase 3: Parallel Sub-Agents ✅ COMPLETE

- `AgentFuture` - Background thread execution
- `ParallelAgents` concern - spawn_parallel, spawn_race, spawn_any
- `WorkerPool` - Thread management with Queue
- 154 test examples

### Phase 4: Event-Driven Orchestration ✅ COMPLETE

- `EventOrchestrator` - Central event routing
- `EventDriven` concern - Async step execution
- **Eliminated all timing anti-patterns** - No sleep, no polling, no timed waits
- Queue-based completion signaling throughout
- 249 orchestration tests
- All 14,098 tests pass in ~10 seconds

### Phase 4b: Code Quality Enforcement ✅ COMPLETE

**Custom RuboCop Cops (9 total):**

| Cop | Purpose | Status |
|-----|---------|--------|
| `NoSleep` | Forbids sleep() | Enabled |
| `NoTimeoutBlock` | Forbids Timeout.timeout | Enabled |
| `NoTimedWait` | Forbids Thread.join(n), cv.wait(m,n) | Enabled |
| `NoBusyWait` | Forbids while Time.now < deadline | Enabled |
| `NoTimingAssertion` | Forbids timing-based test assertions | Enabled |
| `PreferDataDefine` | Prefers Data.define over Struct | Enabled |
| `RequireDisableComment` | Requires explanation on rubocop:disable | Enabled |
| `PreferEndlessMethod` | Suggests endless methods for predicates | Disabled (opt-in) |
| `TypeLocationRule` | Enforces types in types/ directory | Disabled (aspirational) |

---

## What's Next: Phase 5 Options

### Option A: Documentation & Polish (Recommended)

Focus on making the architecture accessible and production-ready:

1. **DSL Documentation**
   - YARD docs for all builder methods
   - `.help` content for new methods (`.model(:purpose)`, `.parallel`)
   - Examples in README

2. **Guides**
   - Multi-model configuration guide
   - Parallel agent patterns guide
   - Event subscription cookbook
   - Migration guide from classic to event-driven

3. **Performance Validation**
   - Benchmark suite for parallel execution
   - Memory profiling under load
   - Optimization pass if needed

### Option B: Architecture Debt

Address remaining P1 items from the audit:

1. **AgentConfig Split** (P1 #7)
   - Split 12-field type into focused configs:
   - `PlanningConfig`, `BehavioralConfig`, `ObservabilityConfig`

2. **Event Emission Gaps** (P1 #14, #15)
   - Add events to Model base class
   - Add events to Tool base class
   - Complete observability coverage

3. **Retry Consolidation** (P1 #12)
   - Three retry implementations → one BaseRetryHandler
   - Unify: retryable.rb, retry_execution.rb, tool_retry.rb

### Option C: Test Coverage

Fill gaps in test coverage:

1. **Ractor Lazy System** (P2 #19)
   - batch_handling.rb (95 lines, needs specs)
   - context.rb (85 lines, needs specs)
   - future_combinators.rb (101 lines, needs specs)

2. **Orchestrators** (P2 #20)
   - agent_pool.rb (176 lines)
   - ralph_loop.rb

### Option D: Enable Opt-In Cops

Gradually enable the aspirational cops:

1. **TypeLocationRule** - Consolidate types to `types/` directory
   - ~55 Data.define usages outside types/
   - Move them, enable cop

2. **PreferEndlessMethod** - Modernize method syntax
   - ~100+ conversion opportunities
   - Auto-correct available

---

## Architecture Strengths

- **Type system:** 85+ Data.define types
- **Event system:** 50+ events with full orchestration
- **Executor abstraction:** All code through executor
- **Builder pattern:** Lazy evaluation, immutable configs
- **Test suite:** 14,098 examples, 96.59% coverage
- **Zero RuboCop violations:** 9 custom cops enforcing patterns
- **Event-driven enforcement:** No timing anti-patterns allowed
- **Work Queue:** Generalized priority queue
- **Model Pool:** Multi-model with purpose-based selection

---

## Quick Reference

### Running Tests
```bash
rake spec          # Full test suite
rake spec_fast     # Skip slow/integration tests
rake ci            # Full CI (lint + tests)
```

### RuboCop
```bash
bundle exec rubocop lib/                              # Check lib/
bundle exec rubocop --only Smolagents/PreferEndlessMethod lib/  # Check specific cop
bundle exec rubocop -A lib/                           # Auto-correct
```

### Custom Cops Location
```
lib/rubocop/cop/smolagents/
├── no_sleep.rb
├── no_timeout_block.rb
├── no_timed_wait.rb
├── no_busy_wait.rb
├── no_timing_assertion.rb
├── prefer_data_define.rb
├── prefer_endless_method.rb
├── require_disable_comment.rb
└── type_location_rule.rb
```
