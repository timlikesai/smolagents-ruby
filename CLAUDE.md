# smolagents-ruby

Agents that think in Ruby 4.0.

## DSL

```ruby
agent = Smolagents.agent
  .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
  .tools(:search, :web)
  .as(:researcher)
  .planning
  .build

result = agent.run("Find the latest Ruby release notes")
```

**Builder methods:** `.model { }` (required), `.tools(...)`, `.tool(:name, "desc") { }`, `.as(:persona)`, `.memory(budget:, strategy:)`, `.planning`, `.can_spawn(allow: [...])`, `.refine(max_iterations:)`, `.evaluate(on: :each_step)`

## Rules

- **100/10**: Modules ≤100 lines, methods ≤10 lines. RuboCop enforces.
- **Ruby 4.0**: `Data.define` for types, pattern matching for flow, endless methods
- **Test everything**: MockModel for fast deterministic tests
- **No backwards compat**: Delete unused code, no legacy shims

## Commands

```bash
rake ci            # Full CI (lint + spec + doctest) - SAME AS GITHUB
rake commit_prep   # FIX → STAGE → VERIFY (before every commit!)
rake spec          # Run tests
rake spec_fast     # Tests excluding slow/integration
```

**Pre-commit hooks check STAGED content.** Always `rake commit_prep`.

## GitHub

```bash
gh issue list                          # View open issues
gh issue list -l "ready,effort-small"  # Filter by labels
gh issue create                        # Create new issue
gh pr create                           # Create PR (use "Fixes #N" in body)
gh pr checks                           # View CI status
```

### Labels

| Category | Labels | Purpose |
|----------|--------|---------|
| Priority | `P0-critical`, `P1-high`, `P2-medium`, `P3-low` | Urgency |
| Effort | `effort-small`, `effort-medium`, `effort-large` | Complexity |
| Status | `needs-triage`, `ready`, `blocked`, `needs-info` | Workflow |
| Area | `area-core`, `area-tools`, `area-models`, `area-builders` | Component |
| Special | `copilot`, `good first issue`, `help wanted` | Contributor |

### Copilot Integration

Issues labeled `copilot` are suitable for GitHub Copilot coding agent:
```bash
gh issue edit 46 --add-label copilot  # Mark for Copilot
```

Requirements for Copilot-ready issues:
- Clear acceptance criteria with checkboxes
- Priority label (P0-P3)
- Effort estimate label

## Testing

```ruby
model = Smolagents::Testing::MockModel.new(
  responses: ['result = search(query: "Ruby")', 'final_answer(answer: result)']
)
agent = Smolagents.agent.model { model }.tools(:search).build
result = agent.run("Find Ruby info")
expect(model).to be_exhausted
```

## Architecture

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

See **AGENTS.md** for detailed agent guidance.
