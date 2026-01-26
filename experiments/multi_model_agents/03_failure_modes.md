# Failure Modes Analysis

## Category 1: Infrastructure Failures

### F1.1: Model Server Unreachable

**Scenario:** Mac Studio goes offline while agent is mid-task.

**Current Mitigation:**
- Health checks detect unavailability
- Circuit breaker opens after threshold failures
- Fallback chain activates

**Events Fired:**
```ruby
HealthCheckCompleted(model_id: "mac-studio/gpt-oss-20b", status: :unhealthy)
CircuitStateChanged(circuit_name: "mac-studio", from_state: :closed, to_state: :open)
FailoverOccurred(from_model_id: "mac-studio/gpt-oss-20b", to_model_id: "macbook/gpt-oss-20b")
```

**Gap:** No automatic recovery when server comes back. Circuit stays open for `reset_after` seconds regardless.

**Recommendation:** Add `RecoveryAttempted` event and background health monitor.

### F1.2: Network Partition

**Scenario:** Tailscale tunnel drops, all three servers become unreachable simultaneously.

**Current Mitigation:**
- Retry with backoff
- Circuit breakers on each server
- Eventually all fallbacks fail

**What Happens:**
```ruby
# Cascading failures
RetryRequested(model_id: "llama-ultra", attempt: 1)
RetryRequested(model_id: "llama-ultra", attempt: 2)
RetryRequested(model_id: "llama-ultra", attempt: 3)
FailoverOccurred(from: "llama-ultra", to: "macbook")
# macbook also fails...
# Eventually: Error(error_class: "AllModelsUnavailable", recoverable: false)
```

**Gap:** No "global" circuit breaker for network partitions. Each model fails independently.

**Recommendation:** Add `NetworkPartitionDetected` event when multiple servers fail together.

### F1.3: Model Unloaded on Server

**Scenario:** LM Studio unloaded gpt-oss-120b to free VRAM.

**Current Mitigation:**
- Request fails with 404 or similar
- Retry won't help (model genuinely unavailable)

**Gap:** Health check only pings endpoint, doesn't verify specific model availability.

**Recommendation:** Health check should list available models and verify requested model is loaded.

---

## Category 2: Model Failures

### F2.1: Context Window Exceeded

**Scenario:** Long research task accumulates too many messages, exceeding model's context.

**Current Mitigation:**
- Memory management with budget
- Summarization can compact history

**Events:**
```ruby
# Should fire but currently doesn't
ContextWindowExceeded(model_id: "gpt-oss-20b", token_count: 35000, limit: 32768)
```

**Gap:** No explicit event for context overflow. Error bubbles up as API error.

**Recommendation:** Pre-flight check token count, emit `ContextWindowApproaching` warning.

### F2.2: Model Returns Invalid JSON

**Scenario:** Model hallucinates malformed tool call.

**Current Mitigation:**
- JSON parsing error caught
- NOT a circuit-breaking error (model is working, just confused)
- Observation includes error, model can self-correct

**Events:**
```ruby
Error(error_class: "JSON::ParserError", recoverable: true)
# Step continues with error observation
```

**This is well-handled!**

### F2.3: Model Refuses Task

**Scenario:** Model refuses to help with task (content policy).

**Current Mitigation:**
- Response contains refusal text
- Agent may interpret as "stuck"

**Gap:** No detection of refusal vs genuine inability.

**Recommendation:** Add `ModelRefusalDetected` event with heuristic detection.

### F2.4: Infinite Loop / Repetition

**Scenario:** Model keeps calling same tool with same arguments.

**Current Mitigation:**
- `RepetitionDetected` event fires
- Guidance provided to model

**Events:**
```ruby
RepetitionDetected(pattern: :tool_call, count: 3, guidance: "Try a different approach")
```

**This is well-handled!**

---

## Category 3: Multi-Agent Failures

### F3.1: Sub-Agent Never Returns

**Scenario:** Sub-agent gets stuck in infinite loop or hangs.

**Current Mitigation:**
- `max_steps` limit on sub-agent
- Eventually hits limit and returns

**Gap:** No timeout on wall-clock time. `max_steps` of 100 could run indefinitely if steps are slow.

**Recommendation:** Add `step_timeout` per agent, emit `AgentTimeout` event.

### F3.2: Coordinator Lost Track of Sub-Agents

**Scenario:** Coordinator delegates to 3 sub-agents but only receives 2 responses.

**Current Mitigation:**
- AgentPool tracks all launched agents
- Waits for all to complete

**Gap:** No timeout on collective completion. One stuck agent blocks all.

**Recommendation:** Add `parallel_timeout` on AgentPool, emit partial results.

### F3.3: Sub-Agent Spawn Depth Exceeded

**Scenario:** Agent A spawns B, B spawns C, C tries to spawn D but hits depth limit.

**Current Mitigation:**
- `SpawnRestricted` event fires
- Spawn denied with explanation

**Events:**
```ruby
SpawnRestricted(agent_name: "D", depth: 3, violations: ["max_depth exceeded"])
```

**This is well-handled!**

### F3.4: Circular Delegation

**Scenario:** Agent A delegates to B, B delegates back to A.

**Current Mitigation:**
- Each agent has unique ID
- Spawn path tracked

**Gap:** Not explicitly prevented. Could theoretically loop.

**Recommendation:** Add `spawn_path` check to prevent circular delegation.

---

## Category 4: Resource Exhaustion

### F4.1: Token Budget Exhausted

**Scenario:** Agent runs out of token budget mid-task.

**Current Mitigation:**
- Memory budget tracking
- Summarization when approaching limit

**Gap:** No hard stop when budget exceeded. Can still run if summarization fails.

**Recommendation:** Add `BudgetExhausted` event, force graceful termination.

### F4.2: Rate Limited by External API

**Scenario:** Tool calls external API that rate-limits.

**Current Mitigation:**
- `RateLimitViolated` event
- `retry_after` provides backoff hint

**Events:**
```ruby
RateLimitViolated(tool_name: "web_search", retry_after: 60)
```

**This is well-handled!** (Tool needs to implement backoff)

### F4.3: Request Queue Overflow

**Scenario:** Too many concurrent requests, queue fills up.

**Current Mitigation:**
- `with_queue(max_depth: N)` limits queue
- Excess requests fail fast

**Gap:** No event when queue is full. Request just fails.

**Recommendation:** Add `QueueFull` event with queue depth.

---

## Category 5: Data Integrity Failures

### F5.1: Inconsistent State After Failover

**Scenario:** Request sent to model A, fails, retried on model B. Response semantics differ.

**Current Mitigation:**
- Fallback uses same messages
- Models should give similar responses

**Gap:** No guarantee of semantic consistency. Different models may interpret differently.

**Recommendation:** Document as expected behavior. Consider "sticky" model routing for stateful conversations.

### F5.2: Event Ordering in Async Mode

**Scenario:** Events processed out of order due to async emission.

**Current Mitigation:**
- Events have timestamps
- Critical events can use `emit_sync`

**Gap:** No guaranteed ordering for async events.

**Recommendation:** Add sequence numbers to events for reconstruction.

---

## Failure Recovery Strategies

### Strategy 1: Graceful Degradation

```ruby
agent = Smolagents.agent
  .model { primary }
  .model(:fallback_1) { secondary }
  .model(:fallback_2) { tertiary }
  .on(:failover) { |e| notify_degraded_mode(e.to_model_id) }
  .build
```

### Strategy 2: Circuit Breaker with Manual Reset

```ruby
agent = Smolagents.agent
  .model {
    Smolagents.model(:openai)
      .base_url(LLAMA_ULTRA)
      .with_circuit_breaker(threshold: 3, reset_after: 300)  # 5 min cooldown
      .build
  }
  .on(:circuit_state_changed) do |e|
    if e.open?
      alert("Circuit open for #{e.circuit_name}")
    end
  end
  .build
```

### Strategy 3: Timeout Chains

```ruby
agent = Smolagents.agent
  .model { fast_model }
  .max_steps(20)
  .step_timeout(30)  # 30s per step
  .on(:step_complete) { |e| extend_deadline if e.outcome == :success }
  .build
```

### Strategy 4: Checkpoint and Resume

**Gap:** No built-in checkpointing. Would need custom implementation.

```ruby
# Hypothetical API
agent = Smolagents.agent
  .model { model }
  .checkpointing(interval: 5, storage: :redis)
  .on(:checkpoint_saved) { |e| log("Saved at step #{e.step_number}") }
  .build

# Resume from checkpoint
agent.resume_from(checkpoint_id)
```

---

## Testing Failure Scenarios

Each failure mode should have a deterministic test:

```ruby
RSpec.describe "Failure: Model Server Unreachable" do
  it "falls back to secondary model" do
    primary = mock_model_that_fails(with: NetworkError)
    secondary = mock_model { |m| m.queue_final_answer("fallback worked") }

    agent = Smolagents.agent
      .model { primary }
      .with_fallback { secondary }
      .build

    events = []
    agent.on(:failover) { |e| events << e }

    result = agent.run("test")

    expect(result).to eq("fallback worked")
    expect(events.first.from_model_id).to include("primary")
  end
end
```

**Gap:** `mock_model_that_fails` helper doesn't exist yet.

**Recommendation:** Add failure injection to MockModel:
```ruby
model = MockModel.new
model.fail_next(3, with: NetworkError)  # Next 3 calls fail
model.queue_final_answer("success")      # Then succeed
```
