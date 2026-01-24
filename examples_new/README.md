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
├── memory/           # Memory management (planned)
├── teams/            # Multi-agent teams (planned)
└── advanced/         # Advanced patterns (planned)
```

## Running Examples

Each example has a corresponding spec file:

```bash
# Run all example tests
bundle exec rspec spec/examples/

# Run specific example tests
bundle exec rspec spec/examples/basics/
bundle exec rspec spec/examples/tools/
bundle exec rspec spec/examples/testing/
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

- [ ] Memory management examples
- [ ] Team builder examples
- [ ] Planning configuration examples
- [ ] Event handling examples
- [ ] Error recovery patterns
- [ ] Spawn/child agent examples
