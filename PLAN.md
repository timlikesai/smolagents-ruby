# Cleanup & Organization Plan

**Generated:** 2026-01-24
**Branch:** feature/tool-future-lazy-eval
**Status:** P0-P2 Complete, P3 Open

---

## Completed Work

### P0: Critical Foundation ✅
1. **Remove CodeFiber dead code** - Deleted 79 lines from fiber_execution.rb
2. **Fix RateLimitExceeded hierarchy** - Now extends Errors::AgentError
3. **Delete validate_children_limit!** - Removed unused method
4. **Fix silent error swallowing** - OpenAI parser returns error info instead of `{}`
5. **Remove deprecated aliases** - Deleted AgentToolCallError/AgentToolExecutionError

### P1: Architecture Consistency ✅
1. **Enforce builder usage** - 5 files converted to `Smolagents.agent.model { }.build` pattern
2. **Move Data classes to types/** - AsyncToolError, AsyncResult, EarlyYieldResult
3. **Key transformations** - NOT NEEDED (Utilities::Transform already exists)
4. **Role mapping** - NOT NEEDED (provider-specific by design)
5. **Tool formatting** - DEFERRED (6 lines, not worth complexity)

### P2: Code Quality ✅
1. **HTTP security tests** - 181 new tests across 4 spec files:
   - ssrf_protection_spec.rb, dns_rebinding_guard_spec.rb
   - connection_spec.rb, requests_spec.rb
2. **Outer ToolFuture tests** - 139 tests in tool_future_spec.rb
3. **Concern suffixes** - DEFERRED (high risk, low value)
4. **Naming conventions** - ACCEPTABLE AS-IS after analysis
5. **ToolFuture API asymmetry** - ACCEPTABLE (intentional architectural distinction)
6. **Model signatures** - DEFERRED (stylistic only)
7. **Builder .config private** - NOT POSSIBLE (Data.define design)

**Total: 320 new tests added, 7507 tests passing, 94.92% coverage**

---

## P3: Polish & Documentation (Open)

### 18. Remove Unused ToolResult Aliases
- `member?`, `to_ary`, `to_hash`, `to_str` in utility.rb
- `length`, `count`, `collect`, `slice` in collection.rb

### 19. Convert Data-Heavy Files to YAML
- `events/registry/built_in.rb` (354 lines)
- `concerns/registrations.rb` (326 lines)
- `tools/search_tool/configuration.rb` (275 lines)

### 20. Document `.observe()` Mode Options
- Add `:structure_only` to CLAUDE.md DSL docs

### 21. Update Case/When to Pattern Matching
- `tools/tool/schema.rb:72-81`
- `tools/speech_to_text/status.rb:29-31`

### 22. Rename `define_tool` to `create`
- `Tools.define_tool` → `Tools.create`

### 23. Add Missing Search Tool Tests
- SearxNG search tool
- ArxivSearchTool XML parsing edge cases

### 24. Document Event Handler Convenience Methods
- `.on_step`, `.on_task`, `.on_error`, etc.

### 25. Refactor Struct to Data.define
- `ParseState` in pattern_matching/final_answer.rb
- `RefinementState` in self_refine/loop.rb

### 26. Address TODO Comment
- `tools/visit_webpage.rb:28` markitdown TODO

---

## Large Files Reference

| Lines | File | Notes |
|-------|------|-------|
| 355 | `dsl.rb` | Split into focused modules |
| 354 | `events/registry/built_in.rb` | Convert to YAML |
| 326 | `concerns/registrations.rb` | Convert to YAML |
| 275 | `tools/search_tool/configuration.rb` | Per-provider configs |
| 242 | `builders/team_builder.rb` | Extract concerns |
