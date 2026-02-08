# Testing Conventions

## Philosophy

The test suite is our primary feedback loop — for humans AND coding agents. It must be:

1. **Instant-fast** (~10s total). Short iteration cycles let agents try, see results, and adjust. `rake spec` runs dozens of times per session without losing momentum.

2. **Silent on success.** No debug output, no progress bars, no warnings in passing tests. Clean output = clean agent context. If something appears in test logs that isn't a failure, that's a bug in our tests or code — fix it.

3. **Diagnostic on failure.** Stack traces, timing, assertion context — everything needed to diagnose. **NEVER pipe or filter test output.** Use `rake spec`, not `bundle exec rspec | grep`.

4. **Deterministic.** No randomness, no timing dependencies, no network calls. MockModel provides exact responses in exact order. WebMock blocks all network.

5. **Adversarial by default.** For every feature, test: (a) happy path, (b) most common failure mode, (c) recovery from that failure. The trio proves the feature works, handles errors, and recovers.

---

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

### Adversarial Responses (Phase J)

```ruby
# Model returns non-Ruby garbage
model.queue_malformed("Here's what I think: the answer is 42")

# Model calls tools that don't exist
model.queue_hallucinated_tool("nonexistent_tool(arg: 'value')")

# Model returns empty/nil final answer
model.queue_empty_final_answer

# Model returns text without code blocks
model.queue_text_only("I think the answer is 42")
```

### Conditional Responses (Phase J)

```ruby
# Respond based on what the model sees in observations
model.when_input_matches(/error/) { "final_answer(answer: 'recovered')" }
model.when_input_matches(/search/) { 'search(query: "Ruby")' }
model.default_response("final_answer(answer: 'fallback')")
```

Conditionals are checked BEFORE the FIFO queue. If no match, falls through to queue. Existing `queue_*` tests work unchanged.

---

## Test Patterns

### Happy Path + Adversarial + Recovery

Every feature should have this trio:

```ruby
describe "tool execution" do
  it "executes tool and returns result" do
    # Happy path: tool works
    model.queue_code_action('search(query: "Ruby")')
    model.queue_final_answer("found it")
    expect(agent.run("find Ruby")).to be_success
  end

  it "handles tool execution failure" do
    # Adversarial: tool raises error
    tool = build_test_tool(name: "flaky", raises: RuntimeError.new("timeout"))
    model.queue_code_action("flaky()")
    model.queue_final_answer("couldn't use flaky tool")

    result = build_test_agent(model:, tools: [tool]).run("task")
    expect(result).to be_success
    # Agent saw error in observations and adjusted
  end

  it "recovers and tries alternative tool" do
    # Recovery: agent adapts after failure
    model.when_input_matches(/RuntimeError/) { 'backup_tool()' }
    model.queue_code_action("flaky()")
    model.queue_final_answer("used backup")
    # ... proves recovery path works
  end
end
```

### Integration Test Organization

```
spec/integration/
  deterministic_agent_spec.rb      # Happy-path multi-step workflows
  deterministic_examples_spec.rb   # DSL usage examples
  adversarial_agent_spec.rb        # Format drift, hallucinations, empty answers
  cascading_failure_spec.rb        # Tool fail → retry → circuit break → recovery
  spawn_execution_spec.rb          # Sub-agent spawn, execute, failure handling
  planning_integration_spec.rb     # Planning concern integration
  lazy_evaluation_spec.rb          # Lazy tool future resolution
```

---

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
- Adversarial tests must be ≤120ms — they use MockModel, not real models

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

## Context Hygiene

Tests should produce **zero output** on success. Violations to watch for:

- `puts`/`print` statements in production code (use `@logger` instead)
- VerboseSubscriber output during tests (mock or disable the logger)
- SimpleCov "previous error detected" warnings (harmless but noisy — investigate if new)
- Deprecation warnings from gems (pin versions or report upstream)

If a test produces output on success, either the test or the code needs fixing. Clean output means agents can run `rake spec` and immediately see "0 failures" without wading through noise.
