# AGENTS.md

Contributor guidance for smolagents-ruby. See **CLAUDE.md** for DSL reference.

## CRITICAL: Running Tests and Linting

**Use rake tasks. Do not filter output.**

```bash
rake spec          # Run all tests
rake spec_fast     # Skip slow/integration tests
rake ci            # Full CI: rubocop + tests
rake commit_prep   # Auto-fix, stage, verify
```

**Why this matters:**
- Rake tasks are configured for optimal output
- Full output is required to diagnose failures
- Timing failures need context to investigate
- Piping/grepping loses diagnostic information

**NEVER do this:**
```bash
bundle exec rspec ... | tail ...    # Loses stack traces
bundle exec rspec ... | grep ...    # Loses context
bundle exec rubocop ... | head ...  # Loses offense details
```

When investigating failures, you need the FULL output. If it's long, read it in sections.

---

## Setup

```bash
bundle install
```

Ruby 3.2+ required. Local model server (LM Studio, Ollama) recommended for development.

## Code Style

**100/10 Rule:** Modules ≤100 lines, methods ≤10 lines (RuboCop enforces).

```ruby
# Data.define for all types
Message = Data.define(:role, :content) do
  def self.create(role:, content:) = new(role:, content:)
end

# Endless methods for simple predicates
def success? = state == :success

# Pattern matching for control flow
case step
in ActionStep[tool_calls:] then execute_tools(tool_calls)
in FinalAnswerStep[answer:] then return answer
end
```

**No legacy code.** Delete unused code immediately. No deprecation warnings, no backwards-compatibility shims.

## Workflow

```bash
rake commit_prep   # Always run before committing
rake ci            # Same as GitHub Actions
```

**PR titles:** Use conventional commits (`fix:`, `feat:`, `refactor:`, `test:`, `docs:`)

**Link issues:** Include `Fixes #N` in PR body.

## Testing

Use `MockModel` for deterministic agent tests:

```ruby
model = Smolagents::Testing::MockModel.new(
  responses: ['search(query: "x")', 'final_answer(answer: result)']
)
expect(model).to be_exhausted
```

## Creating Tools

```ruby
class WeatherTool < Smolagents::Tool
  self.tool_name = "weather"
  self.description = "Get current weather. Use when: need conditions for a city. Do NOT use: forecasts or historical data. Returns: Hash with temp, conditions."
  self.inputs = { city: { type: "string", description: "City name" } }
  self.output_type = "object"

  def execute(city:) = fetch_weather(city)
end
```

**Description format:** 3+ sentences, include "Use when" / "Do NOT use", describe return type.

## Creating Concerns

1. Place in `lib/smolagents/concerns/` under appropriate category
2. Keep under 100 lines (extract types to `types/`)
3. Use stub methods for opt-in behavior
4. Include `Events::Emitter` if emitting events

```ruby
# concerns/agents/my_feature.rb
module Smolagents
  module Concerns
    module Agents
      module MyFeature
        def my_feature_enabled? = false  # Stub, overridden when enabled

        private

        def with_my_feature
          return yield unless my_feature_enabled?
          # Feature logic here
        end
      end
    end
  end
end
```

## Creating Types

All domain types go in `types/` using `Data.define`:

```ruby
# types/my_type.rb
module Smolagents
  module Types
    MyType = Data.define(:field1, :field2) do
      def self.create(field1:, field2: nil) = new(field1:, field2:)
    end
  end
end
```

## Multi-Model Agent Experiments

See `experiments/multi_model_agents/` for sophisticated agent patterns:

| Experiment | Pattern |
|------------|---------|
| 04_tiered_reasoning | Fast/big model routing |
| 05_research_swarm | Parallel agents + synthesis |
| 06_visual_analysis_pipeline | Vision → reasoning |
| 07_self_improving_agent | Meta-learning |
| 09_distributed_analyst | Combined system |

**Testing multi-model agents:**

```ruby
# Build test setup with mocks
result = Experiment.build_for_testing(
  execution_responses: ["<code>\nfinal_answer(answer: \"done\")\n</code>"],
  planning_responses: []
)

# Run and verify
run_result = result[:agent].run("query")
expect(run_result.output).to eq("done")

# Inspect calls
expect(result[:models][:execution].call_count).to eq(1)
```

**Run experiment tests:**
```bash
bundle exec rspec spec/experiments/multi_model_agents/
```

## Architecture Decisions

See **PLAN.md** for:
- Event-Driven Agent Architecture (EDAA) design
- DSL consistency patterns
- Implementation phases
- Multi-model infrastructure gaps (Phase 7)
