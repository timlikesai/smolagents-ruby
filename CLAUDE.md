# smolagents-ruby

Highly-testable agents that think in Ruby.

## The Vision

Build agents that feel native to Ruby. Not a Python port—a Ruby-first design using `Data.define`, pattern matching, and fluent APIs. The interface should be so obvious that documentation feels redundant.

```ruby
agent = Smolagents.agent
  .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
  .tools(:search, :web)
  .as(:researcher)
  .planning
  .build

result = agent.run("Find the latest Ruby release notes")
```

That's it. An agent, some tools, a task, a result.

---

## Principles

**Simple by Default**
The common case should be one line. Configuration is for when you need it, not before. If a feature requires explanation, simplify the feature.

**Ruby 4.0 Idioms**
`Data.define` for immutable types. Pattern matching for control flow. Endless methods for simple operations. Blocks for configuration. This isn't Ruby-flavored Python—it's Ruby.

**Forward Only**
No backwards compatibility. When something improves, adopt it everywhere. When code is unused, delete it. The codebase moves forward as a unit.

**100/10 Rule**
Modules ≤100 lines. Methods ≤10 lines. If you exceed these limits, decompose. Rubocop enforces this.

**Test Everything**
Every public method has a test. Use `MockModel` for deterministic, zero-cost testing. Tests should run fast—if slow, fix the code.

**Ship It**
Working software over architecture. Don't over-abstract before need. Don't add configuration without use cases.

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
.refine(max_iterations:)      # Self-refine loop (20% improvement)
.evaluate(on: :each_step)     # Progress evaluation
```

---

## Architecture

```
lib/smolagents/
├── agents/           # Agent class (thin facade)
├── builders/         # Fluent configuration DSL
├── concerns/         # Composable behaviors (see below)
│   ├── agents/       # Agent-specific concerns
│   ├── models/       # Model reliability, health
│   ├── api/          # HTTP, API keys, clients
│   ├── parsing/      # JSON, XML, HTML, critique
│   ├── resilience/   # Retry, circuit breaker
│   ├── validation/   # Execution oracle, goal drift
│   └── formatting/   # Results, messages
├── events/           # Event system (emitter, consumer)
├── executors/        # Sandboxed code execution
├── models/           # LLM adapters (OpenAI, Anthropic)
├── tools/            # Tool base class + built-ins
├── types/            # Data.define for domain concepts
└── runtime/          # Memory, spawning
```

**Core abstractions:**
- `Agent` - Thin facade that delegates to concerns
- `Model` - Talks to LLMs (OpenAI, Anthropic, local)
- `Tool` - Something an agent can use
- `ToolResult` - What a tool returns (chainable, immutable)
- `Concern` - Composable behavior module

---

## Concern Organization

Concerns are the primary decomposition mechanism. Each concern is ≤100 lines and does one thing.

**Naming pattern:**
```ruby
module Smolagents
  module Concerns
    module DomainName
      # Single responsibility
    end
  end
end
```

**Include pattern for simple concerns:**
```ruby
module MyFeature
  def self.included(base)
    base.attr_reader :my_config
  end

  private

  def initialize_my_feature(config: nil)
    @my_config = config
  end
end
```

**Include pattern for composite concerns (3+ sub-concerns):**
```ruby
module CompositeConcern
  def self.included(base)
    base.include(SubConcernA)
    base.include(SubConcernB)
    base.include(SubConcernC)
  end
end
```

**When to create a new concern:**
- Functionality is used by multiple classes
- Module exceeds 100 lines
- Clear single responsibility exists
- Behavior is optional/configurable

---

## Ruby 4.0 Patterns

**Data.define for immutable types:**
```ruby
ToolCall = Data.define(:id, :name, :arguments) do
  def to_s = "#{name}(#{arguments.map { "#{_1}: #{_2}" }.join(', ')})"

  # Factory methods
  def self.create(name:, arguments:)
    new(id: SecureRandom.uuid, name:, arguments:)
  end
end
```

**Always include `deconstruct_keys` for pattern matching:**
```ruby
ChatMessage = Data.define(:role, :content, :tool_calls) do
  def deconstruct_keys(_) = { role:, content:, tool_calls: }
end
```

**Pattern matching for control flow:**
```ruby
case step
in ActionStep[tool_calls:] if tool_calls.any?
  execute_tools(tool_calls)
in FinalAnswerStep[answer:]
  return answer
end
```

**Endless methods for simple operations:**
```ruby
def success? = state == :success
def name = @name.to_s.freeze
def model_id = @model&.model_id || "unknown"
```

**Predicate methods end in `?`:**
```ruby
def enabled? = @config&.enabled || false
def tool_calls? = tool_calls&.any? || false
```

---

## Commands

**CRITICAL: Pre-commit hooks check STAGED content, not files on disk.**

Always use `rake commit_prep` before committing. This ensures:
1. Code style issues are auto-fixed
2. Changes are staged
3. Staged content passes RuboCop (what the pre-commit hook checks)

```bash
# Agent workflow (use these)
rake commit_prep       # FIX → STAGE → VERIFY (use before every commit!)
rake fix               # Auto-fix RuboCop issues (files on disk)
rake lint              # Check code style (files on disk)
rake staged_lint       # Check staged content (simulates pre-commit)
rake spec              # Run test suite
rake spec_fast         # Run tests excluding slow/integration
rake check             # Full check: lint + spec
rake help              # Show all available tasks

# Makefile equivalents
make commit-prep       # Same as rake commit_prep
make fix               # Same as rake fix
make lint              # Same as rake lint
make test              # Same as rake spec

# Direct commands (when you know what you're doing)
bundle exec rspec spec/file:42   # Single example
bundle exec rubocop -A           # Lint + autofix (files on disk only!)
yard doctest                     # Run YARD examples
```

**Why `rake commit_prep` matters:**
- `bundle exec rubocop -A` fixes files on disk
- Pre-commit hook checks staged content (which may differ!)
- `rake commit_prep` fixes, stages, then verifies staged content matches

---

## Testing

**Use MockModel for agent tests:**
```ruby
model = Smolagents::Testing::MockModel.new(
  responses: [
    'result = search(query: "Ruby")',
    'final_answer(answer: result)'
  ]
)

agent = Smolagents.agent.model { model }.tools(:search).build
result = agent.run("Find Ruby info")

expect(model).to be_exhausted
expect(result.output).to include("Ruby")
```

**Test matchers:**
```ruby
expect(agent).to have_called_tool(:search).with(query: "Ruby")
expect(result).to be_success
expect(result.steps).to have_attributes(count: 2)
```

**If tests are slow:**
- HTTP calls → WebMock stubs
- Sleep in code → Remove it
- Heavy setup → Lazy initialization
- Real models → MockModel

---

## Creating Tools

```ruby
class WeatherTool < Smolagents::Tool
  name "weather"
  description <<~DESC
    Get current weather for a city.

    Use when: You need current weather conditions.
    Do NOT use when: You need forecasts or historical data.

    Returns: Hash with temperature, conditions, humidity.
  DESC

  inputs city: { type: "string", description: "City name" }
  output_type "object"

  def execute(city:)
    fetch_weather(city)
  end
end
```

**Tool description requirements:**
- 3-4+ sentences minimum
- Include "Use when" and "Do NOT use when"
- Describe return format
- NO examples (small models copy them literally)

---

## What We Avoid

- **God objects** — Decompose into concerns
- **Shotgun surgery** — Keep related code together
- **Feature envy** — Delegate to objects, don't query internals
- **Primitive obsession** — Use Data.define for value objects
- **Over-abstraction** — Don't abstract until you have 3 uses
- **Backwards compatibility** — Delete unused code
- **Python idioms** — Use Ruby patterns

---

## Model Testing Framework

```ruby
# Test a model
Smolagents.test(:model)
  .task("What is 2+2?")
  .expects { |out| out.include?("4") }
  .run(model)

# Define capability requirements
Smolagents.test_suite(:my_agent)
  .requires(:tool_use)
  .reliability(runs: 10, threshold: 0.95)
  .rank_models(candidates)
```

Key features:
- Orthogonal capabilities: `:text`, `:code`, `:tool_use`, `:reasoning`, `:vision`
- Auto-generate tests from tool schemas: `AutoGen.tests_for_tool(tool)`
- Declarative specs: `Smolagents.agent_spec(:name) { ... }`
- MockModel for fast unit tests, real models for compliance

---

## Project Tracking

Work items and decisions live in **PLAN.md**. That's the single source of truth.

Current priorities focus on architectural improvements:
1. Consolidate fragmented concerns (ReActLoop)
2. Extract runtime from god objects (Agent)
3. Split large monolithic concerns
4. Polish public API ergonomics

See PLAN.md for the full prioritized backlog.
