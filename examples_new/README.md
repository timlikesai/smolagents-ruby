# Smolagents Examples

Comprehensive examples showcasing the smolagents DSL and testing patterns.

## Structure

```
examples_new/
├── basics/           # Getting started
│   └── 01_hello_world.rb
├── tools/            # Tool creation patterns
│   ├── 01_inline_tools.rb
│   └── 02_class_tools.rb
├── testing/          # Testing with MockModel
│   └── 01_mock_model.rb
├── memory/           # Memory management
│   └── 01_memory_basics.rb
├── teams/            # Multi-agent coordination
│   ├── 01_managed_agents.rb
│   └── 02_team_building.rb
└── advanced/         # Advanced patterns
    ├── 01_planning.rb
    ├── 02_refinement.rb
    └── 03_evaluation.rb
```

## Running Examples

Each example has a corresponding spec file:

```bash
# Run all example tests
bundle exec rspec spec/examples/

# Run specific category tests
bundle exec rspec spec/examples/basics/
bundle exec rspec spec/examples/tools/
bundle exec rspec spec/examples/testing/
bundle exec rspec spec/examples/memory/
bundle exec rspec spec/examples/teams/
bundle exec rspec spec/examples/advanced/
```

## Key Patterns

### Simple Agent

```ruby
agent = Smolagents.agent
  .model { model }
  .build

result = agent.run("Your task")
puts result.output
```

### Inline Tools

```ruby
agent = Smolagents.agent
  .model { model }
  .tool(:add, "Add numbers", a: Integer, b: Integer) { |a:, b:| a + b }
  .build
```

### Class-Based Tools

```ruby
class MyTool < Smolagents::Tool
  self.tool_name = "my_tool"
  self.description = "Does something"
  self.inputs = { value: { type: "string" } }

  def execute(value:)
    value.upcase
  end
end
```

### Memory Configuration

```ruby
agent = Smolagents.agent
  .model { model }
  .memory(budget: 50_000, strategy: :mask, preserve_recent: 5)
  .build
```

### Multi-Agent Teams

```ruby
helper = Smolagents.agent.model { helper_model }.build

team = Smolagents.team
  .model { coordinator_model }
  .agent(helper, as: "researcher")
  .coordinate("Delegate research tasks")
  .build
```

### Planning Mode

```ruby
agent = Smolagents.agent
  .model { model }
  .planning(interval: 5)  # Re-plan every 5 steps
  .build
```

### Self-Refinement

```ruby
agent = Smolagents.agent
  .model { model }
  .refine(max_iterations: 3, feedback: :execution)
  .build
```

### Testing with MockModel

```ruby
model = Smolagents::Testing::MockModel.new
model.queue_code_action('final_answer(answer: my_tool(value: "test"))')

agent = Smolagents.agent.model { model }.tools(MyTool.new).build
result = agent.run("Task")

expect(result.output).to eq("TEST")
expect(model).to be_exhausted
```

## Testing Patterns

- **Single step**: Use `final_answer(answer: tool(...))` - tool executes and returns
- **Nested tools**: `final_answer(answer: tool1(data: tool2(...)))` - chains work
- **Multi-step**: Requires `queue_evaluation_continue` between steps

## Gaps & TODOs

- [ ] Event handling examples
- [ ] Error recovery patterns
- [ ] Spawn/child agent examples (can_spawn)
- [ ] Observation mode examples
