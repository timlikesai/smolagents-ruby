# smolagents-ruby Project Plan

> **When updating this file:** Remove completed sections, consolidate history, keep it lean.
> The plan should be actionable, not archival. If work is done, collapse it to a single line in Completed.

Delightfully simple agents that think in Ruby.

See [ARCHITECTURE.md](ARCHITECTURE.md) for vision, patterns, and examples.

---

## Principles

- **Ship it**: Working software over perfect architecture
- **Simple first**: If it needs explanation, simplify it
- **Test everything**: No feature without tests
- **Delete unused code**: If nothing calls it, remove it
- **Cops guide development**: Fix the code, not disable the cop
- **DSL consistency**: Same idioms everywhere. One pattern, many expressions.
- **Token efficiency**: Compact DSLs reduce boilerplate for AI agent consumption
- **Self-reinforcing**: Use our constructs to build our constructs

---

## DSL Interface Principles

> These principles ensure every DSL feels like part of the same family.
> An AI writing agents should reach for these patterns instinctively.

### The Universal Pattern

Every orchestration DSL follows the same shape:

```ruby
Smolagents.<verb>
  .model { ... }      # What thinks
  .tools(...)         # What it can use
  .<configure>(...)   # How it behaves
  .build              # Make it real
```

### Consistency Rules

| Rule | Example | Rationale |
|------|---------|-----------|
| **Entry point is verb** | `.agent`, `.refine`, `.swarm`, `.debate` | Verbs express intent |
| **Configuration is chainable** | `.model { }.tools(:x).build` | Fluent = readable |
| **Blocks for complex, symbols for simple** | `.model { custom }` vs `.model(:openai)` | Match complexity to syntax |
| **Build finalizes** | `.build` always returns the runnable thing | Predictable lifecycle |
| **Run executes** | `.run(task)` always returns result | Consistent execution |

### The Three Atoms

Every agent composes from three atoms:

```ruby
.model { ... }        # WHAT thinks (required)
.tools(...)           # WHAT it uses (optional, expands toolkits)
.as(:persona)         # HOW it behaves (optional, sets instructions)
```

These compose in any order. The same atoms work across all DSLs:

```ruby
Smolagents.agent.model { m }.tools(:search).as(:researcher).build
Smolagents.refine.model { m }.tools(:search).as(:critic).build
Smolagents.swarm.model { m }.tools(:search).workers(5).build
Smolagents.debate.model { m }.tools(:search).rounds(3).build
```

### Self-Reinforcing Patterns

Our DSLs use our own constructs:

```ruby
# Swarm uses agents internally
swarm = Smolagents.swarm.model { m }.workers(5).build
# Each worker IS a Smolagents.agent under the hood

# Debate uses agents internally
debate = Smolagents.debate.model { m }.build
# Proposer, Critic, Judge are each Smolagents.agent

# Refine uses agents internally
refine = Smolagents.refine.model { m }.build
# Generator and Refiner share the same agent pattern
```

---

## Current Status

**What works:**
- CodeAgent & ToolAgent - write Ruby code or use JSON tool calling
- Builder DSL - `Smolagents.agent.tools(:search).as(:researcher).model{}.build`
- Composable atoms - Toolkits (tool groups), Personas (behavior), Specializations (bundles)
- Models - OpenAI, Anthropic, LiteLLM adapters with reliability/failover
- Tools - base class, registry, 12+ built-ins, SearchTool DSL
- ToolResult - chainable, pattern-matchable, Enumerable
- Executors - Ruby sandbox, Docker, Ractor isolation
- Events - DSL-generated immutable types, Emitter/Consumer pattern
- Errors - DSL-generated classes with pattern matching
- Fiber-first execution - `fiber_loop()` as THE ReAct loop primitive
- Control requests - UserInput, Confirmation, SubAgentQuery with DSL
- Ruby 4.0 idioms enforced via RuboCop

**Metrics:**
- Code coverage: 93.46% (threshold: 80%)
- Doc coverage: 97.31% (target: 95%)
- Tests: 3241 examples, 0 failures
- RuboCop: 0 offenses

---

## Priority 0: Critical Fixes (Ship This Week)

> **Goal:** Fix failure modes discovered during research testing.
> **Research doc:** `exploration/FAILURE_MODES.md`
> **Time estimate:** 2-3 days total

### Quick Wins (High Impact, Low Effort)

| Task | Files | Time | Notes |
|------|-------|------|-------|
| UTF-8 sanitization in JSON | `concerns/parsing/json.rb`, `tools/arxiv_search.rb` | 30m | `text.encode('UTF-8', invalid: :replace, undef: :replace)` |
| UTF-8 in HTTP responses | `http/response_handling.rb` | 20m | Sanitize before parsing |
| UTF-8 in visit_webpage | `tools/visit_webpage.rb` | 20m | Sanitize before ReverseMarkdown |
| Circuit breaker allowlist | `concerns/resilience/circuit_breaker.rb` | 25m | Define `CIRCUIT_BREAKING_ERRORS` |
| Exclude JSON errors from circuit | `concerns/resilience/circuit_breaker.rb` | 10m | `JSON::GeneratorError` is local |
| Exclude rate limits from circuit | `concerns/resilience/circuit_breaker.rb` | 10m | Use retry instead |

---

## Priority 1: Pre-Act Planning (70% Improvement)

> **Research:** Pre-Act pattern yields 70% improvement in Action Recall over ReAct.
> **Paper:** http://arxiv.org/abs/2505.09970
> **Time estimate:** 1-2 weeks

This is the highest-impact single feature. Plan before acting.

### Implementation

| Task | Priority | Notes |
|------|----------|-------|
| Add `planning` phase to fiber_loop | HIGH | Generate multi-step plan before first action |
| Plan refinement after tool results | HIGH | Incorporate observations into plan |
| Temporal context injection | HIGH | Date/time/timezone in system prompt |
| Planning DSL | MEDIUM | `.planning(interval: 3)` already exists, enhance |

### DSL Design

```ruby
# Simple: just enable planning
agent = Smolagents.agent
  .model { m }
  .planning                    # Enable planning phase
  .build

# Configured: control the planning
agent = Smolagents.agent
  .model { m }
  .planning(interval: 3)       # Replan every 3 steps
  .planning(depth: :shallow)   # Quick plans vs detailed
  .build
```

---

## Priority 2: Self-Refine Loop (20% Improvement)

> **Research:** Self-Refine yields 20% improvement with no training, just prompting.
> **Paper:** http://arxiv.org/abs/2303.17651
> **Time estimate:** 3-5 days

### Implementation

| Task | Priority | Notes |
|------|----------|-------|
| `Smolagents.refine` entry point | HIGH | New builder in `builders/refine_builder.rb` |
| Generate → Feedback → Refine cycle | HIGH | Core loop implementation |
| Stop conditions | MEDIUM | `max_iterations:`, `until:`, `unchanged?` |

### DSL Design

```ruby
# The refine builder follows THE universal pattern
result = Smolagents.refine
  .model { m }                              # Same atom
  .tools(:search)                           # Same atom
  .generate("Write a summary of X")         # Initial generation
  .feedback("What could be improved?")      # Self-critique prompt
  .max_iterations(3)                        # Stop condition
  .build
  .run

# Or with custom feedback logic
result = Smolagents.refine
  .model { m }
  .generate("Draft an email")
  .feedback { |draft| "Rate this draft 1-10: #{draft}" }
  .until { |result| result.include?("10/10") }
  .build
  .run
```

---

## Priority 3: Swarm Ensemble (6.6% + Parallelism)

> **Research:** Self-MoA (same model ensemble) beats mixing different models.
> **Papers:** http://arxiv.org/abs/2502.00674, http://arxiv.org/abs/2510.05077
> **Time estimate:** 1-2 weeks

### Implementation

| Task | Priority | Notes |
|------|----------|-------|
| `Smolagents.swarm` entry point | HIGH | New builder in `builders/swarm_builder.rb` |
| Parallel execution via Ractor | HIGH | Use existing RactorOrchestrator |
| Temperature spread for diversity | HIGH | Same model, different temperatures |
| Aggregation strategies | HIGH | `:majority`, `:confidence`, `:best` |

### DSL Design

```ruby
# Swarm follows THE universal pattern
result = Smolagents.swarm
  .model { m }                              # Same atom
  .tools(:search)                           # Same atom
  .workers(5)                               # How many parallel agents
  .temperature(0.3..1.2)                    # Spread for diversity
  .aggregate(:confidence)                   # CISC-style voting
  .build
  .run("Research topic X")

# Workers are just agents - self-reinforcing
# Internally: 5x Smolagents.agent with varied temperatures
```

---

## Priority 4: Debate Pattern

> **Research:** Multi-Agent Reflexion shows 47% EM vs 44% baseline.
> **Paper:** http://arxiv.org/abs/2512.20845
> **Time estimate:** 1-2 weeks

### Implementation

| Task | Priority | Notes |
|------|----------|-------|
| `Smolagents.debate` entry point | MEDIUM | New builder in `builders/debate_builder.rb` |
| Proposer → Critic → Judge roles | MEDIUM | Three-agent pattern |
| Multi-round debates | MEDIUM | Configurable rounds |

### DSL Design

```ruby
# Debate follows THE universal pattern
result = Smolagents.debate
  .model { m }                              # Same atom
  .tools(:search)                           # Same atom
  .proposer("Generate initial answer")      # Role instructions
  .critic("Find flaws in the proposal")     # Role instructions
  .judge("Pick the strongest argument")     # Role instructions
  .rounds(2)                                # How many debate rounds
  .build
  .run("Should we use microservices?")

# Each role is an agent - self-reinforcing
# Internally: 3x Smolagents.agent with role-specific personas
```

---

## Priority 5: Agent Modes (Metacognition)

> **Research:** Multiple papers on metacognition and self-monitoring.
> **Time estimate:** 1 week

### Implementation

| Task | Priority | Notes |
|------|----------|-------|
| `AgentMode` types | MEDIUM | `:reasoning`, `:evaluation`, `:correction` |
| Mode switching in fiber loop | MEDIUM | Agent can transition between modes |
| Mode-specific prompts | MEDIUM | Different behavior per mode |

### DSL Design

```ruby
# Modes are internal state, not DSL configuration
# The agent switches modes automatically based on context

agent = Smolagents.agent
  .model { m }
  .tools(:search)
  .build

# During execution, agent internally transitions:
# :reasoning → :evaluation → :correction → :reasoning
# Exposed via events for observability
```

---

## Priority 6: Memory as Tools

> **Research:** Memory should be agent-controlled, not framework-managed.
> **Paper:** http://arxiv.org/abs/2601.01885
> **Time estimate:** 1-2 weeks

### Implementation

| Task | Priority | Notes |
|------|----------|-------|
| Memory tool interface | HIGH | `store`, `retrieve`, `summarize`, `forget` |
| Working memory limit | MEDIUM | Token budget enforcement |

### DSL Design

```ruby
# Memory is just a tool - follows existing patterns
agent = Smolagents.agent
  .model { m }
  .tools(:search, :memory)                  # Memory is a tool
  .build

# Agent decides when to use memory
# store(key, value), retrieve(key), summarize(keys), forget(key)
```

---

## Priority 7: Security-Aware Routing

> **Goal:** Route data to appropriate models based on sensitivity.
> **Use cases:** Newsrooms, healthcare, finance, legal, HR
> **Time estimate:** 2-3 weeks

### Phase 1: Data Classification

```ruby
agent = Smolagents.agent
  .model { m }
  .classify { |input| contains_pii?(input) ? :sensitive : :general }
  .route(:sensitive, to: local_model)
  .route(:general, to: cloud_model)
  .build
```

### Phase 2: Compliance Modes

```ruby
agent = Smolagents.agent
  .model { m }
  .compliance(:hipaa)                       # Preset configuration
  .build

# :hipaa implies: sanitize_phi, audit_trail, us_data_residency
```

---

## Backlog

| Item | Priority | Notes |
|------|----------|-------|
| Goal state tracking | MEDIUM | Explicit goals, subgoal decomposition |
| External validator pattern | MEDIUM | Hook for external verification |
| Hierarchical delegation | LOW | Supervisor → Worker patterns |
| Cost-aware tool selection | LOW | Optimize for latency/cost |
| Sandbox DSL builder | LOW | Composable sandbox configuration |
| Air-gapped operation | FUTURE | For high-security environments |

---

## Completed

| Date | Summary |
|------|---------|
| 2026-01-15 | **Research & Resilience**: ArXiv tool, EarlyYield, ToolRetry. 55+ papers synthesized. PLAN restructured. |
| 2026-01-15 | **Composable Agent Architecture**: Toolkits, Personas, Specializations. 35 composition tests. |
| 2026-01-15 | **Fiber-First Execution Model**: `fiber_loop()` as THE ReAct primitive, control requests, events. |
| 2026-01-14 | **Module Splits & RuboCop**: http/, security/, concerns/. All offenses fixed. |
| 2026-01-13 | **Documentation**: YARD 97.31%, event system simplification, dead code removal. |
| 2026-01-12 | **Infrastructure**: Agent persistence, DSL.Builder, Model reliability, Telemetry. |

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Universal DSL pattern | `.verb.model{}.tools().build.run` everywhere |
| Three atoms | Model (thinks), Tools (uses), Persona (behaves) |
| Self-reinforcing | Swarm uses agents, Debate uses agents, Refine uses agents |
| Verbs as entry points | `Smolagents.agent`, `.refine`, `.swarm`, `.debate` |
| Blocks for complex | `.model { custom_config }` when configuration needed |
| Symbols for simple | `.tools(:search)` for registered tools |
| Build finalizes | `.build` returns runnable, `.run` executes |
| Events, not callbacks | Events are data (testable). Callbacks are behavior. |
| Forward-only | Delete unused code. No backwards compatibility. |
| Research-driven | Cite papers for patterns. 70% > 20% > 6.6% guides priority. |
| Token efficiency | DSLs that AI agents want to write |
