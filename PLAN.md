# smolagents-ruby

Highly-testable agents that think in Ruby.

---

## Current Status

| Metric | Value |
|--------|-------|
| RSpec Tests | 4131 passing (90% coverage) |
| YARD Doctests | 46 runs, 42 assertions, 0 failures |
| Model Compliance | 3 models passing L0-L8 at 98%+ |

---

## Current DSL

```ruby
.model { }                    # WHAT thinks (required)
.tools(...)                   # WHAT it uses (optional)
.tool(:name, "desc") { }      # Inline tool definition
.as(:persona)                 # HOW it behaves (optional)
.memory(budget:, strategy:)   # Context management
.planning                     # Pre-Act planning (70% improvement)
.can_spawn(allow: [...])      # Enable sub-agent spawning
```

---

## Completed (P0-P6)

| Priority | Feature | Key Benefit |
|----------|---------|-------------|
| P0 | Unified Agent | All agents write Ruby code |
| P1 | Memory Management | Token budgets, hybrid strategy |
| P2 | Multi-Agent | Model palette, spawn capability |
| P3 | Pre-Act Planning | 70% action recall improvement |
| P4 | Testing Infrastructure | MockModel, matchers, doctests |
| P5 | Inline Tools | `.tool(:name, "desc") { }` |
| P6 | Self-Spawning | Constrained sub-agent creation |

---

## Next: Research-Backed Improvements

Based on comprehensive research analysis (January 2026). Each layer builds on the previous.

---

### Layer 1: Foundation (No Dependencies) ✅

#### F1: Enhanced Tool Descriptions ✅

> **Research:** "By far the most important factor in tool performance" — OpenAI, Anthropic

**Pattern:**
```ruby
description <<~DESC
  Searches the web using multiple search engines.
  Returns structured results with titles, URLs, and snippets.

  Use when: You need current information not in your training data.
  Do NOT use when: The answer is obvious or well-known.

  Returns: Array of {title:, url:, snippet:} hashes, max 10 results.
DESC
```

**Requirements:** 3-4+ sentences, what/when/when-not, return format, NO examples.

---

#### F2: Structured Error Messages ✅

> **Research:** "Don't return generic 'Failed'" — LangChain, GoCodeo

**Pattern:**
```ruby
ToolError = Data.define(:code, :message, :suggestion, :example) do
  def to_observation
    "Error [#{code}]: #{message}\nFix: #{suggestion}\nExample: #{example}"
  end
end
```

---

#### F3: Repetition Detection ✅

> **Research:** "Consecutive identical actions = intervene" — Reflexion, ReAct 2025

**Pattern:**
```ruby
def repetition_detected?(recent_steps, window: 3)
  recent = recent_steps.last(window).map { |s| [s.tool_name, s.arguments] }
  recent.uniq.size < recent.size
end
```

---

### Layer 2: Reliability (Depends on F2)

#### R1: Exponential Backoff with Jitter ✅

> **Research:** Reduces API failures by 90% — Retry Logic Best Practices 2025

```ruby
delay = base_delay * (2 ** retries) + rand(0.0..0.5)  # Jitter
```

**Error Classification:** Retriable (timeout, rate_limit, 5xx) vs Non-retriable (auth, not_found)

---

#### R2: Circuit Breaker ⬜

> **Research:** "Cut off traffic to unhealthy components" — Portkey

Stop calling failing endpoints before cascade. Half-open state for recovery testing.

---

### Layer 3: Metacognition (Depends on F2, F3)

#### M1: Evaluation States ✅

> **Research:** Matches AgentPRM "promise/progress" scoring — arXiv:2511.08325

```ruby
EvaluationState = Data.define(:status, :detail, :confidence) do
  DONE     = ->(answer, confidence: 0.9) { new(:done, answer, confidence) }
  CONTINUE = ->(needed, progress: 0.5) { new(:continue, needed, progress) }
  STUCK    = ->(blocking, confidence: 0.3) { new(:stuck, blocking, confidence) }
end
```

**DSL:** `.evaluate(on: :each_step)`

---

#### M2: Self-Refine Loop ✅

> **Research:** ~20% improvement — arXiv:2303.17651

Generate → Feedback → Refine loop. Works best with capable models.
For small models, use external validation instead.

**DSL:** `.refine(max_iterations: 3, feedback_model: :same)`

---

#### M3: Reflection Memory ✅

> **Research:** 91% pass@1 on HumanEval — Reflexion

Store reflections across attempts: "Last time I tried X, it failed because Y."

---

### Layer 4: External Validation (Depends on M1)

#### V1: Execution Feedback Oracle ✅

> **Research:** "Small models cannot self-correct without external feedback" — ICLR 2024

Use execution results as ground truth. Parse error messages for actionable fixes.

---

#### V2: Goal Drift Detection ✅

> **Research:** "Track behavioral changes across multiple actions" — arXiv:2505.02709

Monitor action sequences for deviation from original task.

---

### Layer 5: Advanced (Depends on M2, V1)

#### A1: Mixed-Refinement ✅

> **Research:** Vicuna-13b + ChatGPT: 24% → 40% on math

Small model generates, larger model provides feedback.

**DSL:** `.refine(feedback_model: large_model, max_iterations: 2)`

---

#### A2: STRATUS Undo-and-Retry ⬜

> **Research:** 150%+ improvement — IBM STRATUS (NeurIPS 2025)

Checkpoint state before risky operations, rollback on failure.

---

#### A3: Constrained Output ⬜

> **Research:** 100% schema compliance — XGrammar, DOMINO

Requires model-level grammar constraint support (llama.cpp, vLLM).

---

## Implementation Order

| Priority | Item | Depends On | Impact | Status |
|----------|------|------------|--------|--------|
| P7 | F1: Enhanced Tool Descriptions | None | High | ✅ Done |
| P8 | F2: Structured Error Messages | None | High | ✅ Done |
| P9 | F3: Repetition Detection | None | Medium | ✅ Done |
| P10 | R1: Exponential Backoff | F2 | Medium | ✅ Done |
| P11 | M1: Evaluation States | F2, F3 | High | ✅ Done |
| P12 | V1: Execution Oracle | M1 | High | ✅ Done |
| P13 | M2: Self-Refine Loop | M1, V1 | High | ✅ Done |
| P14 | R2: Circuit Breaker | R1 | Low | ⬜ |
| P15 | M3: Reflection Memory | M2 | Medium | ✅ Done |
| P16 | V2: Goal Drift Detection | M1 | Medium | ✅ Done |
| P17 | A1: Mixed-Refinement | M2 | Medium | ✅ Done |
| P18 | A2: Undo-and-Retry | V1 | Low | ⬜ |

---

## Later: Swarm & Parallelism

> **Papers:** arXiv:2502.00674, arXiv:2510.05077

Multiple workers, varied temperatures, consensus aggregation.
Consider after Layer 3 complete.

---

## Model Compliance Findings

**Key Insights from Testing:**

1. **Small models are literal-minded** — `r - 50` example caused subtraction from ALL results
2. **NO examples in tool descriptions** — small models copy them blindly
3. **Small models need more steps** — 4+ for basic responses
4. **Explicit prompts work** — "call final_answer(answer: 'Hello!')" beats vague instructions
5. **External validation essential** — small models can't self-correct reasoning

**What Fixed Our Tests:**
- Removed `- 50` examples (literal interpretation)
- Replaced with safe `* 2` or `+ 10` examples
- Improved error hints with concrete syntax
- Removed red herrings from task descriptions

---

## Research References

| Topic | Source | Finding |
|-------|--------|---------|
| Tool descriptions | OpenAI, Anthropic | "Most important factor" |
| Self-Refine | arXiv:2303.17651 | 20% improvement |
| Reflexion | arXiv:2303.11366 | 91% HumanEval with memory |
| Self-correction limits | ICLR 2024 | SLMs need external feedback |
| Pre-Act planning | arXiv:2505.09970 | 70% improvement |
| STRATUS | NeurIPS 2025 | 150% with undo-retry |
| Natural Language Tools | arXiv:2510.14453 | 18.4% over JSON schemas |
| AgentPRM | arXiv:2511.08325 | Promise/progress scoring |
| Goal drift | arXiv:2505.02709 | Multi-action monitoring |

---

## Principles

- **Ship it**: Working software over architecture
- **One agent type**: All agents write Ruby code
- **Test-first**: MockModel enables deterministic, zero-cost testing
- **Ruby 4.0**: Data.define, pattern matching, endless methods
- **Forward only**: No backwards compatibility, delete unused code
