# smolagents Development Guide

## DSL Reference

### AgentBuilder

```ruby
Smolagents.agent
  .model { Model }                    # Required: LLM instance
  .tools(:search, :web)               # Tool symbols or instances
  .tool(:name, "desc") { |args| }     # Inline tool
  .as(:researcher)                    # Persona (alias: .persona)
  .max_steps(10)                      # Step limit
  .instructions("Be concise")         # Custom system prompt
  .planning(interval: 3)              # Replanning every N steps
  .memory(budget: 50_000)             # Token budget
  .evaluation(enabled: true)          # Self-evaluation
  .refine(max_iterations: 3)          # Self-refinement
  .can_spawn(max_depth: 2)            # Enable sub-agents
  .managed_agent(agent, as: "helper") # Static sub-agent
  .on(:step_completed) { |e| }        # Event subscription
  .build                              # -> Agent
```

### ModelBuilder

```ruby
Smolagents.model(:openai)
  .id("gpt-4")
  .temperature(0.7)
  .with_retry(max_attempts: 3)
  .with_fallback { backup_model }
  .with_circuit_breaker(threshold: 5)
  .with_health_check(cache_for: 5)
  .prefer_healthy
  .build                              # -> Model
```

### TeamBuilder

```ruby
Smolagents.team
  .model { coordinator }
  .agent(researcher, as: "researcher")
  .agent(writer, as: "writer")
  .coordinate("Research then write")
  .build                              # -> Agent (coordinator)
```

## Development Recipes

### Adding a Concern

```
1. Check registrations.rb — don't duplicate existing concerns
2. Create: lib/smolagents/concerns/my_feature.rb (<=100 lines)
3. Register: lib/smolagents/concerns/registrations.rb
4. Spec: spec/smolagents/concerns/my_feature_spec.rb
5. Include in agent/model/tool as needed
```

### Adding a Type

```
1. Create: lib/smolagents/types/my_config.rb (Data.define)
2. Add .default factory method
3. Spec with shared examples: "a frozen type", "a data type"
4. Predicate methods: enabled? / Immutable updates: with_threshold(val)
```

### Adding a Builder Method

Builders are immutable — `derive()` returns a new instance with updated config.

```ruby
def my_option(value)
  derive(my_option: value)
end
```

### Adding a Tool

```ruby
class MyTool < Tool
  self.tool_name = "my_tool"
  self.description = "What this tool does"
  self.inputs = { query: { type: "string", description: "The query" } }
  self.output_type = "string"
  def execute(query:) = # implementation
end
```

Register in `lib/smolagents/tools.rb` so it resolves from symbol `:my_tool`.

### Adding an Event Type

Register in `lib/smolagents/events/registry.rb`:

```ruby
register :my_event,
         category: :lifecycle,
         fields: { data: "Description" },
         description: "When this fires"
```

Emit via: `emit :my_event, data: value`

## Event-Driven Architecture

Two composable modules — include what you need:

| Module | Purpose |
|--------|---------|
| `Events::Emitter` | Emit events (models, tools, agents) |
| `Events::Consumer` | Subscribe to events (observers, agents) |

```ruby
# Emit events
emit :step_completed, step_number: 1
emit(:model_generation) { api.call }  # Block captures duration_ms

# Subscribe
on(:error_occurred) { |e| alert(e) }  # Single event
on_lifecycle { |e| track(e) }        # Category subscription
```

**Key principle:** No instrumentation — everything is event-driven.
