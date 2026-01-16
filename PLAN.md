# smolagents-ruby

Highly-testable agents that think in Ruby.

---

## Why smolagents-ruby?

**Testing agents is hard.** Most frameworks require:
- Expensive API calls for every test run
- Complex HTTP mocking with WebMock/VCR
- Non-deterministic tests due to LLM variance
- Slow feedback loops

**smolagents-ruby is different.** Built from the ground up for testability:

```ruby
require "smolagents/testing"

RSpec.describe "My Agent" do
  let(:model) { Smolagents::Testing::MockModel.new }

  it "answers questions correctly" do
    model.queue_final_answer("42")

    agent = Smolagents.agent.model { model }.build
    result = agent.run("What is the answer?")

    expect(result.output).to eq("42")
    expect(model.call_count).to eq(1)
  end
end
```

| Feature | Other Frameworks | smolagents-ruby |
|---------|------------------|-----------------|
| Test speed | Slow (HTTP/API) | Fast (<10s total) |
| Determinism | Flaky (LLM variance) | 100% deterministic |
| Cost | API tokens per test | Zero cost |
| Setup | WebMock/VCR fixtures | `MockModel.new` |
| Inspection | Limited | Full call history |

---

## Current Atoms

Build agents with composable primitives:

```ruby
.model { }        # WHAT thinks (required)
.tools(...)       # WHAT it uses (optional)
.as(:persona)     # HOW it behaves (optional)
```

---

## P0 - One Agent Type ✅ COMPLETE

All agents write Ruby code. No ToolAgent, no mode selection.

```ruby
agent = Smolagents.agent
  .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
  .tools(:search, :web)
  .as(:researcher)
  .build
```

| Task | Status |
|------|--------|
| Delete ToolAgent, merge into Agent | ✅ Done |
| Remove `.with(:code)` (accepted but ignored) | ✅ Done |
| Update all specs for unified Agent | ✅ Done |
| Update README | ✅ Done |

---

## P1 - Memory & Context Management ✅ COMPLETE

> **Research:** MemGPT, A-MEM, JetBrains context engineering
> **Papers:** http://arxiv.org/abs/2310.08560, http://arxiv.org/abs/2601.01885

Memory management is now fully implemented:

```ruby
agent = Smolagents.agent
  .model { m }
  .memory(budget: 100_000)                    # Simple budget
  .build

# Or with full configuration
agent = Smolagents.agent
  .model { m }
  .memory(
    budget: 100_000,           # Token limit
    strategy: :hybrid,         # :full, :mask, :summarize, :hybrid
    preserve_recent: 5         # Always keep last N steps full
  )
  .build

# Check memory status during execution
agent.memory.estimated_tokens  # => 45_230
agent.memory.over_budget?      # => false
agent.memory.headroom          # => 54_770
```

### What Was Implemented

| Task | Status |
|------|--------|
| `MemoryConfig` type (Data.define) | ✅ Done |
| Token estimation (~4 chars/token) | ✅ Done |
| Budget tracking in AgentMemory | ✅ Done |
| Observation masking strategy | ✅ Done |
| `.memory()` DSL method | ✅ Done |

**Strategy options:**
- `:full` - Send everything (default)
- `:mask` - Replace old observations with placeholders
- `:hybrid` - Mask first, auto-applies when over budget

---

## P2 - Multi-Agent Hierarchies ✅ COMPLETE

> **Goal:** Agents spawn sub-agents with different models, tools, and context.

### What's Implemented

| Task | Status |
|------|--------|
| `ModelPalette` registry (Data.define) | ✅ Done |
| `ContextScope` type for inheritance | ✅ Done |
| `Environment` class for child agents | ✅ Done |
| `SpawnConfig` type for spawn limits | ✅ Done |
| `.model(:symbol)` references registry | ✅ Done |
| `Smolagents.get_model(:name)` helper | ✅ Done |
| `.can_spawn()` DSL method | ✅ Done |
| `spawn()` runtime function | ✅ Done |

### Model Palette

```ruby
Smolagents.configure do |config|
  config.models do |m|
    m = m.register :router, -> { OpenAIModel.lm_studio("gemma-3n-e4b") }
    m = m.register :researcher, -> { AnthropicModel.new("claude-sonnet-4-20250514") }
    m = m.register :fast, -> { AnthropicModel.new("claude-haiku") }
    m
  end
end

# Reference by role
agent = Smolagents.agent
  .model(:router)
  .build
```

### Spawn Capability

```ruby
# Configure agent to spawn children
agent = Smolagents.agent
  .model(:router)
  .can_spawn(
    allow: [:researcher, :fast],  # Models children can use
    tools: [:search, :final_answer],  # Tools children get
    inherit: :observations,  # Context inheritance
    max_children: 5
  )
  .build

# Agent code can now use spawn():
# result = spawn(model: :fast, task: "Summarize findings")
```

### Architecture Vision

```
┌─────────────────────────────────────────────────────────┐
│                    Chat Interface Model                  │
│              (High-quality, conversational)              │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│                  Management/Routing Model                │
│           (Fast, cheap - decides who does what)          │
└──────────┬──────────────┬──────────────┬────────────────┘
           │              │              │
    ┌──────▼──────┐ ┌─────▼─────┐ ┌─────▼─────┐
    │  Research   │ │   Code    │ │  Analysis │
    │   Model     │ │  Model    │ │   Model   │
    │ (thorough)  │ │ (precise) │ │  (cheap)  │
    └─────────────┘ └───────────┘ └───────────┘
```

#### Spawn Capability

```ruby
agent = Smolagents.agent
  .model(:router)
  .can_spawn(
    allow: [:researcher, :coder, :fast],  # Which models children can use
    tools: [:search, :web],                # Tools available to children
    inherit: :observations                 # Context inheritance
  )
  .build

# Agent writes Ruby code at runtime:
sub = spawn(model: :researcher, tools: [:search])
findings = sub.run("Find Ruby 4 release notes")
```

#### Context Inheritance

| Scope | What Child Sees |
|-------|-----------------|
| `:task_only` | Just the delegated task (default, current behavior) |
| `:observations` | Task + parent's tool observations |
| `:summary` | Task + compressed parent history |
| `:full` | Everything (use sparingly) |

```ruby
.can_spawn(inherit: :observations)
```

### Bidirectional Communication

**Existing primitives (already implemented):**
- `UserInput` - Agent asks user a question
- `SubAgentQuery` - Child asks parent for guidance
- `Confirmation` - Agent requests approval
- `Response` - Answer wrapper

**Flow:**
```
Child Agent                    Parent Agent / User
─────────────────────────────────────────────────
env.ask("Include 2023?")  ──→  SubAgentQuery yields
                          ←──  Parent's model answers
answer received           ←──  fiber.resume(Response)
```

#### Environment Object (New)

```ruby
# Child agent's interface to parent context
class Environment
  attr_reader :context

  def ask(question, options: nil)
    # Yields SubAgentQuery to parent
    escalate_query(question, options:)
  end

  def can?(capability)
    @capabilities.include?(capability)
  end
end

# Child code at runtime:
project = env.context[:project]           # Read static context
answer = env.ask("What date range?")      # Ask parent's model
```

#### Request Handling Policy

```ruby
agent = Smolagents.agent
  .model(:router)
  .can_spawn(allow: [:researcher])
  .on_child_request do |req|
    case req
    in SubAgentQuery[query:]
      ask_model(query)      # Answer with my model
      # OR: bubble(req)     # Pass to my parent
      # OR: lookup(query)   # Check context
    end
  end
  .build
```

### Unified Model: Same Primitives, Three Use Cases

| Use Case | Request Type | Handler |
|----------|-------------|---------|
| Agent → User | `UserInput` | Chat UI shows prompt |
| Child → Parent Agent | `SubAgentQuery` | Parent's model answers |
| Child → Grandparent | `SubAgentQuery` | Bubbles up chain |

### Tasks

| Task | Priority |
|------|----------|
| Model palette registration | HIGH |
| `Environment` class | HIGH |
| Context scoping (`:task_only`, `:observations`, etc.) | HIGH |
| `.on_child_request` handler | MEDIUM |
| Dynamic `spawn()` primitive | MEDIUM |
| Structured `SpawnResult` (not just string) | LOW |

---

## P3 - Pre-Act Planning ✅ COMPLETE

> **Paper:** http://arxiv.org/abs/2505.09970
> **Impact:** 70% improvement in Action Recall

Pre-Act planning is fully implemented with a flexible DSL:

```ruby
# Enable with research-backed default (interval: 3)
agent = Smolagents.agent
  .model { m }
  .planning
  .build

# All equivalent ways to enable/configure:
.planning                              # Default interval (3)
.planning(5)                           # Custom interval
.planning(true) / .planning(:enabled)  # Enable with default
.planning(false) / .planning(:disabled) # Disable
.planning(interval: 5, templates: {...}) # Full config
```

### What Was Implemented

1. **Pre-Act Pattern** - Initial planning happens BEFORE the first action step
2. **Update Planning** - Plan updates at configured intervals AFTER steps
3. **Flexible DSL** - Multiple calling styles for `.planning()` method
4. **Research-Backed Default** - Interval of 3 steps (arXiv:2505.09970)
5. **Bug Fixes** - Fixed `@tools` hash iteration, fixed immutable context update

| Task | Status |
|------|--------|
| Initial planning before first action | ✅ Done |
| Update planning at intervals | ✅ Done |
| Flexible `.planning` DSL | ✅ Done |
| Default interval from research | ✅ Done |
| Comprehensive tests (83 planning-related) | ✅ Done |

---

## P4 - Testing Infrastructure ✅ COMPLETE

> **Goal:** Enable deterministic, fast, zero-cost agent testing.

### What's Implemented

| Component | Description |
|-----------|-------------|
| `MockModel` | Scriptable model with queued responses |
| `MockCall` | Data.define for inspecting generate() calls |
| `Helpers` | Factory methods for common test setups |
| `Matchers` | RSpec matchers for agent assertions |
| `SpyTool` | Records all tool calls for verification |

### MockModel API

```ruby
model = Smolagents::Testing::MockModel.new

# Queue responses (FIFO)
model.queue_final_answer("42")
model.queue_code_action('search(query: "Ruby 4.0")')
model.queue_planning_response("1. Search 2. Analyze")

# Fluent aliases
model.answers("42").returns_code("search()").returns("Plan")

# Inspect calls after agent run
model.call_count          # => 3
model.calls               # => [MockCall, MockCall, ...]
model.last_messages       # => messages from last call
model.user_messages_sent  # => all user messages
model.exhausted?          # => true when all responses consumed
```

### RSpec Matchers

```ruby
# Result matchers
expect(result).to have_output(containing: "answer")
expect(result).to have_steps(3)
expect(result).to have_steps(at_most: 5)

# MockModel matchers
expect(model).to be_exhausted
expect(model).to have_received_calls(2)
expect(model).to have_seen_prompt("search for")
expect(model).to have_seen_system_prompt
```

### Helper Methods

```ruby
include Smolagents::Testing::Helpers

# Single-step test
model = mock_model_for_single_step("42")

# Multi-step with pattern matching
model = mock_model_for_multi_step([
  { code: 'search(query: "test")' },
  { final_answer: "Found it" }
])

# Planning + answer
model = mock_model_with_planning(
  plan: "1. Search 2. Answer",
  answer: "Done"
)
```

### Ruby 4.0 Idioms

- **MockCall** uses `Data.define` for immutable, pattern-matchable call records
- **Pattern matching** in `mock_model_for_multi_step` for clean step handling
- **Monitor** for thread-safe re-entrant locking
- **Endless methods** for concise accessors

| Task | Status |
|------|--------|
| MockModel class | ✅ Done |
| MockCall Data.define | ✅ Done |
| RSpec matchers (8 matchers) | ✅ Done |
| Helper methods | ✅ Done |
| User-facing Testing module | ✅ Done |
| YARD documentation | ✅ Done |
| 170 deterministic tests | ✅ Done |

---

## Later: Self-Refine & Swarm

### Self-Refine (20% improvement)

> **Paper:** http://arxiv.org/abs/2303.17651

Consider rolling into planning modes rather than separate builder.

### Swarm (6.6% + parallelism)

> **Papers:** http://arxiv.org/abs/2502.00674, http://arxiv.org/abs/2510.05077

Multiple workers, varied temperatures, consensus aggregation.

---

## Research References

| Topic | Source | Key Finding |
|-------|--------|-------------|
| Memory as OS | MemGPT (arXiv:2310.08560) | Two-tier: working + archival |
| Agent-controlled memory | A-MEM (arXiv:2601.01885) | Memory ops as tools |
| Context engineering | JetBrains 2025 | Hybrid mask+summarize best |
| Pre-Act planning | arXiv:2505.09970 | 70% improvement |
| Self-Refine | arXiv:2303.17651 | 20% improvement |
| Swarm | arXiv:2502.00674 | 6.6% + parallelism |
| Multi-agent scoping | Google ADK | "Scope by default" |

---

## Completed

| Date | Summary |
|------|---------|
| 2026-01-16 | P4 complete: Testing infrastructure with MockModel, matchers, Ruby 4.0 idioms |
| 2026-01-16 | P2 complete: Multi-agent spawn with model palette, 3339 tests pass |
| 2026-01-16 | P1 complete: Memory management with token budget and masking |
| 2026-01-16 | P3 complete: Pre-Act planning with flexible DSL |
| 2026-01-16 | P0 complete: unified Agent, all tests pass |
| 2026-01-15 | Archived P4-P7 to ROADMAP.md |
| 2026-01-15 | UTF-8 sanitization, circuit breaker fixes |
| 2026-01-15 | Fiber-first execution, control requests, events |

---

## Principles

- **Ship it**: Working software over architecture
- **One agent type**: All agents write Ruby code
- **Test-first**: MockModel enables deterministic, zero-cost testing
- **Ruby 4.0**: Data.define, pattern matching, endless methods
- **Scope by default**: Children get minimum context, reach for more
- **Same primitives**: User↔Agent and Agent↔Agent use same patterns
- **Forward only**: No backwards compatibility, delete unused code
