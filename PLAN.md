# smolagents-ruby Project Plan

Delightfully simple agents that think in Ruby.

See [ARCHITECTURE.md](ARCHITECTURE.md) for vision, patterns, and examples.

---

## Principles

- **Ship it**: Working software over perfect architecture
- **Simple first**: If it needs explanation, simplify it
- **Test everything**: No feature without tests
- **Delete unused code**: If nothing calls it, remove it

---

## Current Status

**What works:**
- CodeAgent - writes Ruby code, executes tools, returns answers
- ToolCallingAgent - uses JSON tool calling format
- Builder DSL - `Smolagents.code.model{}.tools().build`
- Models - OpenAI, Anthropic, LiteLLM adapters
- Tools - base class, registry, 10+ built-ins
- ToolResult - chainable, pattern-matchable
- Executors - Ruby sandbox, Docker, Ractor isolation
- Event system - Thread::Queue, Emitter/Consumer pattern
- 2131 tests passing, 87.95% coverage

---

## P0 - Simplify & Wire Event System ✅ COMPLETE

**Problem:** 603 LOC event infrastructure that emits to nowhere.

**Decision:** Keep events (not callbacks). Simplify to ~100 LOC. Wire it up.

| Delete | LOC | Replacement |
|--------|-----|-------------|
| EventQueue class | 219 | Thread::Queue (stdlib) |
| Mappings (legacy aliases) | 105 | Nothing |
| Priority/scheduling | ~90 | YAGNI |
| Rate limit helpers | ~30 | Move to concerns |

| Add | LOC |
|-----|-----|
| Queue initialization in Agent | ~5 |
| connect_to wiring | ~5 |
| drain_events in ReActLoop | ~10 |

**Result:** 603 LOC → ~100 LOC. Events actually fire.

- [x] Delete EventQueue class, use Thread::Queue
- [x] Simplify Mappings module (removed legacy aliases)
- [x] Simplify Emitter to ~47 LOC
- [x] Simplify Consumer to ~58 LOC
- [x] Wire: Agent creates queue, connects emitters, drains after steps (already done via Monitorable + ReActLoop)
- [x] Test: 39 event tests + react_loop event tests passing

---

## P0 - Delete Dead Code ✅ PARTIAL

Deep analysis found some code was actually used. Deleted only truly unused code.

### Concerns - Deleted (141 LOC)

| Concern | LOC | Status |
|---------|-----|--------|
| Measurable | 106 | ✅ Deleted |
| Streamable | 35 | ✅ Deleted |

### Concerns - Kept (actually used)

| Concern | Used By |
|---------|---------|
| ModelReliability | Model classes for retry/fallback |
| ModelHealth | Model health checks |
| RequestQueue | Model request queuing |
| CircuitBreaker | Api concern |
| Resilience | Model reliability |
| Auditable | Api concern |
| Retryable | Api concern |
| Mcp | MCP tools |
| SandboxMethods | Executors |
| GemLoader | Optional gem loading |

### Tools - Deleted (368 LOC)

| Item | LOC | Status |
|------|-----|--------|
| ToolCollection | 198 | ✅ Deleted |
| MCPToolCollection | 170 | ✅ Deleted |

Registry kept - used by tool lookup system.

### Types - Deleted (~350 LOC)

| Type | LOC | Status |
|------|-----|--------|
| Goal + GoalDynamic | ~210 | ✅ Deleted |
| AgentResult | ~140 | ✅ Deleted |

**Total deleted:** ~860 LOC of truly unused code

---

## P0.5 - Deduplication & Cleanup

Deep architecture analysis revealed several areas of duplication and dead code. These are low-risk, high-clarity improvements.

### 1. Harmonize Outcome State Names (~1 hour)

**Problem:** Three parallel outcome systems with inconsistent state naming.

| System | Location | `:max_steps` variant |
|--------|----------|---------------------|
| `Outcome` module | types/outcome.rb | `:max_steps` (constant) |
| `ExecutionOutcome` | types/execution_outcome.rb | `:max_steps_reached` |
| `ExecutorExecutionOutcome` | types/executor_execution_outcome.rb | N/A (never produces) |
| `RunResult` | types/data_types.rb | `:max_steps_reached` |
| `OutcomePredicates` | types/execution_outcome.rb | Checks `:max_steps_reached` |

**Conversion mismatch in `Outcome.from_run_result`:**
```ruby
when :max_steps_reached then MAX_STEPS  # converts :max_steps_reached → :max_steps
```

**Fix:** Standardize on `:max_steps_reached` everywhere.

| File | Line | Change |
|------|------|--------|
| types/outcome.rb | 10 | `MAX_STEPS = :max_steps_reached` |
| types/outcome.rb | 14 | Update `RETRIABLE` to include `:max_steps_reached` |
| types/outcome.rb | 29 | Remove conversion, return `MAX_STEPS` directly |
| spec/smolagents/types/outcome_spec.rb | Various | Update test expectations |

- [x] Change `Outcome::MAX_STEPS` from `:max_steps` to `:max_steps_reached`
- [x] Update `Outcome.from_run_result` to use constant instead of hardcoded symbol
- [x] Update specs to expect `:max_steps_reached`
- [x] Run tests to confirm no breakage ✅ COMPLETED

---

### 2. Remove Unused Event Infrastructure from Models (~30 min) ✅ COMPLETED

**Problem:** Model base class includes event infrastructure that's never used.

**Dead code in `lib/smolagents/models/model.rb`:**
- Line 40: `include Events::Emitter` - included but `emit()` never called
- Lines 67-85: `with_generation_events()` method - **defined but never called anywhere**
- Line 56: `@event_queue = nil` - initialized but unused

**All model implementations use `Instrumentation.instrument()` instead:**
- OpenAIModel (line 126): `Instrumentation.instrument("smolagents.model.generate")`
- AnthropicModel (line 78): `Instrumentation.instrument("smolagents.model.generate")`

**Orphaned event types never emitted:**
- `ModelGenerateRequested` (events.rb:35) - only in dead `with_generation_events()`
- `ModelGenerateCompleted` (events.rb:41) - only in dead `with_generation_events()`
- `RateLimitHit` (events.rb:114) - defined but never emitted
- `RetryRequested` (events.rb:124) - defined but never emitted
- `FailoverOccurred` (events.rb:130) - defined but never emitted
- `RecoveryCompleted` (events.rb:136) - defined but never emitted

**Fix:**
- [x] Delete `with_generation_events()` method from model.rb
- [x] Remove `include Events::Emitter` from Model base class
- [x] Delete orphaned event types from events.rb (ModelGenerateRequested, ModelGenerateCompleted)
- [x] Update event mappings.rb to remove deleted event types
- [x] Run tests to confirm no breakage
- Note: Reliability events (RateLimitHit, RetryRequested, FailoverOccurred, RecoveryCompleted) are used by ModelReliability concern - kept

---

### 3. Remove Validation API Duplication (~30 min) ✅ COMPLETED

**Problem:** Tool class has 6 validation methods, but only 3 are actually used.

**Current methods in `lib/smolagents/tools/tool.rb`:**

| Method | Line | Called? | Action |
|--------|------|---------|--------|
| `validate_arguments!` | 419 | ✅ Yes (initialize) | Keep |
| `validate_arguments` | 437 | ❌ Never | Delete |
| `valid_arguments?` | 447 | ❌ Never (alias) | Delete |
| `validate_input_spec!` | 460 | ✅ Yes (by validate_arguments!) | Keep |
| `validate_input_spec` | 472 | ❌ Only by validate_arguments | Delete |
| `valid_input_spec?` | 481 | ❌ Never (alias) | Delete |
| `validate_tool_arguments` | 503 | ✅ Yes (tool_execution.rb) | Keep |

**Call graph:**
```
Tool#initialize (line 251)
  └─> validate_arguments! ✓
        └─> validate_input_spec! ✓

ToolExecution#execute_tool_call (line 121)
  └─> validate_tool_arguments ✓

UNUSED:
  validate_arguments → validate_input_spec
  valid_arguments? (alias)
  valid_input_spec? (alias)
```

**Fix:**
- [x] Delete `validate_arguments` method
- [x] Delete `valid_arguments?` alias
- [x] Delete `validate_input_spec` method
- [x] Delete `valid_input_spec?` alias
- [x] Run tests to confirm no breakage

---

### 4. Relocate Mutable Collections (~45 min) ✅ COMPLETED

**Problem:** Mutable classes in `types/` directory contradict immutable Data.define philosophy.

**Mutable classes currently in types/:**

| Class | File | Mutation Pattern |
|-------|------|-----------------|
| `AgentMemory` | types/agent_memory.rb | `@steps << step`, `@steps = []` |
| `ToolStatsAggregator` | types/tool_stats.rb | `@stats[name] = ...` |
| `ActionStepBuilder` | types/steps.rb | 13 `attr_accessor` mutations |

**Note:** `ActionStepBuilder` mutability is **intentional and required** for multi-phase step execution. It captures data across generate → extract → execute → error phases.

**Fix:** Create `lib/smolagents/collections/` namespace for clarity.

```
lib/smolagents/collections/
├── agent_memory.rb      (moved from types/)
├── tool_stats_aggregator.rb  (extracted from types/tool_stats.rb)
└── action_step_builder.rb    (extracted from types/steps.rb)
```

**Changes:**
- [x] Create `lib/smolagents/collections.rb` loader
- [x] Move `AgentMemory` to collections/ (update namespace to `Collections::AgentMemory`)
- [x] Extract `ToolStatsAggregator` to collections/ (keep `ToolStats` Data.define in types/)
- [x] Extract `ActionStepBuilder` to collections/ (keep `ActionStep` Data.define in types/)
- [x] Update re-exports in types.rb to point to collections/
- [x] Run tests to confirm no breakage (2128 tests pass, 88% coverage)
- Note: Specs remain in original locations since they test via public API re-exports

---

### Summary: Deduplication Tasks ✅ ALL COMPLETED

| Task | Effort | LOC Removed | Risk |
|------|--------|-------------|------|
| Harmonize outcome states | 1 hour | 0 (rename) | Low |
| Remove unused model events | 30 min | ~80 | Low |
| Remove validation duplication | 30 min | ~25 | Low |
| Relocate mutable collections | 45 min | 0 (move) | Low |
| **Total** | **~3 hours** | **~105** | **Low** |

---

## P1 - Test Coverage & Documentation ✅ COMPLETE

Current: 88% code coverage, 2128 tests passing, 83.28% YARD documented

- [x] Test all public methods in core classes (comprehensive test coverage exists)
- [x] Integration tests exist in spec/integration/ (requires LIVE_MODEL_TESTS=true)
- [x] Document public API with examples (302 @example tags, all user-facing APIs documented)
- [x] Comprehensive YARD documentation across all 70 core files (7,288 lines added)

---

## P2 - Release

- [ ] README with getting started guide
- [ ] Gemspec complete
- [ ] CHANGELOG
- [ ] Version 1.0.0

---

## Completed Work

| Date | Item |
|------|------|
| 2026-01-13 | P1 Complete - Comprehensive YARD documentation across 70 files (7,288 lines), 83.28% coverage |
| 2026-01-13 | P1 Documentation - Added YARD docs to Builders and Collections modules, 70% coverage |
| 2026-01-13 | P0.5 Deduplication - Harmonized outcomes, removed dead model events, cleaned validation API, reorganized collections |
| 2026-01-13 | P0 Event Simplification - deleted EventQueue (219 LOC), simplified Emitter/Consumer/Mappings |
| 2026-01-13 | P0 Dead Code Removal - deleted ~860 LOC: Measurable, Streamable, ToolCollection, MCPToolCollection, Goal, AgentResult |
| 2026-01-13 | Deep Analysis - identified architecture is 90% complete, needs wiring |
| 2026-01-12 | Agent Persistence - `agent.save(path)` / `Agent.from_folder(path, model:)` |
| 2026-01-12 | DSL.Builder Framework - `builder_method` DSL, `.help`, `.freeze!` |
| 2026-01-12 | Model Reliability - `.with_retry`, `.with_fallback`, `.with_health_check` |
| 2026-01-12 | Telemetry - Instrumentation, LoggingSubscriber, OTel integration |

---

## Backlog (Deferred)

| Item | Notes |
|------|-------|
| HuggingFace Inference API | Use LiteLLM instead |
| Amazon Bedrock Support | Use LiteLLM instead |
| Local Model Auto-Detection | Nice-to-have |
| Data Pipeline DSL | May overlap with existing Pipeline |

---

## Coverage

- **Code:** 88.16% (threshold: 80%)
- **Docs:** 83.28% (target: 90%)
- **Tests:** 2128 total, 42 pending (integration tests requiring live models/Docker/Ractor)

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Events, not callbacks | Events are data (testable, replayable). Callbacks are behavior (timing-dependent). |
| Thread::Queue for events | Stdlib. `pop` blocks without polling. No custom EventQueue needed. |
| Delete 34% of codebase | Forward-only. If nothing calls it, remove it. |
| Ractors for code execution only | Model HTTP calls are I/O-bound, threads work fine |
| No API key serialization | Security - keys provided at load time |
