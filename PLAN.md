# Cleanup & Organization Plan

**Generated:** 2026-01-24
**Branch:** feature/tool-future-lazy-eval
**Status:** New comprehensive audit complete

---

## Executive Summary

Comprehensive codebase audit identified **160+ issues** across 12 categories. The codebase is architecturally sound (95/100 reinforcement, excellent type system), but has accumulated organizational debt in file sizes, test coverage, and legacy code.

**Key Metrics:**
- 73+ files exceed 100-line limit (project rule violation)
- 369/599 lib files lack test coverage (61.6% untested)
- 16+ methods use conditional-in-name anti-pattern
- 7 code duplication patterns need consolidation
- 9+ files with backwards-compat shims (no-legacy-code violation)
- 7 events unmappable in event system

---

## P0: Critical Foundation (Do First - Prevents Future Work)

### 1. Split Oversized Core Files

These files block proper module organization and violate the 100-line rule:

| Priority | Lines | File | Action |
|----------|-------|------|--------|
| P0.1 | 355 | `lib/smolagents/dsl.rb` | Split into `dsl/agents.rb`, `dsl/models.rb`, `dsl/teams.rb`, `dsl/pipelines.rb` |
| P0.2 | 348 | `events/registry/built_in.rb` | Distribute to per-domain event files |
| P0.3 | 326 | `concerns/registrations.rb` | Split by concern category (agents/, formatting/, resilience/) |
| P0.4 | 275 | `tools/search_tool/configuration.rb` | Extract per-provider config modules |
| P0.5 | 242 | `builders/team_builder.rb` | Extract TeamBuilder concerns |

**Why First:** Large files create merge conflicts, make navigation difficult, and violate project conventions. Splitting enables parallel work.

### 2. Fill Critical Test Coverage Gaps

**Completely untested core features (0% coverage):**

| Directory | Files | Impact |
|-----------|-------|--------|
| `tools/result/` | 5 | Core result handling |
| `tools/managed_agent/` | 4 | Agent spawning feature |
| `tools/ruby_interpreter/` | 5 | Code execution |
| `types/callbacks/` | 5 | Event system |
| `types/chat_message/` | 4 | Core message types |
| `types/execution_outcome/` | 4 | Execution tracking |
| `testing/` | 10 | MockModel and test utilities |
| `builders/` (sub-modules) | 11 | DSL builder methods |

**Why First:** Untested code is unsafe to refactor. Tests must exist before any cleanup work.

### 3. Fix Event System Registry/Mappings Divergence

**Impact:** Breaks event subscription, handlers don't fire

| Issue | Details |
|-------|---------|
| `step_complete` docs wrong | Says `[step, context]` but actual fields are `[step_number, outcome, observations]` |
| `tool_complete` docs wrong | Says `[tool_call, result]` but actual is `[request_id, tool_name, result, observation, is_final]` |
| 7 events unmappable | `agent_launch`, `agent_progress`, `agent_complete`, `tool_call`, `tool_initialized`, goal events |
| `ToolRetrying` undefined | Emitted with `defined?()` guard but event class never defined |

**Files:** `events/registry/built_in.rb` (31 events) vs `events/mappings.rb` (only 24 mapped)

### 4. Remove Deprecated/Legacy Code

**Impact:** Direct violation of project's zero-tolerance no-legacy-code rule

**Files with backwards-compat shims (delete these):**
- `types/steps/null_step.rb:54-56` - `alias_method :is_final_answer` marked "(deprecated)"
- `tools/tool_formatter.rb:86` - `:code` format "alias for backwards compat"
- `concerns/api/http.rb` - "Re-export constants for backwards compatibility"
- `concerns/sandbox/ruby_safety.rb` - "Re-export types/allowlists for backward compatibility"
- `concerns/agents/evaluation.rb` - "Re-export constants for backwards compatibility with specs"
- `concerns/agents/evaluation/step_protocol.rb` - "Provides fallbacks for legacy ActionStep compatibility"
- `testing/mock_call.rb:33-38` - "Hash-style access for backwards compatibility"
- `models/litellm_model.rb` - "For backwards compatibility - expose PROVIDERS"
- `models/openai/cloud_providers.rb` - "Legacy accessors for backwards compatibility"

### 5. Consolidate Code Duplication

**Immediate consolidation needed:**

| Duplication | Files | Action |
|-------------|-------|--------|
| ToolFuture (200+ lines) | `executors/tool_future.rb`, `executors/ractor_lazy/tool_future.rb` | Extract shared `FutureBase` mixin |
| UTF-8 sanitization | `http/response_handling.rb`, `concerns/parsing/json.rb` | Extract to `Concerns::StringSanitization` |
| Frozen state checking | `builders/base.rb`, `config/configuration/freezable.rb` | Create shared `Concerns::Freezable` |
| Result formatting | `tools/support/formatted_result.rb`, `concerns/formatting/results/formatting.rb` | Unify under single `ResultFormatting` concern |
| partition_tool_args | `builders/agent_builder/tools_concern.rb:43-52`, `builders/tool_resolution.rb:44-53` | Extract to shared module |
| Image content building | `models/openai/message_formatter.rb:38-42`, `models/anthropic/message_formatter.rb:37-40` | Create `ImageContentFormatter` concern |
| Tool schema formatting | `models/openai/request_builder.rb:59-73`, `models/anthropic/request_builder.rb:51-63` | Extract common tool extraction to base |

**Why First:** Duplication causes bugs to be fixed in one place but not another.

---

## P1: Architecture Consistency (High Impact)

### 4. Fix Conditional-in-Method-Name Anti-Pattern

**16+ methods embed conditionals in names** - this violates SRP and makes testing harder:

```ruby
# Current (bad):
execute_planning_step_if_needed(task, step, number)

# Better:
execute_planning_step(task, step, number)  # Caller checks conditions
```

**Files to refactor:**
- `concerns/agents/planning.rb:45,54,72,85` - `execute_*_if_needed`, `build_*_messages`
- `concerns/agents/early_yield.rb:63` - `execute_parallel_with_early_yield`
- `concerns/agents/mixed_refinement.rb:38` - `execute_*_if_needed`
- `concerns/agents/react_loop/setup.rb:76` - `create_*_if_enabled`
- `concerns/agents/react_loop/completion.rb:24` - `complete_*_if_enabled`
- `concerns/resilience/circuit_breaker.rb:123` - `emit_*_if_needed`

### 5. Fix Get/Set Prefix Anti-Patterns

**Java-style prefixes that should use Ruby conventions:**

| File | Current | Should Be |
|------|---------|-----------|
| `config/configuration.rb:107` | `get_model(name)` | `model(name)` or `find_model(name)` |
| `http/requests.rb:68` | `set_post_body` | `post_body=` |
| `concerns/agents/reflection_memory/analysis.rb:49` | `get_relevant_reflections` | `relevant_reflections` |
| `concerns/agents/mixed_refinement.rb:87` | `get_feedback` | `feedback` |
| `concerns/agents/self_refine/feedback.rb:23` | `get_refinement_feedback` | `refinement_feedback` |

### 6. Standardize Flexible Input Handling

**4 different patterns exist for handling flexible method inputs:**
- `dispatch_by_type()` in memory_concern.rb
- `resolve_value_or_toggle()` pattern
- `resolve_boolean()` in setters_concern.rb
- Custom inline logic in refine_concern.rb

**Action:** Consolidate into single `Support::FlexibleInput` module with consistent patterns.

### 7. Split Oversized Concern Files

**Files exceeding 100-line limit in concerns/:**

| Lines | File | Action |
|-------|------|--------|
| 216 | `models/queue/dead_letter.rb` | Extract queue state management |
| 214 | `execution/code_execution.rb` | Extract hint generation (~30 LOC) |
| 204 | `registry.rb` | Extract documentation generator |
| 165 | `formatting/output.rb` | Split: markdown, table, serialization |
| 165 | `agents/spawn_restrictions.rb` | Extract spawn validator |
| 139 | `agents/mixed_refinement.rb` | At limit - monitor |
| 138 | `agents/completion_validation.rb` | At limit - monitor |
| 137 | `agents/early_yield.rb` | At limit - monitor |
| 135 | `agents/react_loop.rb` | Simplify to include pattern only |
| 133 | `agents/react_loop/execution/loop.rb` | Move to `agents/step_iteration.rb` |

### 8. Fix Model Adapter Inconsistencies

**Streaming method signatures differ:**
- OpenAI: `&block` + `unless block`
- Anthropic: `&` + `unless block_given?`
- **Fix:** Standardize on `unless block_given?` (matches base class)

**Error handling differs:**
- Anthropic warns about unsupported `response_format`
- Different `build_params` signatures
- **Fix:** Standard adapter interface for handling provider constraints

**Client initialization differs:**
- OpenAI uses factory method `build_client`
- Anthropic uses inline instantiation
- **Fix:** Both use factory methods

### 9. Fix Concern Boundary Issues

| Issue | File | Action |
|-------|------|--------|
| WorkingMemoryState embedded | `concerns/agents/working_memory.rb` | Extract 56-line Data type to `types/working_memory_state.rb` |
| GoalAwareYield duplicates EarlyYield | `concerns/agents/goal_aware_yield.rb:50-53` | Delegate to EarlyYield, don't reimplement |
| Evaluation over-granular | 4 sub-concerns in `evaluation/` | Merge Prompts + StepProtocol → `Protocol` |
| ContextOrchestration implicit include | `concerns/agents/context_orchestration.rb` | Document MessageFormatting dependency |

---

## P2: Code Quality (Medium Impact)

### 8. Add Missing Type Definitions

**ObservabilityContext uses plain hashes that should be types:**

```ruby
# Current (concerns/monitoring/observability_context.rb:93-100):
@sub_agent_runs << {
  agent_name:, token_usage:, step_count:, duration:, outcome:,
  timestamp: Time.now.utc.iso8601
}

# Should be:
SubAgentRecord = Data.define(:agent_name, :token_usage, :step_count, :duration, :outcome, :timestamp)
```

Also extract: `ToolInvocationCount`, `ExtractedContext`

### 9. Fix Error Handling Gaps

**Silent error swallowing (returns nil without logging):**
- `discovery/http_client.rb:39-40` - Network errors return nil silently

**Use custom errors consistently:**
- Tool validation uses `ArgumentError` - should use `ArgumentValidationError`

### 10. Consolidate Over-Extracted Concerns

**Tiny files that should be merged:**

| Directory | Files | Action |
|-----------|-------|--------|
| `agents/react_loop/control/` | 6 files (28-62 LOC each) | Merge into 2-3 modules |
| `agents/react_loop/repetition/` | 3 files (29-67 LOC each) | Merge detectors + guidance |
| `models/health/` | `types.rb` (50 LOC) + `thresholds.rb` (36 LOC) | Merge into `health.rb` |

### 11. Document Undocumented DSL Features

**Missing from CLAUDE.md:**

| Feature | Location | Status |
|---------|----------|--------|
| `summarizer_model` config | `.observe()` block parameter | Implicit only |
| `allowed_tools:` parameter | `.can_spawn()` | Not documented |
| ModelBuilder DSL | `.with_retry()`, `.with_fallback()`, etc. | Separate API |
| Additional event handlers | `on_control_yielded`, `on_isolation`, etc. | Not documented |
| `.persona()` as `.as()` alias | Specialization | Mentioned but not explicit |
| `.team`, `.ralph_loop()` | DSL module | Missing entirely |

### 12. Fix DSL/Builder Inconsistencies

| Issue | Details | Action |
|-------|---------|--------|
| 11 methods not in `.help` | `.tools`, `.tool`, `.observe`, `.executor`, `.logger`, `.authorized_imports`, `.run`, `.run_fiber`, `.build`, `.managed_agent`, `.on` | Add `register_method` calls |
| TeamBuilder.planning differs | Only `planning(interval:)` vs AgentBuilder's flexible pattern | Align APIs |
| InlineTool not Tool subclass | Reimplements Tool interface separately | Inherit from Tool or document why |

### 13. Expand Test Edge Cases

**Current error coverage: 15.6%** (1,091/6,960 tests)

**Missing test scenarios:**
- Formatting with nested/circular/large data structures
- Concurrent retry scenarios
- Circuit breaker state transitions
- Conflicting configuration combinations
- Tools with complex nested inputs

**Additional untested modules:**
- `concerns/parsing/json.rb`, `html.rb`, `xml.rb`, `critique.rb`
- `http/user_agent/builder.rb`, `sanitizer.rb`
- `concerns/support/browser_mode.rb`, `gem_loader.rb`

### 14. Add Missing Type Validations

| Type | Missing Validation |
|------|-------------------|
| `InputSchema` | No MCP spec validation |
| `SpawnConfig` | No allowed values validation |
| `Goal` | No status validation |

**Also:** Standardize on symbols internally, coerce at boundaries (currently mixed symbol/string keys)

---

## P3: Polish & Refinement (Low Priority)

### 15. Fix Awkward Predicate Naming

| File | Current | Better |
|------|---------|--------|
| `concerns/agents/completion_validation.rb:83` | `should_validate_goal_alignment?` | `validate_goal_alignment?` |
| `orchestrators/ralph_loop.rb:135` | `should_stop?` | `stop?` or `stopped?` |
| `concerns/resilience/health_routing.rb:39` | `should_skip_unhealthy?` | `skip_unhealthy?` |
| `types/steps/action_step.rb:45` | `is_final_answer` field | `final_answer` (accessor `final_answer?` is correct) |

### 16. Address Verbose Method Names

**Over-compound names that could be simpler:**

| Current | Simpler |
|---------|---------|
| `validate_and_sanitize_arguments` | `sanitize_arguments` |
| `map_results_with_link_builder` | `format_results` |
| `mock_model_for_single_step` | `mock_single_step` |

### 17. Update Pattern Matching Usage

**Files using case/when where pattern matching would be cleaner:**
- `builders/support/flexible_input.rb:38-47, 94-105, 121-129`

### 18. Add Method Stubs for Discoverability

ValidatedSetter generates methods dynamically (`executor`, `logger`, `authorized_imports`) - add explicit stubs for IDE/documentation visibility.

### 20. Single TODO Marker

**File:** `tools/visit_webpage.rb:28`
```ruby
# TODO: Consider https://github.com/microsoft/markitdown if Ruby support is added
```
**Status:** Legitimate enhancement note - no action needed.

### 21. Executor System Gaps

| Issue | Details | Priority |
|-------|---------|----------|
| `timeout` parameter ignored | Accepted but never used in `executor.rb` | Low |
| `memory_mb` parameter ignored | Accepted but never used | Low |
| No stdlib whitelist | Safe stdlib blocked entirely (JSON.parse, Time.now, Math.sqrt) | Medium |

---

## Architecture Strengths (No Action Needed)

The audit confirmed these areas are excellent:

- **Type system:** 50 Data.define types, consistently used, proper pattern matching
- **Event system:** 168 emit points, proper inclusion of Emitter/Consumer
- **Executor abstraction:** All code execution through executor, no direct eval
- **Builder pattern:** All agents through builders, lazy model evaluation
- **Concern composition:** Properly included, no inline duplication
- **Exception hierarchy:** Well-structured with proper inheritance

**Note:** Legacy/deprecated code exists (see P0.4) - needs cleanup per no-legacy-code rule.

---

## Previous Work (Completed)

### P0-P2 from Previous Session ✅
1. Removed CodeFiber dead code (79 lines)
2. Fixed RateLimitExceeded hierarchy
3. Deleted validate_children_limit!
4. Fixed silent error swallowing in OpenAI parser
5. Removed deprecated aliases
6. Enforced builder usage (5 files)
7. Moved Data classes to types/
8. Added 320 new tests (HTTP security, ToolFuture)

### P3 from Previous Session ✅
- Removed unused ToolResult aliases
- Documented `.observe()` mode options
- Renamed `define_tool` to `create`
- Created searxng_search_spec.rb (96 tests)
- Created arxiv_search_spec.rb (62 tests)
- Documented event handler convenience methods

---

## Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Files > 100 lines | 73+ | 0 (except RuboCop excludes) |
| Test coverage | 38.3% | 80%+ |
| Error case coverage | 15.6% | 50%+ |
| Code duplication spots | 7 | 0 |
| Conditional-in-name methods | 16+ | 0 |
| Legacy/deprecated code files | 9+ | 0 |
| Event mapping gaps | 7 events | 0 |
