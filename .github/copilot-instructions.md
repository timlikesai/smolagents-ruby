# Copilot Coding Agent Instructions

This repository is `smolagents-ruby`, a Ruby port of HuggingFace's Python smolagents library.

## Project Overview

AI agents that think in Ruby code. The gem provides:
- `CodeAgent` - writes and executes Ruby code
- `ToolCallingAgent` - uses JSON tool calling
- 10 built-in tools (web search, Wikipedia, etc.)
- Sandboxed code execution
- Model integrations (OpenAI, Anthropic)

## Commands

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop
bundle exec rubocop -A  # auto-fix

# Run single test file
bundle exec rspec spec/smolagents/tool_result_spec.rb
```

## Code Style

- Ruby 4.0+ required
- Use `Data.define` for immutable value objects
- Use `frozen_string_literal: true` in all files
- Follow RuboCop rules (run `bundle exec rubocop`)
- Prefer endless methods (`def foo = bar`)
- Use refinements for extensions (lexically scoped)

## Architecture

```
lib/smolagents/
├── agents/           # CodeAgent, ToolCallingAgent
├── models/           # OpenAI, Anthropic wrappers
├── tools/            # Tool base class, DSL
├── default_tools/    # 10 built-in tools
├── executors/        # Code execution (Ruby sandbox, Docker)
├── concerns/         # Shared mixins (HttpClient, Retryable, etc.)
├── monitoring/       # Logging, callbacks
├── memory.rb         # Agent memory/step history
├── tool_result.rb    # Chainable, Enumerable results
└── configuration.rb  # Global config
```

## Key Patterns

### Creating Tools
```ruby
class MyTool < Smolagents::Tool
  self.tool_name = "my_tool"
  self.description = "Does something"
  self.inputs = {
    "param" => { "type" => "string", "description" => "A parameter" }
  }
  self.output_type = "string"

  def forward(param:)
    "Result: #{param}"
  end
end
```

### ToolResult (chainable)
```ruby
result.select { |r| r[:score] > 0.5 }
      .sort_by(:score, descending: true)
      .take(5)
      .pluck(:title)
```

### Data Classes
```ruby
MyData = Data.define(:foo, :bar) do
  def to_h = { foo: foo, bar: bar }
end
```

## Testing

- Use RSpec with `webmock` for HTTP stubbing
- Mock tools with `instance_double`
- 737 tests total - all must pass

## When Working on Issues

1. Read the issue description carefully
2. Create a feature branch: `git checkout -b fix/issue-N-description`
3. Make changes following code style
4. Run `bundle exec rubocop -A` to fix style issues
5. Run `bundle exec rspec` - all tests must pass
6. Commit with descriptive message referencing issue
7. Push and create PR

## Security Notes

- LocalRubyExecutor has sandbox - don't bypass security checks
- Don't commit API keys or secrets
- Validate all user inputs
- URL validation prevents SSRF (see HttpClient concern)
