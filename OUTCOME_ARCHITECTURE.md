# ExecutionOutcome Architecture

## Status: Phase 1-2 Complete ✅

The ExecutionOutcome architecture uses a **composition pattern** where outcomes CONTAIN results while adding state machine semantics.

```
ExecutorExecutionOutcome CONTAINS ExecutionResult (from executors)
StepExecutionOutcome CONTAINS ActionStep (agent steps)
AgentExecutionOutcome CONTAINS RunResult (complete runs)
ToolExecutionOutcome (tool-specific metadata)
```

## Completed Work

### ✅ Foundation (37 tests passing)
- [x] ExecutionOutcome base class with predicates (`success?`, `error?`, `final_answer?`, etc.)
- [x] ExecutorExecutionOutcome with ExecutionResult composition
- [x] StepExecutionOutcome with ActionStep composition
- [x] AgentExecutionOutcome with RunResult composition
- [x] ToolExecutionOutcome with tool-specific fields
- [x] Pattern matching support for all types
- [x] Event payload generation (`to_event_payload`)

### ✅ Executor Integration (12 tests passing)
- [x] `execute_with_outcome()` method on base Executor class
- [x] Composition pattern: outcome.result contains full ExecutionResult
- [x] Delegation methods: `outcome.output`, `outcome.logs`
- [x] Support for positional and keyword arguments in tools
- [x] FinalAnswerTool accepts both `final_answer('answer')` and `final_answer(answer: 'answer')`

### ✅ Instrumentation (34 tests passing)
- [x] `Instrumentation.observe()` for outcome-based operations
- [x] `Instrumentation.instrument()` for legacy exception-based operations
- [x] Model behavior tracking (argument styles, model IDs, agent types)
- [x] LoggingSubscriber integration
- [x] All tests passing with new outcome/timestamp expectations

### ✅ Model Behavior Tracking
Tool#call now tracks how different models interact:
```ruby
{
  tool_name: "final_answer",
  argument_style: :positional,  # or :keyword, :hash, :mixed
  model_id: context[:model_id],
  agent_type: context[:agent_type]
}
```

## Remaining Work

### 🔄 Agent API Integration
Add outcome-based methods to agents:

**Files to update:**
- `lib/smolagents/agents/code.rb`
- `lib/smolagents/agents/toolcalling.rb`

```ruby
# Add run_with_outcome() alongside existing run()
def run_with_outcome(task, **options)
  Instrumentation.observe("smolagents.agent.run",
    agent_class: self.class.name,
    model_id: @model.model_id
  ) do
    run_result = run(task, **options)
    AgentExecutionOutcome.from_run_result(run_result, task: task)
  end
end
```

### 🔄 Full-Stack Integration Test
Create `spec/integration/outcome_flow_spec.rb`:
- [ ] Test executor → step → agent outcome flow
- [ ] Pattern matching for control flow
- [ ] Instrumentation emitting at all levels
- [ ] Model behavior tracking end-to-end

### 🔄 Documentation Updates
Update architecture documentation to reflect final state:
- [ ] Update CLAUDE.md with outcome patterns
- [ ] Add examples of `execute_with_outcome()` usage
- [ ] Document model behavior tracking approach

## Key Patterns

### Composition Over Replacement
Outcomes CONTAIN results, preserving all original data:

```ruby
outcome = executor.execute_with_outcome("2 + 2", language: :ruby)

# Outcome adds state machine
outcome.success?  # => true
outcome.state     # => :success

# Result is fully accessible
outcome.result.output  # => 4
outcome.result.logs    # => ""

# Delegation for convenience
outcome.output  # => 4 (delegates to result.output)
```

### Backward Compatibility
Both APIs coexist:

```ruby
# Existing API (still works)
result = executor.execute("code", language: :ruby)  # Returns ExecutionResult

# New API (adds state machine)
outcome = executor.execute_with_outcome("code", language: :ruby)  # Returns ExecutorExecutionOutcome
```

### Pattern Matching for Control Flow

```ruby
case outcome
in ExecutorExecutionOutcome[state: :success, value:]
  puts "Output: #{value}"
in ExecutorExecutionOutcome[state: :final_answer, value:]
  return finalize(:success, value, context)
in ExecutorExecutionOutcome[state: :error, error:]
  handle_error(error)
end
```

### Event-Driven Observability

```ruby
# Instrumentation observes, emits events, returns outcome unchanged
outcome = Instrumentation.observe("smolagents.custom.event", executor_class: "Ruby") do
  executor.execute_with_outcome(code, language: :ruby)
end

# Subscriber receives outcome data
Instrumentation.subscriber = ->(event, payload) {
  puts "#{event}: #{payload[:outcome]} in #{payload[:duration]}s"
}
```

## Testing Stats

- **83 total tests** passing
  - 37 ExecutionOutcome type tests
  - 12 Executor outcome integration tests
  - 34 Instrumentation tests

## Files Modified

**New:**
- `lib/smolagents/types/execution_outcome.rb` - Outcome type definitions
- `spec/smolagents/types/execution_outcome_spec.rb` - Outcome unit tests
- `spec/smolagents/executors/executor_outcome_spec.rb` - Integration tests

**Modified:**
- `lib/smolagents/executors/executor.rb` - Added `execute_with_outcome()`
- `lib/smolagents/tools/tool.rb` - Argument style tracking
- `lib/smolagents/tools/final_answer.rb` - Flexible arguments
- `lib/smolagents/types.rb` - Export outcome types

## Next Steps

1. Add `run_with_outcome()` to agents
2. Write full-stack integration test
3. Update architecture documentation
4. Begin collecting model behavior analytics
