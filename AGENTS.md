# AGENTS.md

Agent guidance for smolagents-ruby.

## Dev Environment

```bash
bundle install                    # Install dependencies
```

Ruby 4.0+ required. Local model server (LM Studio, Ollama) recommended for development.

### Project Layout

```
lib/smolagents/
├── agents/      # Thin facade
├── builders/    # Fluent DSL
├── concerns/    # Composable behaviors (≤100 lines each)
├── events/      # Event system with registry
├── executors/   # Sandboxed code execution
├── models/      # LLM adapters (OpenAI, Anthropic)
├── tools/       # Tool base + built-ins
└── types/       # Data.define domain types
```

## Code Style

- **100/10 Rule**: Modules ≤100 lines, methods ≤10 lines (RuboCop enforces)
- **Ruby 4.0 idioms**: `Data.define` for types, pattern matching for flow, endless methods
- **No backwards compat**: Delete unused code, no legacy shims

```ruby
# Data.define with deconstruct_keys
Message = Data.define(:role, :content) do
  def deconstruct_keys(_) = { role:, content: }
end

# Endless methods
def success? = state == :success

# Pattern matching
case step
in ActionStep[tool_calls:] if tool_calls.any? then execute_tools(tool_calls)
in FinalAnswerStep[answer:] then return answer
end
```

## Testing

CI runs on every PR via GitHub Actions (`.github/workflows/ci.yml`).

```bash
rake ci            # Full CI check (lint + spec + doctest) - SAME AS GITHUB
rake spec          # Run tests only
rake spec_fast     # Tests excluding slow/integration
rake lint          # RuboCop only
```

Use `MockModel` for deterministic tests:

```ruby
model = Smolagents::Testing::MockModel.new(
  responses: ['result = search(query: "Ruby")', 'final_answer(answer: result)']
)
agent = Smolagents.agent.model { model }.tools(:search).build
result = agent.run("Find Ruby info")
expect(model).to be_exhausted
```

## PR Instructions

Before committing:

```bash
rake commit_prep   # FIX → STAGE → VERIFY (run before every commit!)
```

Pre-commit hooks validate staged content. Always use `rake commit_prep` to ensure hooks see the right state.

### PR Title Format

Use conventional commits: `fix:`, `feat:`, `docs:`, `refactor:`, `test:`, `chore:`

### Linking Issues

Reference issues in PR body with `Fixes #N` or `Closes #N`.

## Issue Tracking

Work items tracked in GitHub Issues.

```bash
gh issue list      # View open issues
gh issue view N    # View issue details
gh issue create    # Create new issue
```

## Tool Descriptions

When creating tools, follow this format:

```ruby
class WeatherTool < Smolagents::Tool
  name "weather"
  description "Get weather. Use when: need current conditions. Do NOT use: forecasts. Returns: Hash."
  inputs city: { type: "string", description: "City name" }
  output_type "object"
  def execute(city:) = fetch_weather(city)
end
```

Tool descriptions must: 3+ sentences, include "Use when" / "Do NOT use", describe return format, NO examples.
