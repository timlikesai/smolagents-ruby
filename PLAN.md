# smolagents-ruby

Highly-testable agents that think in Ruby.

---

## Current Status

| Metric | Value | Target |
|--------|-------|--------|
| RSpec Tests | 5716 | - |
| Line Coverage | 92.33% | 90%+ |
| RuboCop Offenses | 0 | 0 |
| RuboCop Disables | 22 | <15 |
| **File Size Compliance** | **60%** | **95%+** |

**Critical Issue:** 139 of 351 files (39.6%) exceed the 100-line limit. This violates our core principle and must be fixed before adding new features.

---

## Priority: Architectural Cleanup

**No new features until file size compliance reaches 95%.**

The codebase has accumulated technical debt through rapid iteration. God objects, bloated test utilities, and antipatterns need cleanup to maintain the 100/10 rule.

### Compliance by Category

| Category | Files | Violations | Rate |
|----------|-------|------------|------|
| tools/ | 39 | 18 | 46% |
| testing/ | 25 | 11 | 44% |
| builders/ | 18 | 8 | 44% |
| types/ | 49 | 17 | 35% |
| concerns/ | 95 | 25 | 26% |

---

## Phase 11: God Object Decomposition

Split the worst offenders first. Each file must be ≤100 lines after refactoring.

### 11A. Core God Objects (Priority 1)

| File | Lines | Extraction Plan |
|------|-------|-----------------|
| `agents/agent.rb` | 482 | → `agent/config.rb` (initialization, config) |
| | | → `agent/execution.rb` (run, run_fiber, stream) |
| | | → `agent/delegation.rb` (tool/memory management) |
| `executors/executor.rb` | 433 | → `executor/security.rb` (sandbox, validation) |
| | | → `executor/output.rb` (truncation, formatting) |
| | | → `executor/base.rb` (interface only) |

### 11B. Builder God Objects (Priority 2)

| File | Lines | Extraction Plan |
|------|-------|-----------------|
| `builders/agent_builder.rb` | 390 | → `agent_builder/model_config.rb` |
| | | → `agent_builder/tool_config.rb` |
| | | → `agent_builder/execution_config.rb` |
| `builders/base.rb` | 343 | → `builder/metadata.rb` |
| | | → `builder/validation.rb` |
| | | → `builder/help.rb` |

### 11C. Model God Objects (Priority 3)

| File | Lines | Extraction Plan |
|------|-------|-----------------|
| `models/resilient_model.rb` | 426 | → `resilient_model/retry.rb` |
| | | → `resilient_model/fallback.rb` |
| | | → `resilient_model/health.rb` |

**Success Criteria:** All files in `agents/`, `executors/`, `builders/`, `models/` ≤100 lines.

---

## Phase 12: Test Utility Cleanup

Testing code has the highest violation rate. Split by responsibility.

### 12A. Mock Model Split

| File | Lines | Extraction Plan |
|------|-------|-----------------|
| `testing/mock_model.rb` | 401 | → `mock_model/core.rb` (generate, queue) |
| | | → `mock_model/responses.rb` (response builders) |
| | | → `mock_model/assertions.rb` (call tracking) |

### 12B. Helper Split

| File | Lines | Extraction Plan |
|------|-------|-----------------|
| `testing/helpers.rb` | 401 | → `helpers/model_helpers.rb` |
| | | → `helpers/agent_helpers.rb` |
| | | → `helpers/tool_helpers.rb` |

### 12C. Benchmark Split

| File | Lines | Extraction Plan |
|------|-------|-----------------|
| `testing/model_benchmark.rb` | 382 | → `benchmark/runner.rb` |
| | | → `benchmark/results.rb` |
| | | → `benchmark/analysis.rb` |

**Success Criteria:** All files in `testing/` ≤100 lines.

---

## Phase 13: Antipattern Fixes

Address patterns that RuboCop doesn't catch but violate Ruby idioms.

### 13A. Law of Demeter Violations

| Pattern | Location | Fix |
|---------|----------|-----|
| `@runtime.instance_variable_get(:@state)` | agent.rb:395 | Add `attr_reader :state` to AgentRuntime |
| `model.instance_variable_get(:@client)` | agent_serializer.rb:85 | Add `api_base` accessor to Model |
| `agent.instance_variable_get(:@custom_instructions)` | agent_serializer.rb:62 | Add accessor to Agent |

### 13B. Temporal Coupling

| Pattern | Location | Fix |
|---------|----------|-----|
| `ctx = (@ctx = after_step(...))` | execution.rb:80 | Split into two statements |
| Mutable `state` hash in retry loop | retry_execution.rb:16 | Use `RetryState = Data.define(...)` |

### 13C. Remaining RuboCop Disables

Target: Reduce from 22 to <15 disables.

| File | Disable | Action |
|------|---------|--------|
| `testing/matchers.rb` | ModuleLength, AbcSize | Split into matcher files |
| `testing/helpers.rb` | MethodLength | Will be fixed by 12B |
| `ractor.rb` | MethodLength | Keep - Ractor requires inline blocks |

**Success Criteria:** <15 rubocop:disable comments, 0 Law of Demeter violations.

---

## Phase 14: Concern Consolidation

Reduce 95-file concern directory to ~60 files by merging related micro-concerns.

### 14A. Tool Concerns

| Current | Merge Into |
|---------|------------|
| `tools/result/arithmetic.rb` | `tools/result.rb` |
| `tools/result/collection.rb` | |
| `tools/result/core.rb` | |
| `tools/result/creation.rb` | |
| `tools/result/utility.rb` | |
| `tools/tool/dsl.rb` | `tool.rb` (base class) |
| `tools/tool/formatting.rb` | |
| `tools/tool/schema.rb` | |
| `tools/tool/validation.rb` | |

### 14B. Parsing Concerns

| Current | Merge Into |
|---------|------------|
| `parsing/json.rb` | `parsing/structured.rb` |
| `parsing/xml.rb` | |
| `parsing/html.rb` | `parsing/document.rb` |
| `parsing/critique.rb` | |

**Success Criteria:** concerns/ directory has ≤70 files.

---

## Completion Checklist

Before moving to new features:

- [ ] File size compliance ≥95%
- [ ] RuboCop disables <15
- [ ] No `instance_variable_get` for state access
- [ ] No compound mutation assignments
- [ ] concerns/ directory ≤70 files
- [ ] All tests passing

---

## Future Phases (Gated on Cleanup)

These features are research-backed but blocked until architectural cleanup is complete.

### Dynamic Tooling

**Research:** ToolMaker (arXiv:2502.11705), TOOLFLOW (ACL 2025)

- JIT tool creation via `create_tool(name:, code:)`
- Security: anonymous modules, CodeValidator, no IO
- DSL: `.jit_tools(approval: :required)`

### Agent Autonomy

**Research:** STRATUS (NeurIPS 2025) - 150% improvement

- Checkpointing with rollback on failure
- Context folding via `.memory(strategy: :folding)`

---

## Backlog

Items lacking research backing or adding complexity without proven value.

| Item | Reason Deferred |
|------|-----------------|
| StateSnapshot | Overhead without research |
| PlanCompass | Complex context manipulation |
| TypeInterface (RBS) | Over-abstraction |
| Debate Pattern | Only 3% improvement |
| Consensus Strategies | Unproven |
| GraphRAG | Complex, low priority |

---

## Research References

| Topic | Source | Finding |
|-------|--------|---------|
| Pre-Act Planning | arXiv:2505.09970 | 70% improvement |
| Self-Refine | arXiv:2303.17651 | 20% improvement |
| STRATUS | NeurIPS 2025 | 150% improvement |
| ToolMaker | arXiv:2502.11705 | LLMs create tools |
| TOOLFLOW | ACL 2025 | Dynamic > static |
| Agent Memory | arXiv:2601.01885 | Agent-controlled |

---

## Principles

- **Simple by Default** - One line for common cases
- **Ruby 4.0 Idioms** - Data.define, pattern matching, blocks
- **100/10 Rule** - Modules ≤100 lines, methods ≤10 lines
- **Test Everything** - MockModel, fast tests
- **Forward Only** - No backwards compatibility
- **Clean Before New** - Fix debt before adding features
