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

**Builder methods:**
- **Required:** `.model { }`
- **Tools:** `.tools(...)`, `.tool(:name, "desc") { }`, `.authorized_imports(...)`
- **Config:** `.as(:persona)`, `.max_steps(n)`, `.instructions("...")`, `.executor(e)`, `.logger(l)`
- **Features:** `.memory(budget:, strategy:)`, `.planning(interval:)`, `.refine(max_iterations:)`, `.evaluation(enabled:)`, `.observe(:with_summary)` or `.observe(:structure_only)`
- **Multi-agent:** `.can_spawn(allow: [...])`, `.managed_agent(agent, as:)`, `.with(:concern)`
- **Events:** `.on(:event, &block)`, `.sync_events(enabled:)`, plus convenience methods:
  - `.on_step { }` → `:step_complete`
  - `.on_task { }` → `:task_complete`
  - `.on_tool { }` → `:tool_complete`
  - `.on_error { }` → `:error`
- **Execution:** `.build`, `.run(task)`, `.run_fiber(task)`

## Rules

- **100/10**: Modules ≤100 lines, methods ≤10 lines. RuboCop enforces.
- **Ruby 4.0**: `Data.define` for types, pattern matching for flow, endless methods
- **Test everything**: MockModel for fast deterministic tests
- **No legacy code**: This is a greenfield project. Zero tolerance for:
  - Deprecated methods, classes, or modules
  - Backwards-compatibility shims or aliases
  - Fallback/failover code paths for old behavior
  - Comments like "TODO: remove in v2" or "DEPRECATED"
  - Unused code kept "just in case"

  If something is unused, **delete it immediately**. No deprecation warnings, no grace periods.

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
├── servers/     # Server clients (llama.cpp router)
├── tools/       # Tool base + built-ins
└── types/       # Data.define domain types
```

## Server Clients

For inference servers with management APIs (llama.cpp router mode):

```ruby
# Connect to llama.cpp router
server = Smolagents::Servers::LlamaCpp.new(
  api_base: "https://llama-cpp.example.com"
)

# List models and status
server.models.each { |m| puts "#{m.id}: #{m.status}" }
server.loaded_models  # Only loaded ones
server.ready?("model-id")  # Check if ready

# Warmup a model (triggers auto-load)
server.warmup("LFM2.5-1.2B-Instruct-Q8_0")

# Get OpenAIModel for agent use
model = server.model("gemma-3n-E4B-it-Q8_0")
agent = Smolagents.agent.model { model }.build
```

## Shared Concerns

**IMPORTANT:** Before creating new formatting/utility code, check these shared concerns:

### Formatting (`lib/smolagents/concerns/formatting/`)

Unified formatting system for ALL output transformation:

```ruby
# Describe data structures for code agents
StructureFormatting.describe(data)
# => "result = Array[2]\n  Each element has keys: :title, :link\n  ..."

# Format as markdown/table/list
include Concerns::ResultFormatting
as_markdown, as_table, as_list

# Build LLM messages
include Concerns::MessageFormatting
format_system_message, format_user_message, format_tool_message
```

Sub-modules: `Results`, `ResultFormatting`, `MessageFormatting`, `StructureFormatting`

### Resilience (`lib/smolagents/concerns/resilience/`)

Retry policies, circuit breakers, rate limiting, fallbacks.

See **AGENTS.md** for detailed agent guidance.
