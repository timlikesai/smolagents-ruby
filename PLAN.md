# smolagents-ruby

Delightfully simple agents that think in Ruby.

---

## Now: P0 - One Agent Type

**Goal:** Delete ToolAgent. All agents write Ruby code.

### What to Remove

- `lib/smolagents/agents/tool.rb` - ToolAgent class
- `.with(:code)` DSL - no mode selection needed
- Pre-built agents (researcher, fact_checker, etc.) - use Personas instead
- Tool-calling prompts - no JSON format to explain

### What to Keep

- `lib/smolagents/agents/agent.rb` - the one Agent
- `lib/smolagents/agents/code.rb` - merge into Agent, then delete
- Ruby execution via sandbox
- Toolkits, Personas, Specializations (composable atoms)

### The Interface

```ruby
# Minimal agent
agent = Smolagents.agent
  .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
  .build

result = agent.run("What's 2+2?")
# Agent writes: final_answer(2 + 2)
# => "4"

# With tools
agent = Smolagents.agent
  .model { my_model }
  .tools(:search, :web)
  .build

result = agent.run("Find the latest Ruby release")
# Agent writes Ruby code, calls tools, returns answer

# With persona
agent = Smolagents.agent
  .model { my_model }
  .tools(:search)
  .as(:researcher)
  .build
```

### Testing Strategy

Every example must have a deterministic test:

```ruby
# Mock the model to return predictable responses
RSpec.describe "Agent examples" do
  let(:mock_model) do
    instance_double(Smolagents::OpenAIModel).tap do |m|
      allow(m).to receive(:generate).and_return(
        Types::ChatMessage.new(role: "assistant", content: "final_answer(4)")
      )
    end
  end

  it "runs minimal agent" do
    agent = Smolagents.agent.model { mock_model }.build
    result = agent.run("What's 2+2?")
    expect(result.output).to eq("4")
  end
end
```

### Tasks

| Task | Status |
|------|--------|
| Back up pre-built agents to .archive/ | Done |
| Back up P4-P7 to ROADMAP.md | Done |
| Delete `lib/smolagents/agents/tool.rb` | |
| Delete pre-built agent classes | |
| Merge Code into Agent | |
| Remove `.with(:code)` from builder | |
| Update prompts to Ruby-native | |
| Add deterministic test examples | |
| Update README | |

---

## Next: P1 - Pre-Act Planning (70% improvement)

> **Paper:** http://arxiv.org/abs/2505.09970

Plan before acting. Highest-impact single feature.

```ruby
agent = Smolagents.agent
  .model { m }
  .planning              # Enable planning phase
  .build
```

---

## Then: P2 - Self-Refine (20% improvement)

> **Paper:** http://arxiv.org/abs/2303.17651

Generate → Feedback → Refine loop.

```ruby
result = Smolagents.refine
  .model { m }
  .generate("Write a summary")
  .feedback("What could be improved?")
  .max_iterations(3)
  .build
  .run
```

---

## Later: P3 - Swarm (6.6% + parallelism)

> **Papers:** http://arxiv.org/abs/2502.00674, http://arxiv.org/abs/2510.05077

Same model, varied temperatures, parallel execution.

```ruby
result = Smolagents.swarm
  .model { m }
  .workers(5)
  .aggregate(:confidence)
  .build
  .run("Research topic")
```

---

## Completed

| Date | Summary |
|------|---------|
| 2026-01-15 | Backed up P4-P7 to ROADMAP.md, pre-built agents to .archive/ |
| 2026-01-15 | UTF-8 sanitization, circuit breaker fixes |
| 2026-01-15 | Fiber-first execution, control requests, events |
| 2026-01-14 | Module organization, RuboCop compliance |

---

## Principles

- **Ship it**: Working software over architecture
- **One agent type**: If a model can't write Ruby, it can't agent
- **Test everything**: Mocked models for deterministic tests
- **Delete unused code**: Forward only, no backwards compat
