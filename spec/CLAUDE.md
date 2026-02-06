# Testing Conventions

## MockModel (Thread-Safe, FIFO Queue)

```ruby
# Basic: queue responses in order
model = Smolagents::Testing::MockModel.new
model.queue_code_action('calculate(expression: "2+2")')
model.queue_final_answer("4")

# Fluent aliases
model.returns_code('search(query: "Ruby")').answers("42")

# Resilience testing
model.fail_then_succeed(2, then_respond: "ok", with: RuntimeError)

# Assert
expect(model).to be_exhausted
expect(model).to have_received_calls(2)
expect(model).to have_seen_system_prompt
```

## Factories (Globally Available)

```ruby
build_mock_model(responses: [...])    # MockModel with responses
build_test_tool(name: "calc")         # Anonymous tool subclass
build_test_agent(model:, tools:)      # Agent with defaults
build_action_step(step_number: 1)     # ActionStep Data.define
```

## Shared Examples

| Example | Use For |
|---------|---------|
| `"a frozen type"` | Any Data.define type |
| `"a data type"` | Type with members, equality |
| `"a type with to_h"` | Hash conversion |
| `"a type with predicates"` | Boolean predicate methods |
| `"an immutable type"` | `with()` returns new instance |
| `"an immutable builder"` | Builder method immutability |
| `"a builder configuration method"` | Builder setter (method:, config_key:, value:) |
| `"a valid tool"` | Tool class validation |
| `"an executor"` | Executor implementations |
| `"a model"` | Model implementations |

## Timing Enforcement

- Default: **120ms** per test, **200ms** for `:slow` tag (5x in CI)
- Suite limit: **20s** total
- Tag threading/concurrency tests with `:slow`
- Tag agent execution tests with `:slow`
- **Timing failures are real** — profile and fix, don't bump limits

## Test Tags

| Tag | Effect |
|-----|--------|
| `:slow` | 200ms limit (1s in CI) |
| `:integration` | Excluded by default, needs external services |
| `:freeze_time` | Auto-restores Timecop after test |
| `max_time: 0.05` | Custom timing limit per test |

## Network

- WebMock blocks ALL network in tests
- Stub with `stub_request` or use `:integration` tag
- `localhost:1234` (LM Studio) pre-stubbed in spec_helper
