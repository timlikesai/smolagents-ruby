# smolagents-ruby Future Roadmap

> **Archived from PLAN.md on 2026-01-15**
> These are future features to consider AFTER P0-P3 are shipped.
> Do not work on these until the foundation is solid.

---

## Priority 4: Debate Pattern

> **Research:** Multi-Agent Reflexion shows 47% EM vs 44% baseline.
> **Paper:** http://arxiv.org/abs/2512.20845

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

## Priority 6: Memory Enhancements

> **Research:** Memory should be agent-controlled, not framework-managed.
> **Paper:** http://arxiv.org/abs/2601.01885

| Task | Priority | Notes |
|------|----------|-------|
| Working memory token budget | MEDIUM | Enforce limits, auto-summarize |
| Long-term persistence | LOW | Save/restore across sessions |
| Semantic retrieval | FUTURE | Vector similarity for recall |

---

## Priority 7: Security-Aware Routing

> **Goal:** Route data to appropriate models based on sensitivity.
> **Use cases:** Newsrooms, healthcare, finance, legal, HR

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

## Research Papers Referenced

| Paper | Key Finding |
|-------|-------------|
| http://arxiv.org/abs/2505.09970 | Pre-Act: 70% improvement in Action Recall |
| http://arxiv.org/abs/2303.17651 | Self-Refine: 20% improvement, prompting only |
| http://arxiv.org/abs/2502.00674 | Self-MoA: Same model ensemble beats mixing |
| http://arxiv.org/abs/2510.05077 | Swarm intelligence patterns |
| http://arxiv.org/abs/2512.20845 | Multi-Agent Reflexion: 47% EM |
| http://arxiv.org/abs/2601.01885 | Agent-controlled memory |
