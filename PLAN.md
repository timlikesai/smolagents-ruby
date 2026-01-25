# Cleanup & Organization Plan

**Generated:** 2025-01-24
**Branch:** feature/tool-future-lazy-eval
**Status:** P0 Complete, P1-P3 Pending

---

## P1: Architecture Consistency

### Tool System: 5 Different Registration Patterns

| Pattern | Tools | Files |
|---------|-------|-------|
| Direct class definition | FinalAnswerTool, VisitWebpageTool, UserInputTool | `tools/final_answer.rb`, `tools/visit_webpage.rb` |
| DSL configuration | SearchTool and all subclasses | `tools/search_tool.rb`, `tools/google_search.rb` |
| Data.define struct | InlineTool | `tools/inline_tool.rb:37-61` |
| Runtime extraction | MCPTool | `tools/mcp_tool.rb:47-77` |
| attr_reader + custom accessors | ManagedAgentTool | `tools/managed_agent.rb:40-52` |

**Additional Issues:**
- ManagedAgentTool uses **string keys** (`"task"`) while others use **symbol keys** (`:url`)
- InlineTool bypasses Tool base class entirely - breaks interface contract
- SearchTool parameter validation bypasses base class validation

**Fix:**
1. Standardize all tools to `self.tool_name = ...` pattern
2. Make InlineTool inherit from Tool (not Data.define)
3. Ensure ManagedAgentTool uses symbol keys
4. Route SearchTool validation through base class

---

### Model Adapter Signature Inconsistencies

**8 categories of inconsistency between OpenAI and Anthropic adapters**

| Method | OpenAI | Anthropic |
|--------|--------|-----------|
| `build_client` | 2 params: `(api_base, timeout)` | 0 params: `()` |
| `build_params` | Keyword args, 6 params | Positional args, 5 params |
| `max_tokens` default | None (factory only) | 4096 enforced |
| Streaming resilience | `with_circuit_breaker` only | `with_circuit_breaker` only |
| `response_format` | Silently supported | Warns and ignores |

**Files:**
- `models/openai/request_builder.rb:21` vs `models/anthropic/request_builder.rb:17`
- `models/openai/request_builder.rb:38` vs `models/anthropic/request_builder.rb:29`
- `models/anthropic_model.rb:68` - `DEFAULT_MAX_TOKENS = 4096`

**Fix:**
1. Standardize `build_client` to same signature
2. Standardize `build_params` to keyword arguments
3. Add `DEFAULT_MAX_TOKENS` to Model base class or document why provider-specific

---

### Builder check_frozen! Inconsistency

**ModelBuilder.endpoint() missing check_frozen! call**

```ruby
# builders/model_builder/setters.rb:50
def endpoint(url) = with_config(api_base: url)  # Missing check_frozen!

# All other setters have it:
# builders/model_builder/setters.rb:20-24
def id(model_id)
  check_frozen!
  validate!(:id, model_id)
  with_config(model_id:)
end
```

**Fix:** Add `check_frozen!` to `endpoint()` method.

---

### Event System Gaps

**2 events defined but never emitted:**
- `GoalAbandoned`
- `ToolCallRequested`

**3 events missing from registry:**
- Tool isolation events (`tool_isolation_completed`, etc.)

**Convenience handler naming mismatches:**
- `on_model_change` vs actual event name
- `on_queue_wait` vs actual event name

**Fix:** Either emit these events or remove definitions. Add missing events to registry.

---

## P2: Code Quality

### Documentation vs Implementation Discrepancies

| Issue | Documentation | Implementation |
|-------|---------------|----------------|
| Method name | README: `.evaluate(on: :each_step)` | Code: `.evaluation(enabled:)` |
| Missing methods | CLAUDE.md: `format_system_message`, `format_user_message`, `format_tool_message` | **Not found in codebase** |

**Files:**
- `README.md:210` - Wrong method name
- `CLAUDE.md:212-213` - Documents non-existent methods

**Fix:** Update README to use `.evaluation()`. Remove or implement missing formatting methods.

---

### Type System Inconsistencies

**5 result types with inconsistent predicates:**

| Type | Predicate Style |
|------|-----------------|
| Some types | `success?` / `error?` |
| Others | `completed?` / `failed?` |

**8 types with missing validation:**
- Missing factory method validation
- Missing field presence validation

**3 types should be split:**
- AgentConfig (too many concerns)
- ModelConfig (too many concerns)
- ChatMessage (mixed responsibilities)

**2 types should be combined:**
- Refinement + MixedRefinement → single type with flag

---

## P3: Polish & Refinement

### Frozen String Literal Missing

**All 610 Ruby files missing `# frozen_string_literal: true`**

**Fix:** Add header to all files. Configure RuboCop to enforce.

---

### Magic Numbers Without Constants

| File | Line | Number |
|------|------|--------|
| `builders/model_builder.rb` | 20-24 | Port numbers: 1234, 11434, 8080, 8000 |
| `tools/visit_webpage.rb` | 53 | `40_000` bytes, `20` seconds |
| `builders/model_builder/reliability.rb` | 16, 40-41, 92 | `5`, `1.0`, `30.0`, `60` |

**Fix:** Extract to named constants with documentation.

---

### Naming Convention Issues

**18+ underscore-prefixed methods (Ruby convention is no underscore for private):**
- `_resolve!`, `_pending?`, etc.

**15+ validate_*! methods using bang for validation instead of mutation:**
- Ruby convention: bang (!) indicates mutation or danger

**Fix:** Review and rename where appropriate.

---

## Executor Limitations (Documented)

The executor accepts these parameters but they are not yet implemented:

- **`timeout`**: Accepted but execution timeout is not enforced
- **`memory_mb`**: Accepted but memory limits are not enforced
- **Tool execution**: Runs in main Ractor with no resource limits

These are accepted for API stability but have no effect until implemented.

---

## Architecture Strengths (No Action Needed)

The audit confirmed these areas are excellent:

- **Type system:** 50+ Data.define types, consistently used, proper pattern matching
- **Event system:** 168 emit points, proper inclusion of Emitter/Consumer
- **Executor abstraction:** All code execution through executor, no direct eval
- **Builder pattern:** All agents through builders, lazy model evaluation
- **Concern composition:** Properly included, no inline duplication
- **Exception hierarchy:** Well-structured with proper inheritance
- **No dead code:** Codebase is exceptionally clean - no unused methods, no TODO/FIXME for completed work
- **Test suite:** 13,600+ examples, 96%+ coverage, zero RuboCop violations
