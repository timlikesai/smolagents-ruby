# Cleanup & Organization Plan

**Generated:** 2025-01-25
**Branch:** feature/tool-future-lazy-eval
**Status:** Comprehensive Audit Complete - Ready for Implementation

---

## Priority Legend

- **P0 (Critical)**: Blocks future work, violates core architecture rules
- **P1 (High)**: Significant inconsistency, affects maintainability
- **P2 (Medium)**: Code quality improvement, reduces technical debt
- **P3 (Low)**: Polish, nice-to-have refinements

---

## P0: Critical - Prevents Future Work

### 1. Concern Boundary Violations - COMPREHENSIVE REFACTORING PLAN

**Problem:** CLAUDE.md specifies "Modules ≤100 lines" but concerns exceed this limit.

**Key Insight:** RuboCop counts CODE lines (not comments). Research shows most concerns are actually compliant or marginal when measured correctly. The real opportunity is **architectural reinforcement** - extracting embedded types to `types/` makes concerns smaller AND reinforces our type system.

#### Reality Check: Actual Code Lines (excluding comments)

| File | Total | Code | Status | Action |
|------|-------|------|--------|--------|
| `react_loop/repetition.rb` | 166 | 95 | ✅ Compliant | Types already extracted |
| `resilience/circuit_breaker.rb` | 155 | ~100 | Marginal | Extract StateChangeEmitter |
| `agents/mixed_refinement.rb` | 143 | 100 | Marginal | Extract FeedbackLoop |
| `agents/completion_validation.rb` | 138 | 73 | ✅ Compliant | Extract ValidationRejection type |
| `formatting/structure.rb` | 138 | ~95 | Marginal | Split into sub-modules |
| `react_loop/execution/loop.rb` | 137 | 68 | ✅ Compliant | Minor cleanup |
| `agents/react_loop.rb` | 137 | 19 | ✅ Compliant | Mostly docs |
| `agents/early_yield.rb` | 137 | 76 | ✅ Compliant | Extract ParallelExecutionState type |
| `agents/async.rb` | 134 | 57 | ✅ Compliant | No action needed |
| `resilience/tool_retry.rb` | 133 | ~90 | Marginal | Consolidate with Retryable |
| `agents/planning.rb` | 121 | 82 | ✅ Compliant | Already split |
| `agents/health.rb` | 120 | 63 | ✅ Compliant | No action needed |
| `planning/divergence.rb` | 115 | 69 | ✅ Compliant | No action needed |
| `goal_aware_yield.rb` | 115 | 45 | ✅ Compliant | No action needed |
| `isolation/tool_isolation.rb` | 114 | ~70 | ✅ Compliant | Extract IsolationEmitter |
| `goal_driven_loop.rb` | 110 | 38 | ✅ Compliant | No action needed |
| `observation_router.rb` | 124 | 61 | ✅ Compliant | Extract Formatter sub-module |

---

## Foundation Phase: Type Extractions (Enables Everything Else)

**Principle:** Types belong in `types/`. Extracting embedded types:
1. Reduces concern line counts
2. Makes types reusable across codebase
3. Reinforces Data.define as THE pattern for domain objects
4. Improves testability (types tested in isolation)

### Embedded Types to Extract (14 total, ~170 lines saved)

#### High Priority (Critical path - enables other work)

| Type | Location | Lines | Target |
|------|----------|-------|--------|
| `ValidationRejection` | `completion_validation.rb:13` | 5 | `types/validation_rejection.rb` |
| `ParallelExecutionState` | `early_yield.rb:74-89` | 18 | `types/parallel_execution_state.rb` |
| `ExecutionFeedback` | `validation/execution_oracle.rb:22-55` | 34 | `types/execution_feedback.rb` |
| `RetryPolicy` | `resilience/retry_policy.rb:29-77` | 49 | `types/retry_policy.rb` |

#### Medium Priority (Model/Queue types)

| Type | Location | Lines | Target |
|------|----------|-------|--------|
| `HealthStatus` | `models/health/types.rb:21-28` | 8 | `types/health_status.rb` |
| `ModelInfo` | `models/health/types.rb:44-47` | 4 | `types/model_info.rb` |
| `QueuedRequest` | `models/queue/types.rb:20-28` | 9 | `types/queued_request.rb` |
| `QueueStats` | `models/queue/types.rb:45-57` | 13 | `types/queue_stats.rb` |
| `FailedRequest` | `models/queue/types.rb:74-91` | 18 | `types/failed_request.rb` |

#### Lower Priority (Validation/Events)

| Type | Location | Lines | Target |
|------|----------|-------|--------|
| `DriftConfig` | `validation/goal_drift.rb:37-49` | 13 | `types/drift_config.rb` |
| `DriftResult` | `validation/goal_drift.rb:63-78` | 16 | `types/drift_result.rb` |
| `RetryEvent` | `resilience/events.rb:28-35` | 8 | `types/retry_event.rb` |
| `FailoverEvent` | `resilience/events.rb:57-64` | 8 | `types/failover_event.rb` |
| `ConcernInfo` | `registry.rb:18-22` | 5 | `types/concern_info.rb` |

**Note:** `RefinementState` in `self_refine/loop.rb` uses `Struct.new` for mutability - keep as-is with documentation.

---

## Pattern Phase: Sub-Module Extractions

**Principle:** When a concern has distinct responsibilities, split into sub-modules.
This reinforces single-responsibility while keeping related code co-located.

### High-Value Extractions (Clear wins)

| Concern | Extract To | Lines Saved | Risk |
|---------|-----------|-------------|------|
| `observation_router.rb` | `observation_router/formatter.rb` | 15 | LOW |
| `repetition.rb` | `repetition/detection.rb` | 10 | LOW |
| `circuit_breaker.rb` | `circuit_breaker/state_emitter.rb` | 20 | MEDIUM |
| `tool_isolation.rb` | `isolation/emitter.rb` | 16 | LOW |
| `structure.rb` | `structure/{primitives,arrays,hashes}.rb` | 25 | LOW |

### Medium-Value Extractions

| Concern | Extract To | Lines Saved | Risk |
|---------|-----------|-------------|------|
| `mixed_refinement.rb` | `mixed_refinement/feedback_loop.rb` | 15 | MEDIUM |
| `planning/divergence.rb` | `divergence/alignment_tracking.rb` | 15 | MEDIUM |
| `tool_retry.rb` | Consolidate into `retryable.rb` | 30 | MEDIUM |

---

## Idiom Phase: Ruby 4.0 Reinforcement

**Principle:** Use modern Ruby idioms consistently. This isn't just style -
endless methods save lines and express intent clearly.

### Endless Method Opportunities (15+ lines saved)

Files with methods that should become endless:
- `circuit_breaker.rb`: `non_circuit_error?`, `state_changed?`
- `tool_retry.rb`: `default_policy`
- `structure.rb`: Multiple describe_* methods
- `observation_router.rb`: `skip_observation_formatting?`

### Pattern Matching Opportunities

Files with `case/when` that could use `case/in`:
- `structure.rb:25-32` - Type dispatch (already using `then`, could use `in`)
- `completion_validation.rb` - Validation result handling

---

## Test Coverage Risk Assessment

Before refactoring, verify test coverage:

| Concern | Coverage | Risk | Safe to Refactor? |
|---------|----------|------|-------------------|
| `formatting/structure.rb` | 4x (556 lines) | LOW | ✅ YES - pure functions |
| `mixed_refinement.rb` | 2.9x (414 lines) | LOW | ✅ YES |
| `circuit_breaker.rb` | 2.2x (339 lines) | MEDIUM | ✅ YES with care |
| `models/health/operations.rb` | 2.4x (537 lines) | LOW | ✅ YES |
| `repetition.rb` | 0.7x (119 lines) | MEDIUM-HIGH | ⚠️ Expand tests first |
| `completion_validation.rb` | Good | MEDIUM | ⚠️ Fragile mocks |
| `registrations.rb` | 0x (no tests) | CRITICAL | ❌ Create tests first |

---

## Implementation Order (Architecture-First)

### Sprint 1: Foundation (Types) ✅ COMPLETED
1. ✅ Extract `ValidationRejection` → `types/validation_rejection.rb`
2. ⏭️ `ParallelExecutionState` - NOT extracted (mutable state by design, kept in concern)
3. ✅ Extract `ExecutionFeedback` → `types/execution_feedback.rb`
4. ✅ Extract `RetryPolicy` → `types/retry_policy.rb`

**Impact:** 3 concerns become smaller, type system grows stronger

### Sprint 2: Model Types ✅ COMPLETED
5. ✅ Extract `HealthStatus` → `types/health_status.rb`
6. ✅ Extract `ModelInfo` → `types/model_info.rb`
7. ✅ Extract `QueuedRequest` → `types/queued_request.rb`
8. ✅ Extract `QueueStats` → `types/queue_stats.rb`
9. ✅ Extract `FailedRequest` → `types/failed_request.rb`
10. ✅ Update concerns to `require_relative` the types

**Impact:** Cleaner separation of data vs behavior

### Sprint 3: Sub-Modules ✅ COMPLETED
11. ✅ Split `formatting/structure.rb` into sub-modules:
    - `structure/primitives.rb` - primitive value formatting
    - `structure/arrays.rb` - array formatting with access patterns
    - `structure/hashes.rb` - hash formatting with nested paths
    - `structure/helpers.rb` - shared utilities
12. ⏭️ `observation_router/formatter.rb` - NOT needed (already under 100 code lines)
13. ⏭️ `circuit_breaker/state_emitter.rb` - NOT needed (already under 100 code lines)

**Impact:** All concerns now under 100 code lines

### Sprint 4: Consolidation
10. Merge `tool_retry.rb` logic into `retryable.rb`
11. Convert to endless methods where beneficial
12. Add pattern matching where it improves clarity

**Impact:** DRY code, modern idioms throughout

---

### 2. ~~Event System: MixedRefinementCompleted Missing from Mappings~~ ✅ FIXED

~~**Problem:** Event is defined and emitted but NOT in mappings - handlers can't subscribe.~~

**Status:** Fixed - `mixed_refinement_complete` mapping added to `lib/smolagents/events/mappings.rb`

---

### 3. Dead Code: Goal Abandonment System ✅ PARTIALLY FIXED

**Problem:** Partially implemented system with unused code.

**Status:**
- ✅ `GoalAbandoned` event class removed (previous pass)
- ✅ `:goal_abandoned` registry entry removed (this pass)

**Remaining (Low Priority):** Goal type still has unused methods:
- `types/goal.rb:130` - `Goal.abandon(reason:)` - never called in production
- `types/goal.rb:105` - `Goal#abandoned?` - never used in production
- `types/goal.rb:111` - `Goal#closed?` - never called anywhere

**Decision:** Keep these methods for API completeness. Goal has 4 valid states
(`:active`, `:blocked`, `:completed`, `:abandoned`) - the methods support the full state machine
even if abandonment isn't currently triggered by the agent.

---

### 4. ~~DSL Callback Name Mismatches~~ ✅ FIXED

~~**Problem:** Documentation shows different method names than implementation.~~

**Status:** Fixed - Updated `callbacks.rb` to use `maps_to:` parameter:
- `on_model_change` now maps to `:model_changed` event (matches docs)
- `on_queue_wait` now maps to `:queue_request_started` event (matches docs)

---

### 5. ~~Missing Test Coverage: incremental_execution.rb~~ ✅ FIXED

~~**Problem:** 139 lines of fiber-based execution code with NO dedicated spec.~~

**Status:** Fixed - Created `spec/smolagents/executors/incremental_execution_spec.rb` with comprehensive tests:
- Fiber context tracking
- Normal incremental execution flow
- ToolPause handling and resumption
- FinalAnswerException handling
- Error cases during fiber execution
- Multiple pauses in sequence

---

### 6. Events Never Emitted: ToolCallRequested

**Problem:** Event defined but never emitted anywhere.

**File:** `lib/smolagents/events.rb:29`

**Analysis:** The event exists with a mapping (`tool_call: -> { ToolCallRequested }`) but is never emitted.
Tool execution flows through multiple paths:
- `Ractor.execute_single_tool` - actual execution
- `execute_tool_call` method - provided by including class (mocked in tests)
- Various async/parallel execution wrappers

**Decision Required:**
- Option A: Emit in Ractor executor before `tool.call` (low-level, comprehensive)
- Option B: Remove event and mapping (if not needed for observability)
- Option C: Keep as-is (mapping exists for future use)

**Status:** Deferred - requires architecture decision on observability model.

---

## P1: High Impact - Affects Maintainability

### 7. Type System: AgentConfig Has Too Many Fields (12 fields, 11 optional)

**Problem:** Configuration type mixes unrelated concerns.

**Current fields in `types/agent_config.rb`:**
- Planning: `planning_interval`, `planning_templates`
- Behavioral: `evaluation_enabled`, `custom_instructions`, `refine_config`, `sync_events`
- Observability: `observe_mode`, `summarizer_model`
- Core: `max_steps`, `authorized_imports`, `spawn_config`, `memory_config`

**Recommendation:** Split into focused types:
```ruby
PlanningConfig = Data.define(:interval, :templates)
BehavioralConfig = Data.define(:custom_instructions, :evaluation_enabled, :refine_config, :sync_events)
ObservabilityConfig = Data.define(:observe_mode, :summarizer_model)
```

---

### 8. ~~Ruby 4.0 Idiom: Struct.new vs Data.define~~ ✅ REVIEWED

**Status:** Both files have proper RuboCop disables with comments documenting why mutability is needed:
- `utilities/pattern_matching/final_answer.rb:9` - ParseState needs mutation for character parsing
- `concerns/agents/self_refine/loop.rb:27` - RefinementState needs mutation for loop iteration

No changes needed - the documentation is already in place.

---

### 9. ~~Naming: Underscore-Prefixed Public API Methods~~ ✅ FIXED

**Status:** Added `@api private` documentation and rationale to all FutureBase files:
- `executors/future_base.rb` - Core rationale for the naming convention
- `executors/tool_future.rb` - Reference to FutureBase
- `executors/ractor_lazy/tool_future.rb` - Reference to FutureBase
- `executors/ractor_lazy/future_combinators.rb` - Reference to FutureBase

The underscore prefix is intentional for duck-typing and avoiding method conflicts.

---

### 10. ~~Code Duplication: Search Tool Message Templates~~ ✅ ALREADY ADDRESSED

**Status:** `Support::ResultTemplates` mixin already exists at `tools/support/result_templates.rb`.

Both ArxivSearch and WikipediaSearch include this mixin and use its DSL (`empty_message`,
`next_steps_message`). The message *content* differs between tools (ArXiv talks about papers,
Wikipedia talks about articles) - this is proper domain customization, not duplication.

No changes needed - the pattern is already extracted.

---

### 11. Code Duplication: Model Adapter Response Parsing

**Problem:** OpenAI and Anthropic response parsers share 70%+ code structure.

**Files:**
- `models/openai/response_parser.rb`
- `models/anthropic/response_parser.rb`

**Shared Pattern:**
- Include `ModelSupport::ResponseParsing`
- Define `parse_response(response)` with provider-specific extraction
- Extract content, tool calls, token usage
- Convert to `ChatMessage`

**Fix:** Create `ModelAdapterBase` with shared parsing logic and provider hooks.

---

### 12. Code Duplication: Retry Logic (3 implementations)

**Problem:** Three separate retry implementations with overlapping logic.

| File | Purpose |
|------|---------|
| `concerns/resilience/retryable.rb` | Generic retry with exponential backoff |
| `concerns/resilience/retry_execution.rb` | Model-specific retry with events |
| `concerns/resilience/tool_retry.rb` | Tool-specific event-driven retry |

**All three handle:** Attempt counting, backoff calculation, error filtering, max attempts, event emission.

**Fix:** Consolidate into `BaseRetryHandler` with hooks for callbacks.

---

### 13. ~~Constants: Unfrozen Numeric Constants (5 instances)~~ ✅ NOT APPLICABLE

**Status:** Integers in Ruby are already immutable. Adding `.freeze` is redundant and
RuboCop's `Style/RedundantFreeze` correctly rejects this pattern.

No changes needed - current code is correct.

---

### 14. Architecture Gap: Models Don't Emit Events

**Problem:** Models have no event emission for observability.

**Missing events:**
- `ModelGenerateRequested` - before LLM call
- `ModelGenerateCompleted` - after response
- `ToolCallParsed` - tool extraction

**Impact:** External monitoring can't track model behavior without coupling.

**Fix:** Add `include Events::Emitter` to Model base class with optional emission.

---

### 15. Architecture Gap: Tools Don't Emit Events

**Problem:** Most tools don't emit `ToolCallCompleted` with metrics.

**Impact:** Per-tool monitoring, rate limiting feedback unavailable.

**Exception:** `ManagedAgentTool` does emit events (good example).

**Fix:** Add event emission to `Tool::Execution` module.

---

## P2: Medium Impact - Code Quality

### 16. Ruby 4.0 Idiom: Lambda vs Stabby Lambda Syntax

**Problem:** Mixing `lambda { }` with `->` stabby lambda syntax.

**Files with `lambda { }` that should use `->`:**
- `config/validators.rb:19-31` (3 lambdas)
- `persistence/errors.rb:49,54,60,71,77,84` (6 lambdas)

**Fix:** Standardize on `->` stabby lambda syntax throughout.

---

### 17. Model Adapter: Inconsistent Method Signatures

**Problem:** `build_params` signatures differ between adapters.

**OpenAI** (`models/openai/request_builder.rb:38`):
```ruby
def build_params(messages:, stop_sequences:, temperature:, max_tokens:, tools:, response_format:)
```

**Anthropic** (`models/anthropic/request_builder.rb:35`):
```ruby
def build_params(messages:, stop_sequences:, temperature:, max_tokens:, tools:)
# response_format NOT accepted!
```

**Fix:** Both should accept same parameters (Anthropic can ignore response_format).

---

### 18. Model Adapter: Anthropic max_tokens Default Behavior

**Problem:** AnthropicModel applies `DEFAULT_MAX_TOKENS = 4096` even when not specified.

**File:** `models/anthropic_model.rb:118`

**OpenAI:** Passes nil if not specified.

**Impact:** Same builder config produces different behavior across adapters.

**Fix:** Document this difference OR make both behave identically.

---

### 19. Test Coverage Gap: Ractor Lazy Execution System (669 lines)

**Problem:** Complex concurrent code with partial test coverage.

**Files needing dedicated specs:**
- `executors/ractor_lazy/batch_handling.rb` (95 lines)
- `executors/ractor_lazy/context.rb` (85 lines)
- `executors/ractor_lazy/future_combinators.rb` (101 lines)
- `executors/ractor_lazy/future_resolution.rb` (60 lines)

**Fix:** Add comprehensive unit tests for wave resolution, dependency handling.

---

### 20. Test Coverage Gap: Orchestrators

**Problem:** Ralph Loop and Agent Pool have minimal test coverage.

**Files:**
- `orchestrators/agent_pool.rb` (176 lines)
- `orchestrators/ralph_loop.rb`

**Fix:** Add tests for parallel execution, timeout handling, error scenarios.

---

### 21. Concern Naming Inconsistency

**Problem:** Some concerns use `Concern` suffix, others don't.

| Has Suffix | No Suffix |
|------------|-----------|
| `ModelConcern` | `ToolResolution` |
| `SettersConcern` | `Callbacks` |
| `BuildConcern` | `Resolution` |

**Fix:** Standardize - either all use suffix or none do.

---

### 22. Formatting Concerns Not Used Internally

**Problem:** Powerful formatting concerns exist but aren't used by internal code.

**Available concerns:**
- `Concerns::ResultFormatting` - `.as_markdown`, `.as_table`, `.as_list`
- `Concerns::MessageFormatting` - LLM message formatting
- `Concerns::StructureFormatting` - Data structure description

**Missing usage:**
- SearchTool builds results manually instead of using ResultFormatting
- Model adapters reimplement MessageFormatting instead of using concern
- Builder introspection uses custom formatting instead of StructureFormatting

**Fix:** Refactor internal code to use shared concerns.

---

## P3: Low Impact - Polish

### 23. Endless Method Opportunities

**Problem:** Some simple methods could be converted to endless definitions.

**Examples:**
- Response parsers have multi-line methods that could be one-liners
- Simple predicate methods not using `=` syntax

**Status:** Not urgent - existing code is correct and readable.

---

### 24. Pattern Matching Opportunities

**Problem:** Some `case/when` could be `case/in` for better Ruby 4.0 idioms.

**Files:**
- `builders/team_builder/resolution_concern.rb:34-43`
- `builders/agent_builder/model_concern.rb:58-66`

**Fix:** Convert type-based dispatch to pattern matching.

---

### 25. Verbose Method Names

**Problem:** Some method names could be simplified.

| Current | Suggested |
|---------|-----------|
| `validate_required_attributes!` | `validate_attributes!` |
| `strip_html_from_results` | `strip_html` or `clean_results` |
| `extract_and_format_value` | `format_value` |

**Status:** Low priority - existing names are clear.

---

### 26. Test Quality: Implementation Detail Testing

**Problem:** Some tests verify method calls rather than behavior.

**Example in `agents/agent_spec.rb:25-32`:**
```ruby
expect(Smolagents::RactorExecutor).to have_received(:new)
```

**Better:** Test observable behavior, not internal implementation.

---

## Completed Items (Previous Passes)

### P0 Critical (Completed)
- ✅ MixedRefinementCompleted added to events/mappings.rb (handlers can now subscribe)
- ✅ Repetition types extracted to types/repetition.rb (RepetitionResult, RepetitionConfig)
- ✅ IncrementalExecution spec created (spec/smolagents/executors/incremental_execution_spec.rb)
- ✅ Repetition types spec created (spec/smolagents/types/repetition_spec.rb)
- ✅ DSL callback names fixed (on_model_change, on_queue_wait now match docs)
- ✅ GoalAbandoned registry entry removed (event class already removed)

### P1 Architecture Consistency (All Fixed)
- ✅ InlineTool now inherits from Tool
- ✅ ManagedAgentTool uses symbol keys
- ✅ Builder `check_frozen!` added to all 22 methods
- ✅ Event handler naming mismatches fixed
- ✅ Tool isolation events added to registry
- ✅ Model adapter signatures standardized
- ✅ GoalAbandoned event removed (truly dead code)

### P2 Code Quality (All Fixed)
- ✅ README.md documentation updated
- ✅ CLAUDE.md formatting methods corrected

### P3 Polish (Completed)
- ✅ Magic numbers extracted to named constants
- ✅ Frozen string literal confirmed as disabled per project style

---

## Architecture Strengths (No Action Needed)

- **Type system:** 81 Data.define types with excellent support infrastructure
- **Event system:** 40+ events, proper Emitter/Consumer pattern
- **Executor abstraction:** All code through executor, no direct eval
- **Builder pattern:** Lazy model evaluation, immutable configs
- **Test suite:** 13,600+ examples, 96.69% coverage, zero RuboCop violations
- **Zero circular dependencies:** Clean concern layering

---

## Implementation Order

1. **Week 1:** P0 items (blocks future work)
   - Extract repetition types from concern
   - Add MixedRefinementCompleted mapping
   - Remove dead Goal abandonment code
   - Fix DSL callback names
   - Add incremental_execution tests

2. **Week 2:** P1 items (high impact)
   - Split AgentConfig type
   - Fix Struct.new → Data.define
   - Consolidate retry logic
   - Add freeze to numeric constants

3. **Week 3:** P1 items (architecture gaps)
   - Add event emission to Models
   - Add event emission to Tools
   - Extract search message templates
   - Document FutureBase naming convention

4. **Week 4:** P2 items (code quality)
   - Standardize lambda syntax
   - Fix model adapter signatures
   - Add Ractor lazy tests
   - Add orchestrator tests

5. **Ongoing:** P3 items (polish)
   - Convert to endless methods where beneficial
   - Add pattern matching where appropriate
   - Simplify verbose method names
