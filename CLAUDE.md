# smolagents-ruby

A Ruby 4.0 agent framework that demonstrates what Ruby can be when you commit fully to the language's evolution.

## How We Work

**Top of Intelligence**
Bring full capability to every response. Not the first thing that comes to mind—the best thing. Think before acting. When stuck, step back and reason from principles rather than pattern-matching on surface features.

**Yes, And**
Accept direction and build on it. Even when "and" leads somewhere imperfect, it maintains momentum and often reveals the right path. A wrong step forward teaches more than hesitation. When something isn't working, say so—but offer an alternative, don't just block.

**Consistency**
What's true in one message is true in the next. If we're Ruby 4.0, we're Ruby 4.0 everywhere. If we're forward-only, we don't suddenly maintain backwards compatibility. Principles aren't suggestions—they're the grammar of the codebase.

## The Vision

We're not porting Python to Ruby. We're reimagining what an agent framework looks like when built from the ground up with Ruby 4.0's capabilities: `Data.define` for immutable types, pattern matching for control flow, endless methods for expressiveness, Ractors for concurrency, and refinements for scoped extensions.

The result should feel inevitable—like this is how agents were always meant to be built in Ruby.

## Principles

**Forward Only**
We don't maintain backwards compatibility. When a pattern improves, we adopt it everywhere. When code becomes unused, we delete it. No `alias_method` shims, no fallback branches, no `_legacy` suffixes. The codebase moves forward as a unit.

**Event-Driven**
All coordination happens through typed events and queues. No `sleep()`. No `Timeout.timeout`. No polling loops. When something needs to wait, it blocks on a queue. When something happens, it emits an event. This makes the system deterministic, testable, and fast.

**Expressive Minimalism**
Less code that does more. A well-designed `Data.define` with five methods beats a class with fifty. Composition over inheritance. Refinements over monkey-patching. The goal is code that reads like documentation.

## Ruby 4.0

This is what our code looks like:

```ruby
# Immutable value objects with behavior
Outcome = Data.define(:state, :value, :error) do
  def success? = state == :success
  def failed? = !success?
  def then(&) = success? ? yield(value) : self
end

# Endless methods for simple operations
def ready? = state == :ready
def name = @name.to_s.freeze

# Pattern matching for control flow
case step
in ActionStep[tool_calls:] if tool_calls.any?
  execute_tools(tool_calls)
in FinalAnswerStep[answer:]
  return answer
end

# Thread::Queue for coordination (never sleep)
events = Thread::Queue.new
worker = Thread.new { loop { process(events.pop) } }
events.push(task)

# Refinements for scoped extensions
module OutcomeArrays
  refine Array do
    def successes = select(&:success?)
  end
end
```

This is what we avoid:

```ruby
Struct.new(:a, :b)              # Use Data.define
sleep(0.1)                       # Use queue.pop
Timeout.timeout(5) { }           # Use deadlines in execution
alias_method :old_name, :new     # Delete old_name instead
respond_to?(:new) ? new : old    # Just use new
```

## Architecture

```
lib/smolagents/
├── agents/        # CodeAgent writes Ruby, ToolCallingAgent uses JSON
├── builders/      # Fluent DSL: Smolagents.code.model{}.tools().build
├── events/        # Typed events + emitter/consumer pattern
├── executors/     # Sandboxed code execution (Ruby, Docker, Ractor)
├── models/        # LLM adapters (OpenAI, Anthropic, LiteLLM)
├── tools/         # Tool base class + registry + built-ins
├── types/         # Data.define types for all domain concepts
└── pipeline.rb    # Composable tool chains
```

**Key Design Decisions:**

- Tools return `ToolResult` objects that are chainable and pattern-matchable
- All I/O boundaries (HTTP, Docker) have timeouts; application code does not
- Events replace callbacks everywhere—subscribe with `.on(:event_name)`
- Builders validate eagerly and fail fast with helpful messages

## Testing

Tests complete in under 10 seconds. If they don't, something is wrong:
- Real HTTP calls → Add WebMock stubs
- Sleep in code → Replace with queue
- Slow setup → Lazy initialization

Run tests directly, never in background:
```bash
bundle exec rspec                    # Full suite
bundle exec rspec spec/path:42       # Single example
bundle exec rubocop -A               # Lint + autofix
```

## DSL Design

Simple and delightful APIs for humans and agents alike. Every DSL should:

**Compose** — Small pieces that combine into powerful expressions:
```ruby
goal_a & goal_b    # Both must succeed
goal_a | goal_b    # First success wins
pipeline.call(:search).select { }.pluck(:title)
```

**Flow** — Read like natural language, left to right:
```ruby
Goal.desired("Find papers")
    .expect_count(10..20)
    .expect_quality(0.8)
    .with_agent(researcher)
    .run!
```

**Match** — Pattern matching reveals intent:
```ruby
case result
in Goal[state: :success, value:]
  use(value)
in Goal[state: :error, error:]
  handle(error)
end
```

**Express** — Criteria over boilerplate:
```ruby
# Instead of validation methods scattered across classes:
goal.expect(:format, :json)
    .expect(:recency_days, 1..7)
    .expect(:sources, 3..10)
```

## Project Tracking

All work items, decisions, and progress tracked in **PLAN.md**. That is the single source of truth for what's done, in progress, and planned.

## Commands

```bash
bundle install                       # Dependencies
bundle exec rspec                    # Tests (<10s)
bundle exec rubocop -A               # Lint + autofix
ruby -c lib/path/file.rb             # Syntax check (Prism parser)
bundle exec yard doc                 # Generate documentation
```
