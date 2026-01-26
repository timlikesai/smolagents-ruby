# Cleanup & Organization Plan

**Generated:** 2025-01-25
**Branch:** feature/tool-future-lazy-eval
**Status:** EDAA Phases 1-4 Complete - Phase 5 In Progress

---

# Event-Driven Agent Architecture (EDAA)

**Vision:** Events as the fundamental atom of agent building blocks.

---

## Completed Phases

### Phase 1: Foundation ✅
### Phase 2: Multi-Model Support ✅
### Phase 3: Parallel Sub-Agents ✅
### Phase 4: Event-Driven Orchestration ✅
### Phase 4b: Code Quality Enforcement ✅

**9 Custom RuboCop Cops enforcing patterns.**

---

## Phase 5: Hardening & Polish

### 5.1 Test Coverage ✅ ALREADY COMPLETE

All critical files have comprehensive test coverage:

| Component | Files | Test Lines | Status |
|-----------|-------|------------|--------|
| Ractor Lazy System | 8 files | 1,878 lines | ✅ |
| Orchestrators | 3 files | 543 lines | ✅ |
| **Total** | 11 files | 2,421 lines | ✅ |

Coverage: 96.59% with 14,098 tests passing in ~10 seconds.

---

### 5.2 Type Consolidation (Enable TypeLocationRule) 🔲 TODO

**Goal:** Move all `Data.define` types to `lib/smolagents/types/` for discoverability.

**Scope:** 70 instances across 55 files

**Priority Order:**

#### 5.2.1 Builders (5 files, ~6 types)
- [ ] `builders/agent_builder.rb` → extract to `types/builder_config.rb`
- [ ] `builders/model_builder.rb` → extract to `types/model_builder_config.rb`
- [ ] `builders/team_builder.rb` → extract to `types/team_config.rb`
- [ ] `builders/test_builder.rb` → extract to `types/test_config.rb`
- [ ] `builders/dsl.rb` → extract inline types

#### 5.2.2 Security (7 files, ~8 types)
- [ ] `security/argument_validator/validation_result.rb` → `types/validation_result.rb`
- [ ] `security/argument_validator/validation_rule.rb` → `types/validation_rule.rb`
- [ ] `security/rate_limit_policy.rb` → `types/rate_limit_policy.rb`
- [ ] `security/spawn_context.rb` → `types/spawn_context.rb`
- [ ] `security/spawn_policy.rb` → `types/spawn_policy.rb`
- [ ] `security/spawn_validation.rb` → `types/spawn_validation.rb`
- [ ] `security/spawn_violation.rb` → `types/spawn_violation.rb`
- [ ] `security/validation_types.rb` → merge into existing types

#### 5.2.3 Executors (8 files, ~10 types)
- [ ] `executors/execution_result.rb` → `types/execution_result.rb`
- [ ] `executors/fiber_execution.rb` → extract types
- [ ] `executors/tool_future.rb` → `types/tool_future_result.rb`
- [ ] `executors/tool_pause.rb` → `types/tool_pause.rb`
- [ ] `executors/executor/tool_call_tracking.rb` → extract types
- [ ] `executors/ractor_lazy/*.rb` → extract types (4 files)

#### 5.2.4 Infrastructure (30+ files, ~40 types)
- [ ] `concerns/registry.rb` → extract RegistryEntry
- [ ] `concerns/resilience/events.rb` → extract event types
- [ ] `concerns/validation/goal_drift.rb` → extract analysis types
- [ ] `config/model_palette.rb` → `types/model_palette_entry.rb`
- [ ] `context/layer.rb` → `types/context_layer.rb`
- [ ] `context/orchestrator.rb` → extract types
- [ ] `context/providers/base.rb` → extract provider types
- [ ] `discovery/types.rb` → merge into main types/
- [ ] `discovery/scan_context.rb` → `types/scan_context.rb`
- [ ] `errors/dsl.rb` → `types/dsl_error.rb`
- [ ] `errors/tool_error.rb` → extract error types
- [ ] `events/dsl.rb` → extract event config types
- [ ] `events/registry/definition.rb` → extract definition type
- [ ] `interactive/suggestions.rb` → extract suggestion types
- [ ] `orchestrators/agent_pool.rb` → extract pool types
- [ ] `orchestrators/event_orchestrator/subscriptions.rb` → extract types
- [ ] `orchestrators/ralph_loop.rb` → extract loop types
- [ ] `persistence/*.rb` → extract manifest types (3 files)
- [ ] `pipeline.rb` → `types/pipeline_step.rb`
- [ ] `runtime/environment.rb` → `types/environment.rb`
- [ ] `runtime/spawn.rb` → extract spawn types
- [ ] `servers/llama_cpp.rb` → `types/llama_config.rb`
- [ ] `tools/search_tool/*.rb` → extract search types

#### 5.2.5 Enable Cop
- [ ] Enable `TypeLocationRule` in `.rubocop.yml`
- [ ] Run full test suite to verify no regressions

**Estimated Effort:** 4-6 hours

---

### 5.3 Architecture Debt

#### 5.3.1 AgentConfig Split (P2) ✅ COMPLETE

**Problem:** `types/agent_config.rb` had 12 fields mixing unrelated concerns.

**Solution:** Split into three focused config types with composition:

| New Type | Fields | Purpose |
|----------|--------|---------|
| `PlanningConfig` | interval, templates | Pre-Act planning phase |
| `BehavioralConfig` | evaluation_enabled, custom_instructions, refine_config, sync_events | Agent behavior |
| `ObservabilityConfig` | observe_mode, summarizer_model | Monitoring config |

**AgentConfig** now composes these (7 fields: max_steps, authorized_imports, spawn_config, memory_config, planning, behavioral, observability).

**Tasks completed:**
- [x] Create `types/planning_config.rb`
- [x] Create `types/behavioral_config.rb`
- [x] Create `types/observability_config.rb`
- [x] Update `AgentConfig` to compose these types
- [x] Update builders (AgentBuilder, TeamBuilder)
- [x] Update agent initialization, persistence, specialized agents
- [x] Update tests

**Completed:** 2026-01-25

#### 5.3.2 Event Emission Gaps (P1 #14, #15) ✅ COMPLETE

**Problem:** Models and Tools don't emit events for observability.

**Tasks for Models:**
- [x] Add `include Events::Emitter` to `models/model.rb` (via Eventing module)
- [x] Emit `ModelGenerateRequested` before LLM call in `generate`
- [x] Emit `ModelGenerateCompleted` after response
- [x] Emit `ToolCallParsed` when extracting tool calls
- [x] Add event emission tests (130 examples in eventing_spec.rb)

**Tasks for Tools:**
- [x] Add event emission to `tools/tool/execution.rb` (via Eventing module)
- [x] Emit `ToolCallRequested` before `call`
- [x] Emit `ToolCallCompleted` after step monitoring (react_loop/monitoring.rb)
- [x] Add event emission tests

**Completed:** 2026-01-25

#### 5.3.3 Retry Consolidation (P1 #12) ✅ COMPLETE

**Problem:** Three separate retry implementations with overlapping logic.

**Solution:** Created `BaseRetryHandler` class that all retry concerns now delegate to.

**New Architecture:**
| Component | Responsibility |
|-----------|----------------|
| `BaseRetryHandler` | Core retry loop, attempt counting, backoff, error classification |
| `Retryable` | Simple blocking retry, delegates to handler |
| `RetryExecution` | Model-specific with notifications, delegates to handler |
| `ToolRetry` | Event-driven non-blocking, delegates to handler |

**Tasks completed:**
- [x] Create `concerns/resilience/base_retry_handler.rb` with:
  - Attempt counting
  - Backoff calculation (exponential, jitter)
  - Error classification via policy or custom classifier
  - Max attempts enforcement
  - Pluggable delay handlers (blocking, callback, no-op)
  - on_retry callback hooks for event emission
- [x] Refactor `retryable.rb` to use BaseRetryHandler
- [x] Refactor `retry_execution.rb` to use BaseRetryHandler
- [x] Refactor `tool_retry.rb` to use BaseRetryHandler
- [x] Add comprehensive tests for BaseRetryHandler (19 examples)
- [x] Verify all existing tests pass (13,900 tests)

**Completed:** 2026-01-25

---

### 5.4 Enable PreferEndlessMethod 🔲 TODO (Optional)

**Goal:** Modernize simple methods to endless syntax.

**Scope:** ~100+ opportunities (auto-correctable)

**Tasks:**
- [ ] Run `rubocop --only Smolagents/PreferEndlessMethod -A lib/`
- [ ] Review auto-corrections for readability
- [ ] Enable cop in `.rubocop.yml`
- [ ] Run tests to verify no regressions

**Estimated Effort:** 1 hour

---

## Implementation Priority

Execute in this order:

| Priority | Task | Effort | Impact | Status |
|----------|------|--------|--------|--------|
| **P1** | 5.3.2 Event Emission Gaps | 2-3h | High (observability) | ✅ |
| **P2** | 5.3.1 AgentConfig Split | 2-3h | High (maintainability) | ✅ |
| **P3** | 5.3.3 Retry Consolidation | 3-4h | Medium (DRY) | ✅ |
| **P4** | 5.2 Type Consolidation | 4-6h | Medium (organization) | 🔲 |
| **P5** | 5.4 Enable PreferEndlessMethod | 1h | Low (style) | 🔲 |

**Remaining Estimated Effort:** 5-7 hours

---

## Phase 6: Documentation (After Phase 5)

1. **DSL Documentation** - YARD docs for all builder methods
2. **Guides** - Multi-model, parallel agents, events
3. **Performance** - Benchmarks, profiling, optimization

---

## Architecture Strengths

- **Type system:** 85+ Data.define types
- **Event system:** 50+ events with full orchestration
- **Test suite:** 14,098 examples, 96.59% coverage
- **Zero RuboCop violations:** 9 custom cops enforcing patterns
- **Event-driven enforcement:** No timing anti-patterns allowed

---

## Quick Reference

### Running Tests
```bash
rake spec          # Full test suite (~10 seconds)
rake spec_fast     # Skip slow/integration tests
rake ci            # Full CI (lint + tests)
```

### RuboCop
```bash
bundle exec rubocop lib/                                    # Check lib/
bundle exec rubocop --only Smolagents/TypeLocationRule lib/ # Check specific cop
bundle exec rubocop -A lib/                                 # Auto-correct
```

### Custom Cops
```
lib/rubocop/cop/smolagents/
├── no_sleep.rb              # Enabled
├── no_timeout_block.rb      # Enabled
├── no_timed_wait.rb         # Enabled
├── no_busy_wait.rb          # Enabled
├── no_timing_assertion.rb   # Enabled
├── prefer_data_define.rb    # Enabled
├── require_disable_comment.rb # Enabled
├── prefer_endless_method.rb # Disabled (opt-in)
└── type_location_rule.rb    # Disabled (enable after 5.2)
```
