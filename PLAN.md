# Cleanup & Organization Plan

**Generated:** 2025-01-24
**Branch:** feature/tool-future-lazy-eval
**Status:** P0-P3 Complete (Type System analysis documented for future)

---

## P1: Architecture Consistency

### 1. Tool System: InlineTool Bypass (HIGH) ✅ FIXED

**Problem:** InlineTool was a `Data.define`, NOT a Tool subclass.

**Fix:** InlineTool now inherits from Tool:
- Gets type validation via Tool::Validation module
- Gets telemetry instrumentation via Tool::Execution
- Disables danger detection (developer-defined = trusted code)
- Preserves block-based execution and instance-level configuration

---

### 2. Tool System: ManagedAgentTool String Keys (HIGH) ✅ FIXED

**Problem:** Uses `{ "task" => ... }` instead of `{ task: ... }`

**File:** `tools/managed_agent.rb` - `initialize_io_schema` method

**Fix:** Change to symbol key.

---

### 3. Builder check_frozen! Missing (HIGH) ✅ FIXED

**Problem:** 22 setter methods were missing `check_frozen!` call.

**Fix:** Added `check_frozen!` to all 22 methods:
- ModelBuilder: 8 methods (endpoint, at, with_health_check, with_retry, with_fallback, with_circuit_breaker, with_queue, prefer_healthy)
- TeamBuilder: 2 methods (model, coordinator)
- TestBuilder: 12 methods (extracted to setters.rb concern)
- AgentBuilder: 1 method (sync_events)

---

### 4. Event Handler Naming Mismatches (HIGH) ✅ FIXED

**Problem 1:** `on_model_change` handler but event is `:model_changed`
- File: `builders/model_builder/callbacks.rb:15`

**Problem 2:** `on_queue_wait` handler but no such event exists
- File: `builders/model_builder/callbacks.rb:16`
- Queue events are `:queue_request_started` and `:queue_request_completed`

**Fix:** Rename handlers to match actual events.

---

### 5. Tool Isolation Events Missing from Registry (MEDIUM) ✅ FIXED

**Problem:** These events are emitted and mapped but not in registry:
- `ToolIsolationStarted`
- `ToolIsolationCompleted`
- `ResourceViolation`

**File:** `events/registry/built_in.rb`

**Fix:** Add register calls for all 3 events.

---

### 6. Model Adapter Signature Inconsistencies (MEDIUM) ✅ FIXED

**Problem:** OpenAI and Anthropic adapters had incompatible signatures.

**Fix:** Standardized both adapters to use keyword arguments:
- `build_client(api_base: nil, timeout: nil)` in both
- `build_params(messages:, stop_sequences:, temperature:, max_tokens:, tools:)` in both
- Added RuboCop disable for unused api_base in Anthropic (kept for interface consistency)

---

### 7. Never-Emitted Events (LOW) ✅ FIXED

**Problem:** 2 events defined but never emitted.

**Resolution:**
- `GoalAbandoned` - **Removed** (truly dead code, never used anywhere)
- `ToolCallRequested` - **Kept** (heavily used in tests, valid API for user emission)

---

## P2: Code Quality

### Documentation vs Implementation Discrepancies ✅ FIXED

- README.md: `.evaluate(on: :each_step)` → `.evaluation(enabled:)`
- CLAUDE.md: Fixed formatting method names to match actual implementation

---

### Type System Inconsistencies (Future Work)

Analysis completed, documented for future refactoring:
- 5 result types with inconsistent predicates (`success?`/`error?` vs `completed?`/`failed?`)
- 8 types with missing validation (ToolCall, TokenUsage, Timing, etc.)
- 3 types should be split (AgentConfig→5, ModelConfig→3, ChatMessage→5)
- 2 types should be combined (Refinement + MixedRefinement)

---

## P3: Polish & Refinement

### Frozen String Literal ❌ NOT APPLICABLE

Project RuboCop config uses `EnforcedStyle: never` - frozen_string_literal pragma is
explicitly disabled for this codebase.

### Magic Numbers Without Constants ✅ FIXED

Extracted to named constants:
- `model_builder.rb`: `DEFAULT_LMSTUDIO_PORT`, `DEFAULT_OLLAMA_PORT`, `DEFAULT_LLAMACPP_PORT`, `DEFAULT_VLLM_PORT`
- `visit_webpage.rb`: `MAX_CONTENT_BYTES`, `DEFAULT_TIMEOUT_SECONDS`
- `reliability.rb`: `DEFAULT_HEALTH_CHECK_CACHE_SECONDS`, `DEFAULT_MAX_RETRY_ATTEMPTS`, etc.

### Naming Convention Issues ✅ NO ACTION NEEDED

Analysis found the naming is **correct and idiomatic**:
- Underscore methods (`_resolve!`, `_pending?`) are intentionally semi-public for duck-typing in Future system
- `validate_*!` methods correctly use `!` to signal "raises on failure" per Ruby convention

---

## Executor Limitations (Documented)

- **`timeout`**: Accepted but not enforced
- **`memory_mb`**: Accepted but not enforced
- **Tool execution**: Runs in main Ractor with no resource limits

---

## Architecture Strengths (No Action Needed)

- **Type system:** 50+ Data.define types, pattern matching
- **Event system:** 168 emit points, proper Emitter/Consumer
- **Executor abstraction:** All code through executor, no direct eval
- **Builder pattern:** Lazy model evaluation, immutable configs
- **Test suite:** 13,600+ examples, 96%+ coverage, zero RuboCop violations
