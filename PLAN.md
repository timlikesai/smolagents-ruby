# smolagents-ruby

Delightfully simple agents that think in Ruby.

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

## P1 - Memory & Context Management

> **Research:** MemGPT, A-MEM, JetBrains context engineering
> **Papers:** http://arxiv.org/abs/2310.08560, http://arxiv.org/abs/2601.01885

### Current State

`Runtime::AgentMemory` exists and works:
- Stores steps chronologically (TaskStep, ActionStep, PlanningStep)
- Converts to messages via `to_messages(summary_mode:)`
- Lazy enumerators for filtering (`action_steps`, `planning_steps`)
- No token budget management
- `summary_mode` exists but unused

### What's Missing

| Feature | Current | Needed |
|---------|---------|--------|
| Token budget | None | Auto-truncation at threshold |
| Context strategy | Full history always | Hybrid (mask + summarize) |
| Summary mode | Unused | Wire into execution |
| Persistence | None | Optional save/restore |

### Implementation

```ruby
agent = Smolagents.agent
  .model { m }
  .memory(
    budget: 100_000,           # Token limit
    strategy: :hybrid,         # :full, :mask, :summarize, :hybrid
    preserve_recent: 5         # Always keep last N steps full
  )
  .build
```

**Strategy options:**
- `:full` - Send everything (current behavior)
- `:mask` - Replace old observations with placeholders
- `:summarize` - Compress old steps via LLM
- `:hybrid` - Mask first, summarize when needed (recommended)

### Tasks

| Task | Priority |
|------|----------|
| Add `budget` tracking to AgentMemory | HIGH |
| Implement observation masking | HIGH |
| Wire `summary_mode` into execution | MEDIUM |
| Add LLM summarization fallback | LOW |

---

## P2 - Multi-Agent Hierarchies

> **Goal:** Agents spawn sub-agents with different models, tools, and context.

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

### New Atoms

#### Model Palette (Global)

```ruby
Smolagents.configure do |config|
  config.models do |m|
    m.register :interface,  -> { AnthropicModel.new("claude-sonnet-4-20250514") }
    m.register :router,     -> { OpenAIModel.lm_studio("gemma-3n-e4b") }
    m.register :researcher, -> { AnthropicModel.new("claude-sonnet-4-20250514") }
    m.register :coder,      -> { OpenAIModel.new("gpt-4-turbo") }
    m.register :fast,       -> { AnthropicModel.new("claude-haiku") }
  end
end

# Reference by role
agent = Smolagents.agent
  .model(:router)
  .build
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
| 2026-01-16 | P3 complete: Pre-Act planning with flexible DSL, 3220 tests pass |
| 2026-01-16 | P0 complete: unified Agent, all tests pass |
| 2026-01-15 | Archived P4-P7 to ROADMAP.md |
| 2026-01-15 | UTF-8 sanitization, circuit breaker fixes |
| 2026-01-15 | Fiber-first execution, control requests, events |

---

## Principles

- **Ship it**: Working software over architecture
- **One agent type**: All agents write Ruby code
- **Test everything**: Mocked models for deterministic tests
- **Scope by default**: Children get minimum context, reach for more
- **Same primitives**: User↔Agent and Agent↔Agent use same patterns
- **Forward only**: No backwards compatibility, delete unused code
