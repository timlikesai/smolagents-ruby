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

### 1. Concern Boundary Violations (17 files exceed 100-line limit)

**Problem:** CLAUDE.md specifies "Modules ≤100 lines" but 17 concerns violate this rule.

**Files (by line count):**

| File | Lines | Recommendation |
|------|-------|----------------|
| `concerns/agents/react_loop/repetition.rb` | 166 | ✅ Types extracted to `types/repetition.rb` (was 173, now 166) |
| `concerns/resilience/circuit_breaker.rb` | 155 | Acceptable (Stoplight integration requires cohesion) |
| `concerns/agents/mixed_refinement.rb` | 143 | Review if CritiqueParsing can be inlined |
| `concerns/agents/completion_validation.rb` | 138 | Extract `ValidationRejection` to `types/` |
| `concerns/formatting/structure.rb` | 138 | Split describe_* methods into sub-concerns |
| `concerns/agents/react_loop/execution/loop.rb` | 137 | Review for extraction opportunities |
| `concerns/agents/react_loop.rb` | 137 | Documentation-heavy, acceptable |
| `concerns/agents/early_yield.rb` | 137 | Review speculative execution logic |
| `concerns/agents/async.rb` | 134 | Review fiber scheduler detection |
| `concerns/resilience/tool_retry.rb` | 133 | Consider merging with `retryable.rb` |
| `concerns/agents/planning.rb` | 121 | Already split via `planning/divergence.rb` |
| `concerns/agents/health.rb` | 120 | Review health status tracking |
| `concerns/agents/planning/divergence.rb` | 115 | Planning-specific, acceptable |
| `concerns/agents/goal_aware_yield.rb` | 115 | Review goal tracking logic |
| `concerns/isolation/tool_isolation.rb` | 114 | Resource enforcement complexity |
| `concerns/agents/goal_driven_loop.rb` | 110 | Goal-aware iteration logic |
| `concerns/agents/observation_router.rb` | 124 | Review formatting mode dispatch |

**Fix Priority:** Start with `repetition.rb` (largest) - extract Data types to `types/` directory.

---

### 2. ~~Event System: MixedRefinementCompleted Missing from Mappings~~ ✅ FIXED

~~**Problem:** Event is defined and emitted but NOT in mappings - handlers can't subscribe.~~

**Status:** Fixed - `mixed_refinement_complete` mapping added to `lib/smolagents/events/mappings.rb`

---

### 3. Dead Code: Goal Abandonment System

**Problem:** Partially implemented system with unused code.

**Files & Issues:**

| Location | Issue |
|----------|-------|
| `events/registry/built_in.rb:383` | `:goal_abandoned` registered but NO event class exists |
| `types/goal.rb:130` | `Goal.abandon(reason:)` - never called in production |
| `types/goal.rb:105` | `Goal#abandoned?` - never used in production |
| `types/goal.rb:111` | `Goal#closed?` - never called anywhere |

**Fix:** Remove all abandoned-related code OR implement the feature fully.

---

### 4. DSL Callback Name Mismatches

**Problem:** Documentation shows different method names than implementation.

| Documented (CLAUDE.md) | Implemented | File |
|------------------------|-------------|------|
| `.on_model_change { }` | `on_model_changed` | `builders/model_builder/callbacks.rb:15` |
| `.on_queue_wait { }` | `on_queue_request_started` | `builders/model_builder/callbacks.rb:16` |

**Fix:** Either rename implementations to match docs OR update CLAUDE.md.

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

**Problem:** Event defined but never emitted anywhere - dead code.

**File:** `lib/smolagents/events.rb:29`

**Status:** Dead code - monitoring tools cannot track tool calls before execution.

**Fix:** Either implement emission in executor OR remove event definition.

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

### 8. Ruby 4.0 Idiom: Struct.new vs Data.define

**Problem:** 2 files still use deprecated `Struct.new` instead of `Data.define`.

| File | Line | Current | Should Be |
|------|------|---------|-----------|
| `utilities/pattern_matching/final_answer.rb` | 9 | `Struct.new(:depth, ...)` | `Data.define` |
| `concerns/agents/self_refine/loop.rb` | 27 | `RefinementState = Struct.new(...)` | `Data.define` |

**Note:** Both have RuboCop disables. Document why mutability is needed OR convert to Data.define with copy-on-write.

---

### 9. Naming: Underscore-Prefixed Public API Methods

**Problem:** FutureBase uses `_prefix` naming for public API methods.

**Files:**
- `executors/future_base.rb`: `_resolve!`, `_reject!`, `_resolved?`, `_pending?`, `_result`, `_error`, `_future?`
- `executors/ractor_lazy/tool_future.rb`: `_cancelled?`, `_cancel!`, `_with_timeout`, etc.
- `executors/ractor_lazy/future_combinators.rb`: `_ensure_all_resolved!`, `_ensure_any_resolved!`

**Issue:** Underscore prefix signals "private/internal" but these ARE the public API.

**Fix:** Either remove underscores OR document this is intentional for duck-typing and add `@api private`.

---

### 10. Code Duplication: Search Tool Message Templates

**Problem:** ArxivSearch and WikipediaSearch duplicate message template patterns.

**Both define:**
```ruby
empty_message <<~MSG
  No [Source] [content type] found for this query.
  NEXT STEPS: - Try broader/different search terms...
MSG

next_steps_message <<~MSG
  NEXT STEPS: - Extract/summarize relevant info...
MSG
```

**Fix:** Create `SearchToolMessageTemplates` mixin with customizable templates.

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

### 13. Constants: Unfrozen Numeric Constants (5 instances)

**Problem:** Numeric constants without `.freeze` (inconsistent with project patterns).

| File | Constant |
|------|----------|
| `tools/visit_webpage.rb:7` | `MAX_CONTENT_BYTES = 40_000` |
| `tools/visit_webpage.rb:10` | `DEFAULT_TIMEOUT_SECONDS = 20` |
| `tools/duckduckgo_search.rb:33` | `MIN_VALID_RESPONSE_LENGTH = 1_000` |
| `types/working_memory_state.rb:26` | `MAX_FINDINGS = 3` |
| `types/working_memory_state.rb:29` | `MAX_BLOCKERS = 2` |

**Note:** Ruby technically doesn't mutate integers, but `.freeze` is idiomatic for constants.

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
