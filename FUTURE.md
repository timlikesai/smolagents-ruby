# Future Improvements

Observations and patterns identified during Phase 0 cleanup that warrant future consideration.

---

## Naming & Clarity

### Result Type Naming Confusion

Three related but distinct concepts:

| Type | Location | Purpose |
|------|----------|---------|
| `ExecutionResult` | `executors/` | Raw output from code execution (output, logs, error) |
| `ExecutionOutcome` | `types/` | Generic outcome with state machine semantics |
| `CodeOutcome` | `types/` | Code-specific outcome wrapping ExecutionResult |

The `Outcome` module (state constants) vs `ExecutionOutcome` (data type) naming is also potentially confusing.

**Potential simplification:**
- `ExecutionResult` → `CodeOutput` (what it actually is)
- `ExecutionOutcome` → `Outcome` (generic, but conflicts with module)
- Keep `CodeOutcome` as renamed

### Tool Result Abstractions

Two parallel implementations:
- `ToolOutput` (type) - Data.define for tool execution tracking (id, observation, is_final_answer)
- `ToolResult` (class with 5 sub-files) - Chainable wrapper with fluent operations

**Analysis:**
- `ToolOutput` is barely used (only in async error handling)
- `ActionStep.action_output` holds the actual result (can be any type including ToolResult)
- The raw immutable output could just be a field on `ToolResult`

**Potential consolidation:**
- Remove `ToolOutput` type (absorb into ToolResult or ActionStep)
- `ToolResult` already has immutable `@data` field - this IS the raw output
- Simplify to: tools return `ToolResult`, steps record `action_output`

---

## Files Exceeding 100-Line Limit

These files exceed the 100-line module guideline:

| File | Lines | Notes |
|------|-------|-------|
| `dsl.rb` | 355 | Core DSL, may be acceptable |
| `events/registry/built_in.rb` | 313 | Data-heavy (event definitions) |
| `concerns/registrations.rb` | 300 | Registration definitions |
| `search_tool/configuration.rb` | 275 | Could be split into builder |
| `team_builder.rb` | 242 | Builder complexity |
| `errors.rb` | 225 | Error definitions |
| `anthropic_model.rb` | 216 | Model adapter |
| `models/queue/dead_letter.rb` | 216 | Queue handling |
| `fiber_execution.rb` | 207 | Fiber execution |

**Priority candidates for splitting:**
1. `search_tool/configuration.rb` - Extract to builder pattern

---

## Directory Structure

### Deep Nesting (14 levels)

Some paths are deeply nested:
```
concerns/resilience/rate_limiter/strategies/token_bucket.rb
concerns/agents/react_loop/repetition/detectors.rb
concerns/agents/react_loop/control/sync_handler.rb
```

Module paths become unwieldy:
```ruby
Smolagents::Concerns::Resilience::RateLimiter::Strategies::TokenBucket
```

**Consideration:** Flatten rate limiter strategies to `Concerns::RateLimiting`.

### Single-File Directories

These directories contain only one file:
- `observation_router/summarizer.rb` - Could merge into parent

---

## Pattern Inconsistencies

### Multiple Fiber Execution Implementations

Five separate fiber-related files serve **distinct layers** (not duplication):

| File | Layer | Purpose |
|------|-------|---------|
| `react_loop/fiber_execution.rb` | Agent | Interactive sessions with `run_fiber()`, yields ActionSteps |
| `executors/fiber_execution.rb` | Code | Tool batching with ToolFutures, lazy evaluation |
| `executors/ractor_lazy/fiber_executor.rb` | Code | Ractor-based isolation for code execution |
| `tools/managed_agent/fiber_execution.rb` | Tool | Subagent coordination, bubbles control requests |
| `executors/incremental_execution.rb` | Code | Step-by-step code execution |

**Status:** Not duplication - each handles a different execution context. No consolidation needed.

### Support Folder Inconsistency

"Support" folders used inconsistently:
- `builders/support/` (5 files + 2 sub-dirs)
- `concerns/support/` (helper files)
- `models/support/` (1 file)
- `tools/support/` (3 files)
- `types/support/` (utilities)
- `builders/base/` (similar purpose, different name)

---

## SearchTool Complexity

The search tool has become a mini-framework:
- `search_tool.rb` - Main tool
- `search_tool/configuration.rb` - 275 lines
- `search_tool/response_parser.rb` - 188 lines
- `search_tool/request_builder.rb`

Plus 11 individual search provider implementations.

**Consideration:** Extract configuration into a builder with simpler public API.

---

## ReActLoop Complexity

The ReAct loop spans multiple files in nested concerns:
```
react_loop/
├── completion.rb
├── control.rb (+ 5 sub-modules)
├── core.rb
├── error_handling.rb
├── execution.rb (composes Loop + Monitoring)
│   ├── execution/loop.rb (~115 lines)
│   └── execution/monitoring.rb (~85 lines)
├── fiber_consumption.rb
├── fiber_execution.rb
├── repetition.rb (+ 3 sub-modules)
├── run_entry.rb
└── setup.rb
```

**Status:** Split `execution.rb` into `loop.rb` (step iteration) and `monitoring.rb` (events/observability) for Phase 4 readiness.

---

## Positive Patterns to Maintain

These patterns are well-executed:

1. **Concerns organization** - Clean separation of cross-cutting concerns
2. **Builder DSL pattern** - Consistent use of `Data.define` with fluent builders
3. **Type system** - Excellent use of immutable Data types
4. **Sub-module organization** - When a folder has 3+ related files, it's well-structured
5. **Context Orchestration** - Clean provider-based architecture with layered context

---

## Quick Wins Completed (Phase 0)

- [x] Renamed `ExecutorExecutionOutcome` → `CodeOutcome`
- [x] Removed dead `Planning::Injection` module
- [x] Removed dead `ReflectionMemory::Injection` module
- [x] Removed unused `inject_all_before_last_user` helper
- [x] Simplified `StepContext` to provider data source
- [x] Standardized provider state access to use public APIs
- [x] Split `react_loop/execution.rb` into `loop.rb` + `monitoring.rb` (Phase 4 prep)

---

## Notes

- No "Enhanced*", "Advanced*", "Improved*" class names found - naming is appropriately direct
- Directory names follow Ruby snake_case convention correctly
- Tool naming is consistent (`*_search.rb` pattern for search tools)
- The 100-line violations are mostly in data-heavy or core files where splitting may add complexity
