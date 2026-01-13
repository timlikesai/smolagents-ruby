# Builder Vision: Core Features Built-In

This document shows the target state for all builders with validation, help, and immutability controls as core features.

## Design Philosophy

**Essential Features (not nice-to-have):**
1. **Validation** - Catch errors early with helpful messages
2. **Introspection** - `.help` for REPL-friendly development
3. **Immutability** - `.freeze!` for production safety
4. **Consistency** - All builders follow the same patterns
5. **Discoverability** - Methods are self-documenting

## Example: ModelBuilder with Core Features

```ruby
# REPL-friendly help system
builder = Smolagents.model(:openai)
builder.help
# =>
# ModelBuilder - Available Methods
# ============================================================
#
# Required:
#   .id(model_id)
#     Set the model identifier (e.g., "gpt-4", "claude-3-opus")
#
# Optional:
#   .api_key(key)
#     Set API authentication key
#   .temperature(temp) (aliases: temp)
#     Set temperature (0.0-2.0, default: 1.0)
#   .max_tokens(tokens)
#     Set maximum tokens in response (1-100000)
#   .timeout(seconds)
#     Set request timeout in seconds (1-600)
#   ...
#
# Current Configuration:
#   #<ModelBuilder type=openai model_id=nil>
#
# Pattern Matching:
#   case builder
#   in ModelBuilder[type_or_model:, configuration: { model_id: }]
#     # Match and destructure
#   end
#
# Build:
#   .build - Create the configured model

# Validation with helpful errors
builder.temperature(5.0)
# => ArgumentError: Invalid value for temperature: 5.0.
#    Set temperature (0.0-2.0, default: 1.0)

builder.timeout(-10)
# => ArgumentError: Invalid value for timeout: -10.
#    Set request timeout in seconds (1-600)

# Freeze for production safety
PRODUCTION_MODEL = Smolagents.model(:openai)
  .id("gpt-4")
  .api_key(ENV["OPENAI_API_KEY"])
  .temperature(0.7)
  .freeze!

# Later attempts to modify raise FrozenError
PRODUCTION_MODEL.temperature(0.5)
# => FrozenError: Cannot modify frozen ModelBuilder

# Pattern matching support (via Data.define)
case PRODUCTION_MODEL
in ModelBuilder[type_or_model: :openai, configuration: { model_id:, temperature: }]
  puts "OpenAI #{model_id} at temp #{temperature}"
end
# => "OpenAI gpt-4 at temp 0.7"

# Convenience aliases for ergonomics
builder
  .id("gpt-4")
  .temp(0.7)           # alias for temperature
  .tokens(4000)        # alias for max_tokens
  .key(ENV["KEY"])     # alias for api_key
  .build
```

## Example: AgentBuilder with Core Features

```ruby
builder = Smolagents.agent(:code)
builder.help
# =>
# AgentBuilder - Available Methods
# ============================================================
#
# Required:
#   .model { block }
#     Set model (required) - Block should return a Model instance
#
# Optional:
#   .tools(*tools) (aliases: add_tools, with_tools)
#     Add tools by name or instance
#   .max_steps(n) (aliases: steps)
#     Set maximum execution steps (1-1000, default: 10)
#   .planning(interval:, templates:)
#     Configure planning - interval: steps between plans
#   .instructions(text) (aliases: prompt, system_prompt)
#     Set custom instructions for the agent
#   ...
#
# Callbacks:
#   .on_step_start { |step| }
#     Called before each step
#   .on_step_complete { |step| }
#     Called after each step
#   .on_task_complete { |result| }
#     Called when task finishes
#   ...

# Validation
builder.max_steps(-5)
# => ArgumentError: Invalid value for max_steps: -5.
#    Set maximum execution steps (1-1000, default: 10)

builder.tools(:nonexistent_tool)
# => ArgumentError: Unknown tool: nonexistent_tool.
#    Available: google_search, visit_webpage, calculator, ...

# Convenience aliases
agent = Smolagents.agent(:code)
  .model { my_model }
  .add_tools(:search)           # alias for .tools
  .steps(15)                    # alias for .max_steps
  .prompt("You are helpful")    # alias for .instructions
  .on_step_complete { |s| log(s) }
  .build

# Pattern matching
case agent_builder
in AgentBuilder[agent_type: :code, configuration: { max_steps:, tools: }]
  puts "Code agent with #{max_steps} steps, #{tools.size} tools"
end
```

## Example: TeamBuilder with Core Features

```ruby
builder = Smolagents.team
builder.help
# =>
# TeamBuilder - Available Methods
# ============================================================
#
# Required:
#   .agent(agent_or_builder, as:)
#     Add an agent to the team - as: name for the agent
#
# Optional:
#   .model { block }
#     Set shared model for coordinator
#   .coordinator(type) (default: :code)
#     Set coordinator agent type (:code or :tool_calling)
#   .coordinate(instructions) (aliases: instructions)
#     Set coordination instructions
#   .tools(*tools)
#     Add tools directly to coordinator
#   ...

# Validation
builder.coordinator(:invalid)
# => ArgumentError: Invalid value for coordinator: :invalid.
#    Set coordinator agent type (:code or :tool_calling)

builder.build
# => ArgumentError: Missing required configuration: agent.
#    At least one agent required. Use .agent(agent, as: 'name')

# Convenience
team = Smolagents.team
  .model { my_model }
  .agent(researcher, as: "researcher")
  .agent(writer, as: "writer")
  .instructions("Research then write")   # alias for .coordinate
  .tools(:web_search)                    # tools for coordinator
  .coordinator(:tool_calling)
  .freeze!                               # freeze for production
```

## Unified Builder Factory (Phase 2)

```ruby
# Create custom builders using the same foundation
CustomBuilder = Smolagents::DSL.Builder(:target, :config) do
  # Automatically gets: validation, help, freeze!, pattern matching

  builder_method :custom_setting,
    description: "Set custom value (1-100)",
    validates: ->(v) { (1..100).cover?(v) },
    aliases: [:setting]

  def custom_setting(value)
    validate!(:custom_setting, value)
    check_frozen!
    with_config(custom_setting: value)
  end

  def build
    validate_required!
    # ... create object
  end
end

# Usage is identical to built-in builders
builder = CustomBuilder.create(:my_target)
builder.help           # Shows methods
builder.setting(50)    # Validates
builder.freeze!        # Freezes
builder.build          # Creates
```

## Implementation Approach

### 1. Enhance Base Module (Already Started)
- ✅ Validation framework with `builder_method` DSL
- ✅ `.help` introspection
- ✅ `.freeze!` immutability
- ✅ Error handling helpers

### 2. Integrate into All Builders
- [ ] ModelBuilder includes Base, adds method registrations
- [ ] AgentBuilder includes Base, adds method registrations
- [ ] TeamBuilder includes Base, adds method registrations

### 3. Add Convenience Aliases
- [ ] ModelBuilder: `.temp`, `.tokens`, `.key`
- [ ] AgentBuilder: `.steps`, `.add_tools`, `.prompt`
- [ ] TeamBuilder: `.instructions` (alias for `.coordinate`)

### 4. Add Callback Helpers
- [ ] AgentBuilder: `.on_step_start`, `.on_step_complete`, `.on_task_complete`
- [ ] TeamBuilder: `.on_step_start`, `.on_step_complete`, `.on_agent_call`

### 5. Comprehensive Testing
- [ ] Validation tests for all builders
- [ ] Help system tests
- [ ] Freeze functionality tests
- [ ] Pattern matching examples
- [ ] Composition tests

## Benefits of This Approach

1. **Catch Errors Early** - Validation happens at setter time, not build time
2. **Self-Documenting** - `.help` shows exactly what's available
3. **Production-Safe** - `.freeze!` prevents accidental modification
4. **Consistent** - All builders work the same way
5. **Discoverable** - REPL-friendly, no need to read docs
6. **LLM-Friendly** - Help output is perfect for LLM consumption
7. **Pattern Matching** - Data.define enables powerful matching
8. **Extensible** - Easy to create custom builders with same features

## Pattern Matching Use Cases

```ruby
# Route based on builder state
def configure_model(builder)
  case builder
  in ModelBuilder[type_or_model: :openai]
    builder.timeout(30)
  in ModelBuilder[type_or_model: :anthropic]
    builder.timeout(60)
  in ModelBuilder[configuration: { existing_model: }]
    # Wrapping existing model, no changes needed
    builder
  end
end

# Extract configuration
case agent_builder
in AgentBuilder[configuration: { max_steps:, tools: }]
  puts "Agent config: #{max_steps} steps, #{tools.size} tools"
end

# Conditional logic based on agent type
def add_monitoring(builder)
  case builder
  in AgentBuilder[agent_type: :code]
    builder.on_step_complete { |step| monitor_code_step(step) }
  in AgentBuilder[agent_type: :tool_calling]
    builder.on_step_complete { |step| monitor_tool_call(step) }
  end
end
```

This vision ensures that validation, help, and immutability are **core features** built into every builder from the foundation, not afterthoughts.
