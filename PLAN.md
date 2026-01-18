# smolagents-ruby

Highly-testable agents that think in Ruby 4.0.

---

## Current Status

| Metric | Value | Status |
|--------|-------|--------|
| Ruby Version | 4.0 | Target |
| RSpec Tests | 6577 | Passing |
| Line Coverage | 94.46% | Met |
| RuboCop Offenses | 0 | ✓ |

### Architecture Scores (2026-01-18)

| Area | Score | Notes |
|------|-------|-------|
| Ruby 4.0 Idioms | 10/10 | No deprecated code, no backwards compat |
| Self-Documenting | 10/10 | Full registry introspection |
| Test Infrastructure | 10/10 | AutoGen, AgentSpec, MockModel |
| Concurrency | 10/10 | Fiber/Thread/Ractor correct |
| Timeout Handling | 10/10 | RuboCop enforced, zero sleep() |
| Event Completeness | 10/10 | Tool/queue/health/config all emit |
| Reliability | 10/10 | DLQ, backpressure, fallback, graceful shutdown |
| IRB Experience | 10/10 | Tab completion, progress, auto-logging |
| Code DRYness | 10/10 | Utilities extracted, concerns composable |

---

## Architecture

### Execution Model

```
Agent (Fiber for control flow)
    │
    ▼
Code Executor
    │
    ├── LocalRuby (fast, BasicObject sandbox)
    │   └── ~0ms overhead, TracePoint ops limit
    │
    └── Ractor (secure, memory isolation)
        └── ~20ms overhead, message-passing
```

### Concurrency Primitives

```ruby
# Fiber: Control flow (yield steps, request input)
Fiber.new { agent_loop }.resume

# Thread: Background work (both use same worker pattern)
Thread.new { process_loop }  # nil from queue.pop = exit

# Ractor: Code sandboxing
Ractor.new(code) { |c| sandbox.eval(c) }
```

### Key Utilities

```ruby
# Recursive transformations (DRY)
Utilities::Transform.symbolize_keys(hash)
Utilities::Transform.freeze(obj)
Utilities::Transform.dup(obj)

# Similarity calculations (DRY)
Utilities::Similarity.jaccard(set_a, set_b)
Utilities::Similarity.string(a, b)
```

### Event System

Concerns include `Events::Emitter` directly for composability:
```ruby
module MyConcern
  include Events::Emitter

  def do_work
    emit(Events::WorkCompleted.create(...))
  end
end
```

---

## Next: Translation Support (TranslateGemma)

### Overview

TranslateGemma is a translation-only model family (4B/12B/27B) with:
- 55 core languages, strict prompt format
- 2K token context limit, multimodal (image-to-text)
- Local deployment via LM Studio/Ollama

### Atomic Components

| Component | Purpose | Leverages |
|-----------|---------|-----------|
| `TranslateGemmaModel` | Model adapter with strict template | `Models::Base`, `Concerns::ApiClient` |
| `Concerns::Translation` | Language detection, prompt building | `Concerns::Formatting::Messages` |
| `Concerns::Chunking` | Split long text at 2K boundary | `Utilities::Transform` |
| `Tools::TranslateTool` | Single text translation | `Tools::Tool` base |
| `Tools::TranslateFileTool` | File translation with chunking | `Tools::Tool`, `Concerns::Chunking` |
| `GlossaryManager` | Terminology consistency | `Persistence::Serializable` |

### TranslateGemmaModel Constraints

```ruby
class TranslateGemmaModel < Models::Base
  MAX_CONTEXT_TOKENS = 2048
  IMAGE_TOKENS = 256

  def supports_chat? = false  # Translation-only
  def supports_images? = true
  def max_context_tokens = MAX_CONTEXT_TOKENS
end
```

### Chunking Concern

```ruby
module Concerns::Chunking
  def chunk_text(text, max_tokens:, overlap: 100)
    # Split at sentence boundaries
    # Maintain overlap for context continuity
    # Return array of chunks
  end

  def reassemble_chunks(translated_chunks, overlap:)
    # Merge overlapping regions
    # Return complete translation
  end
end
```

### Builder DSL Extension

```ruby
agent = Smolagents.agent
  .model { TranslateGemmaModel.lm_studio("translategemma-12b") }
  .translation(
    source: :auto,
    targets: [:es, :fr, :de],
    glossary: "terms.yml"
  )
  .tools(:translate_file)
  .build
```

### Testing Strategy

```ruby
# MockTranslateGemmaModel for deterministic tests
model = Testing::MockTranslateGemmaModel.new(
  translations: { "Hello" => "Hola" },
  source_lang: "en",
  target_lang: "es"
)
```

---

## Backlog

### Priority 1: Translation

| Item | Description |
|------|-------------|
| TranslateGemmaModel | Model adapter with strict prompt template |
| Translation concern | Language codes, prompt building, validation |
| Chunking concern | 2K token boundary handling with overlap |
| TranslateTool | Single text translation tool |
| MockTranslateGemmaModel | Testing support |

### Priority 2: Test Coverage Gaps

| Item | Description |
|------|-------------|
| Parsing concerns | JSON/HTML/XML parsing edge cases |
| API key management | Error paths for missing env vars |
| Rate limiter strategies | Strategy-specific unit tests |

### Deferred

| Item | Reason |
|------|--------|
| STRATUS Checkpointing | Infrastructure needed (see below) |
| Multi-language execution | Ruby-only focus |
| Distributed rate limiting | Single-process sufficient for gem |
| GraphRAG | Complex, low priority |

#### STRATUS Checkpointing (NeurIPS 2025) — 150% improvement

**Status**: 40% complete — strong serialization foundation, missing orchestration

**What exists**:
- ✅ Serializable types (all 40+ types have `to_h`)
- ✅ Step history in `AgentMemory`
- ✅ 40+ lifecycle events for state changes
- ✅ Immutable `Data.define` structures
- ✅ Token/timing tracking per step

**Infrastructure needed**:
- ○ `Checkpoint` type with run_id, steps, memory, context
- ○ Persistence layer (file/DB adapter)
- ○ Restore mechanism to resume from checkpoint
- ○ Undo operators for reversible actions
- ○ Transaction boundaries for rollback grouping
- ○ Severity assessment for state quality metrics

---

## Principles

- **Ruby 4.0 Only** - No backwards compatibility
- **Simple by Default** - One line for common cases
- **IRB-First** - Interactive sessions work great out of the box
- **Event-Driven** - All state changes emit events
- **100/10 Rule** - Modules ≤100 lines, methods ≤10 lines
- **Test Everything** - MockModel for fast deterministic tests
- **Forward Only** - Delete unused code, no legacy shims
- **Defense in Depth** - Multiple independent security layers
- **Composable Concerns** - Include what you need, no guards
