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
| Inspection | Full call history | Full call history |

---

## Current Status

| Metric | Value |
|--------|-------|
| RSpec Tests | Passing (93% coverage) |
| YARD Doctests | 46 runs, 42 assertions, 0 failures |
| Agent Type | Unified (all agents write Ruby) |

---

## Current Atoms

Build agents with composable primitives:

```ruby
.model { }                    # WHAT thinks (required)
.tools(...)                   # WHAT it uses (optional)
.tool(:name, "desc") { }      # Inline tool definition
.as(:persona)                 # HOW it behaves (optional)
.can_spawn(allow: [...])      # Enable sub-agent spawning
```

---

## Completed Work

### P0 - One Agent Type ✅

All agents write Ruby code. No ToolAgent, no mode selection.

```ruby
agent = Smolagents.agent
  .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
  .tools(:search, :web)
  .as(:researcher)
  .build
```

### P1 - Memory & Context Management ✅

Memory management with token budgets and strategies:

```ruby
agent = Smolagents.agent
  .model { m }
  .memory(budget: 100_000, strategy: :hybrid, preserve_recent: 5)
  .build
```

### P2 - Multi-Agent Hierarchies ✅

Model palette, spawn capability, context inheritance:

```ruby
Smolagents.configure do |config|
  config.models do |m|
    m = m.register :router, -> { OpenAIModel.lm_studio("gemma-3n-e4b") }
    m = m.register :researcher, -> { AnthropicModel.new("claude-sonnet-4-20250514") }
    m
  end
end

agent = Smolagents.agent
  .model(:router)
  .can_spawn(allow: [:researcher], inherit: :observations)
  .build
```

### P3 - Pre-Act Planning ✅

70% improvement in Action Recall (arXiv:2505.09970):

```ruby
agent = Smolagents.agent
  .model { m }
  .planning           # Enable with default interval (3)
  .build
```

### P4 - Testing Infrastructure ✅

Deterministic, fast, zero-cost agent testing:

| Component | Description |
|-----------|-------------|
| `MockModel` | Scriptable model with queued responses |
| `MockCall` | Data.define for inspecting generate() calls |
| `Helpers` | Factory methods for common test setups |
| `Matchers` | RSpec matchers for agent assertions |
| `SpyTool` | Records all tool calls for verification |
| `ModelBenchmark` | Evaluate model compatibility |
| **YARD Doctests** | All documentation examples tested in CI |

#### Documentation Testing (NEW)

All YARD `@example` blocks are now tested:

```ruby
# In spec/doctest_helper.rb:
# - Mock OpenAI and Anthropic clients (no real API calls)
# - Set dummy API keys
# - 46 examples tested, 42 assertions

# Run with:
bundle exec rake yard:doctest
```

GitHub Actions workflow (`.github/workflows/docs.yml`) runs doctests on every PR.

### P5 - Inline Tool Definitions ✅

Define tools where you need them - no separate class required:

```ruby
# Define inline - same atoms, less ceremony
agent = Smolagents.agent
  .tool(:weather, "Get weather for a city", city: String) { |city:| fetch_weather(city) }
  .model { m }
  .build

# Lambda conversion - same thing, different syntax
get_weather = ->(city:) { fetch_weather(city) }
agent = Smolagents.agent
  .tool(:weather, "Get weather", &get_weather)
  .model { m }
  .build
```

**Implementation:** `InlineTool` is a `Data.define` that wraps a block as a callable tool with automatic Ruby type to JSON Schema conversion.

### P6 - Self-Spawning Agents ✅

Constrained agent spawning via structured parameters (not arbitrary code eval):

```ruby
# Parent agent gets spawn capability
agent = Smolagents.agent
  .model(:router)
  .can_spawn(allow: [:researcher, :analyst], tools: [:search, :web])
  .build

# LLM can spawn sub-agents with toolkits or individual tools:
# spawn_agent(task: "Research Ruby 4", persona: "researcher", tools: ["search"])
# spawn_agent(task: "Summarize findings", persona: "analyst")  # No extra tools needed
```

**Why Constrained > Eval:**
- LLM fills JSON parameters, not Ruby code
- Only allowed personas/tools can be used
- Easy to test with MockModel
- Predictable, auditable behavior

**Implementation:** `SpawnAgentTool` validates persona/tools, builds sub-agent using existing DSL, and returns formatted result.

---

## Next: Documentation Examples Enhancement

Now that documentation examples are testable, we can build comprehensive examples that:

1. **Show real usage patterns** - Examples demonstrate actual API usage
2. **Are tested in CI** - Every example runs on every PR
3. **Stay current** - Broken examples fail the build

### Priority Items

| File | Current Examples | Enhancement |
|------|-----------------|-------------|
| `lib/smolagents.rb` | Basic entry points | Add more entry point examples |
| `lib/smolagents/agents/agent.rb` | Minimal | Full lifecycle examples |
| `lib/smolagents/tools/*.rb` | Basic instantiation | Tool chaining, error handling |
| `lib/smolagents/testing/*.rb` | API overview | Step-by-step testing patterns |
| `lib/smolagents/builders/*.rb` | Builder patterns | Configuration scenarios |

### Example Enhancement Patterns

**Before (basic):**
```ruby
# @example Using the registry
#   Smolagents::Tools.get("final_answer").class.ancestors.include?(Tool)  #=> true
```

**After (comprehensive):**
```ruby
# @example Using the registry
#   # Get a tool by name
#   tool = Smolagents::Tools.get("duckduckgo_search")
#   tool.name  #=> "duckduckgo_search"
#
#   # List all available tools
#   Smolagents::Tools.names.include?("final_answer")  #=> true
#
#   # Tools are singletons - same instance returned
#   Smolagents::Tools.get("final_answer").object_id == Smolagents::Tools.get("final_answer").object_id  #=> true
```

### Testing Infrastructure for Examples

The `spec/doctest_helper.rb` provides:

```ruby
# Mock clients (no real API calls)
module OpenAI::Client
  def chat(parameters:)
    { "choices" => [{ "message" => { "content" => "Mock response" } }] }
  end
end

# Dummy API keys
ENV["ANTHROPIC_API_KEY"] = "test-key-for-doctest"
ENV["OPENAI_API_KEY"] = "test-key-for-doctest"
```

This enables examples like:
```ruby
# @example Using OpenAI-compatible models
#   model = Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b")
#   model.is_a?(Smolagents::Models::Model)  #=> true
```

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

## Completed Log

| Date | Summary |
|------|---------|
| 2026-01-16 | P5+P6 complete: Inline tool definitions + self-spawning agents |
| 2026-01-16 | Documentation testing: YARD doctests, mocked clients, CI workflow |
| 2026-01-16 | P4 complete: Testing infrastructure with MockModel, matchers |
| 2026-01-16 | P2 complete: Multi-agent spawn with model palette |
| 2026-01-16 | P1 complete: Memory management with token budget |
| 2026-01-16 | P3 complete: Pre-Act planning with flexible DSL |
| 2026-01-16 | P0 complete: unified Agent, all tests pass |

---

## Principles

- **Ship it**: Working software over architecture
- **One agent type**: All agents write Ruby code
- **Test-first**: MockModel enables deterministic, zero-cost testing
- **Documentation is tested**: Every example runs in CI
- **Ruby 4.0**: Data.define, pattern matching, endless methods
- **Scope by default**: Children get minimum context
- **Forward only**: No backwards compatibility, delete unused code
