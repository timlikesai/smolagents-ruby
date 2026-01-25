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
- **Config:** `.as(:persona)` (alias: `.persona(:name)`), `.max_steps(n)`, `.instructions("...")`, `.executor(e)`, `.logger(l)`
- **Features:** `.memory(budget:, strategy:)`, `.planning(interval:)`, `.refine(max_iterations:)`, `.evaluation(enabled:)`, `.observe(:mode) { summarizer_model }` (modes: `:with_summary`, `:structure_only`)
- **Multi-agent:** `.can_spawn(allow:, allowed_tools:, inherit:, max_children:, max_depth:, max_steps:)`, `.managed_agent(agent, as:)`, `.with(:specialization)`
- **Events:** `.on(:event, &block)`, `.sync_events(enabled:)`, plus convenience methods:
  - `.on_step { }` → `:step_complete`
  - `.on_task { }` → `:task_complete`
  - `.on_tool { }` → `:tool_complete`
  - `.on_error { }` → `:error`
  - `.on_control_yielded { }` → `:control_yielded`
  - `.on_isolation { }` → `:tool_isolation_completed`
  - `.on_violation { }` → `:resource_violation`
- **Execution:** `.build`, `.run(task)`, `.run_fiber(task)`

### Team Builder

```ruby
team = Smolagents.team
  .model { OpenAIModel.new(model_id: "gpt-4") }
  .agent(Smolagents.agent.tools(:search), as: "researcher")
  .coordinate("First research, then summarize")
  .max_steps(50)
  .planning(interval: 5)
  .build
```

**Team methods:** `.model { }`, `.agent(builder, as:)`, `.coordinate(instructions)`, `.coordinator(:type)`, `.max_steps(n)`, `.planning(interval:)`, `.on_agent { }`

### Ralph Loop

```ruby
result = Smolagents.ralph_loop(
  agent: agent,
  prompt: "Iteratively improve the solution",
  max_iterations: 10,
  completion_promise: "All tests pass"
)
```

### Model Builder

```ruby
model = Smolagents.model(:openai)
  .id("gpt-4")
  .temperature(0.7)
  .with_retry(max_attempts: 3, backoff: :exponential)
  .with_fallback { Smolagents.model(:ollama).id("llama3").build }
  .with_health_check(cache_for: 30)
  .with_circuit_breaker(threshold: 5, reset_after: 60)
  .with_queue(max_depth: 100)
  .prefer_healthy
  .build
```

**Model methods:** `.id(name)`, `.temperature(n)`, `.max_tokens(n)`, `.timeout(n)`, `.api_key(key)`
**Reliability:** `.with_retry(...)`, `.with_fallback { }`, `.with_health_check(...)`, `.with_circuit_breaker(...)`, `.with_queue(...)`, `.prefer_healthy`
**Callbacks:** `.on_failover { }`, `.on_error { }`, `.on_recovery { }`, `.on_model_change { }`, `.on_queue_wait { }`

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

### Executor Limitations

The executor accepts these parameters but they are not yet implemented:

- **`timeout`**: Accepted but execution timeout is not enforced
- **`memory_mb`**: Accepted but memory limits are not enforced
- **stdlib whitelist**: Safe stdlib methods (`JSON.parse`, `Time.now`, `Math.sqrt`) are currently blocked; no whitelist mechanism exists

These are accepted for API stability but have no effect until implemented.

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
Concerns::StructureFormatting.describe(data)
# => "result = Array[2]\n  Each element has keys: :title, :link\n  ..."

# Format as markdown/table/list (requires `data` accessor)
include Concerns::ResultFormatting
as_markdown, as_table, as_list

# Format messages for LLM APIs
include Concerns::MessageFormatting
format_messages_for_api, format_single_message, format_tool_calls
```

Sub-modules: `Results`, `ResultFormatting`, `MessageFormatting`, `StructureFormatting`

### Resilience (`lib/smolagents/concerns/resilience/`)

Retry policies, circuit breakers, rate limiting, fallbacks.

See **AGENTS.md** for detailed agent guidance.
