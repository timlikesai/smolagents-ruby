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
- `ToolOutput` (type) - model for tool execution results
- `ToolResult` (module with 5 sub-files) - operations on results

The distinction between these is unclear to newcomers.

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
| `react_loop/execution.rb` | 240 | Core execution logic |
| `errors.rb` | 225 | Error definitions |
| `anthropic_model.rb` | 216 | Model adapter |
| `models/queue/dead_letter.rb` | 216 | Queue handling |
| `fiber_execution.rb` | 207 | Fiber execution |

**Priority candidates for splitting:**
1. `search_tool/configuration.rb` - Extract to builder pattern
2. `react_loop/execution.rb` - Split by phase (setup/run/complete)

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

Five separate `*fiber_execution.rb` files:
- `executors/fiber_execution.rb`
- `executors/incremental_execution.rb`
- `executors/ractor_lazy/fiber_executor.rb`
- `tools/managed_agent/fiber_execution.rb`
- `concerns/agents/react_loop/fiber_execution.rb`

Each handles similar concerns (batching, scheduling, result collection) but in isolation.

**Consideration:** Extract common fiber execution patterns into shared utility.

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

The ReAct loop spans 11 files in nested concerns:
```
react_loop/
├── completion.rb
├── control.rb (+ 5 sub-modules)
├── core.rb
├── error_handling.rb
├── execution.rb (240 lines)
├── fiber_consumption.rb
├── fiber_execution.rb
├── repetition.rb (+ 3 sub-modules)
├── run_entry.rb
└── setup.rb
```

**Consideration:** Consolidate into 3-4 larger files organized by phase.

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

---

## Notes

- No "Enhanced*", "Advanced*", "Improved*" class names found - naming is appropriately direct
- Directory names follow Ruby snake_case convention correctly
- Tool naming is consistent (`*_search.rb` pattern for search tools)
- The 100-line violations are mostly in data-heavy or core files where splitting may add complexity
