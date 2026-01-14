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
- Ruby 4.0 idioms enforced via RuboCop (hash shorthand, endless methods, Data.define)
- Custom cops for event-driven architecture (NoSleep, NoTimingAssertion, NoTimeoutBlock)
- 2982 tests passing, 92.33% coverage

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

Current: 88% code coverage, 2128 tests passing, 97.31% YARD documented

- [x] Test all public methods in core classes (comprehensive test coverage exists)
- [x] Integration tests exist in spec/integration/ (requires LIVE_MODEL_TESTS=true)
- [x] Document public API with examples (302 @example tags, all user-facing APIs documented)
- [x] Comprehensive YARD documentation across all 70 core files (7,288 lines added)
- [x] Second documentation pass: CLI, Testing, Concerns, Types, Utilities (3,662 lines added)

---

## P1.5 - RuboCop Re-enablement (Code Quality)

**Philosophy:** RuboCop cops should guide development, not be fought with disable comments. When a cop catches something, fix the underlying code to be better.

### Current State

We've enabled Ruby 4.0 idiom enforcement:
- `Style/HashSyntax` with shorthand `{x:}` (565 auto-corrected)
- `Style/EndlessMethod` for single-line methods
- `Style/NumberedParameters` for `_1`, `_2` in blocks
- `Style/DataInheritance` for proper `Data.define` form
- `Style/OpenStructUse` to forbid deprecated OpenStruct
- Custom `Smolagents/PreferDataDefine` to prefer `Data.define` over `Struct.new`
- Custom `Smolagents/NoSleep`, `NoTimingAssertion`, `NoTimeoutBlock` for event-driven architecture

### Phase 1: Quick Wins (18 offenses, ~2 hours)

| Cop | Offenses | Why Fix | Ruby 4.0 Opportunity |
|-----|----------|---------|---------------------|
| `Lint/MissingSuper` | 1 | Potential bug - subclasses should call super | - |
| `Lint/DuplicateBranch` | 6 | Code smell - duplicate code in branches | Use pattern matching |
| `Style/MultilineBlockChain` | 5 | Long chains hide complexity | Extract to named methods |
| `Naming/PredicateMethod` | 1 | Ruby idiom - `valid?` not `is_valid?` | - |
| `RSpec/LeakyConstantDeclaration` | 5 | Test pollution between specs | Use `stub_const` or anonymous classes |

- [ ] Enable `Lint/MissingSuper` and fix the 1 offense
- [ ] Enable `Lint/DuplicateBranch` and refactor 6 branches (consider pattern matching)
- [ ] Enable `Style/MultilineBlockChain` and extract 5 chains to methods
- [ ] Enable `Naming/PredicateMethod` and rename 1 method
- [ ] Enable `RSpec/LeakyConstantDeclaration` and fix 5 specs

### Phase 2: Test Doubles (160 offenses, ~1-2 days)

| Cop | Offenses | Why Fix |
|-----|----------|---------|
| `RSpec/StubbedMock` | 15 | Stubbing a mock is confusing - clarify intent |
| `RSpec/AnyInstance` | 37 | Smell indicating tight coupling - refactor to DI |
| `RSpec/VerifiedDoubles` | 108 | Catches interface mismatches - `double` → `instance_double` |

- [ ] Enable `RSpec/StubbedMock` and clarify 15 test intentions
- [ ] Enable `RSpec/AnyInstance` and refactor 37 tests to use DI or instance doubles
- [ ] Enable `RSpec/VerifiedDoubles` incrementally (108 changes)

### Phase 3: Complexity Reduction (Ongoing)

Lower metric thresholds progressively to drive architectural improvements:

| Metric | Current | Target | Offenses at Target |
|--------|---------|--------|-------------------|
| `Metrics/AbcSize` | 55 | 25 | ~25 methods |
| `Metrics/MethodLength` | 50 | 20 | ~20 methods |
| `Metrics/ParameterLists` | 13 | 6 | ~8 signatures |

**Why valuable:** Forces use of:
- `Data.define` for configuration objects (Ruby 4.0)
- Builder pattern for complex construction (our DSL)
- Pattern matching for complex branching (Ruby 4.0)
- Single-responsibility methods (clean code)

- [ ] Lower `Metrics/AbcSize` to 35, fix offenses
- [ ] Lower `Metrics/AbcSize` to 25, fix offenses
- [ ] Lower `Metrics/MethodLength` to 30, fix offenses
- [ ] Lower `Metrics/MethodLength` to 20, fix offenses
- [ ] Lower `Metrics/ParameterLists` to 8, refactor signatures
- [ ] Lower `Metrics/ParameterLists` to 6, refactor signatures

### Keep Disabled (Legitimate for our codebase)

| Cop | Reason |
|-----|--------|
| `Style/Documentation` | YARD handles documentation |
| `Naming/MethodParameterName` | Short names fine in blocks (`\|k, v\|`) |
| `Naming/BlockParameterName` | Context makes clear |
| `RSpec/ContextWording` | Stylistic preference |
| `RSpec/MultipleMemoizedHelpers` | Sometimes needed for complex setup |
| `RSpec/DescribeClass` | Integration specs don't describe single class |
| `Gemspec/DevelopmentDependencies` | Modern bundler handles this |

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
| 2026-01-14 | Ruby 4.0 Idioms - Enforce hash shorthand, endless methods, Data.define via RuboCop (565 auto-corrections) |
| 2026-01-14 | Custom Cops - `Smolagents/PreferDataDefine` for Data.define over Struct.new |
| 2026-01-14 | Custom Cops - `NoSleep`, `NoTimingAssertion`, `NoTimeoutBlock` for event-driven architecture |
| 2026-01-14 | Test Refactoring - Replace timing-dependent tests with structural verification |
| 2026-01-13 | P1 Complete - YARD documentation at 97.31% (10,950 lines across 108 files) |
| 2026-01-13 | P1 Documentation - Comprehensive YARD across 70 files (7,288 lines), 83.28% coverage |
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

- **Code:** 92.33% (threshold: 80%) ✅
- **Docs:** 97.31% (target: 95%) ✅
- **Tests:** 2982 total, 68 pending (integration tests requiring live models/Docker/Ractor)

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Events, not callbacks | Events are data (testable, replayable). Callbacks are behavior (timing-dependent). |
| Thread::Queue for events | Stdlib. `pop` blocks without polling. No custom EventQueue needed. |
| Delete 34% of codebase | Forward-only. If nothing calls it, remove it. |
| Ractors for code execution only | Model HTTP calls are I/O-bound, threads work fine |
| No API key serialization | Security - keys provided at load time |
