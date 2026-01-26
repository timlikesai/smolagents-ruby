# Gap Analysis: System Improvements Needed

## Summary

Through designing sophisticated multi-model agent architectures, I've identified several gaps in the current system. These are prioritized by impact and effort.

---

## Priority 1: Low Effort, High Impact

### G1.1: Missing `base_url` Method on ModelBuilder

**Problem:** Can't easily configure remote model servers.

**Current workaround:**
```ruby
# Have to manually configure
config = { api_base: "http://mac-studio.reverse-bull.ts.net:1234/v1" }
# Then pass to model somehow...
```

**Proposed solution:**
```ruby
Smolagents.model(:openai)
  .base_url("http://mac-studio.reverse-bull.ts.net:1234/v1")
  .id("gpt-oss-20b")
  .build
```

**Implementation:** Add to `ModelBuilderSetters`, 5-10 lines.

---

### G1.2: MockModel Failure Injection

**Problem:** Can't test failure scenarios deterministically.

**Current state:** MockModel only returns queued responses, can't simulate failures.

**Proposed solution:**
```ruby
model = MockModel.new
model.fail_next(3, with: NetworkError)  # Next 3 calls raise NetworkError
model.queue_final_answer("success")      # Then succeed

# Or inline:
model.queue_failure(NetworkError, "Connection refused")
model.queue_final_answer("success")
```

**Implementation:** Add `fail_next` and `queue_failure` to MockModel, ~20 lines.

---

### G1.3: Event Sequence Numbers

**Problem:** Async events can arrive out of order, making reconstruction hard.

**Proposed solution:**
```ruby
# Events already have timestamp, add sequence number
Event.new(sequence: 42, timestamp: Time.now, ...)

# Or use monotonic counter per emitter
class Emitter
  def emit(event)
    event = event.with(sequence: @sequence_counter.increment)
    # ...
  end
end
```

**Implementation:** Add to event base type, modify emitter, ~15 lines.

---

## Priority 2: Medium Effort, High Impact

### G2.1: Parallel Execution Control in TeamBuilder

**Problem:** `.coordinate()` is just instructions, not actual control flow.

**Current state:**
```ruby
team.coordinate("Run all researchers in parallel")  # Just text!
```

**Proposed solution:**
```ruby
Smolagents.team
  .model { coordinator }
  .agent(a, as: "a")
  .agent(b, as: "b")
  .parallel([:a, :b])           # Run a and b in parallel
  .then(:synthesizer)           # Then run synthesizer
  # Or with explicit control:
  .execution_plan do |plan|
    plan.parallel(:a, :b, :c)
    plan.sequential(:synthesizer)
  end
  .build
```

**Implementation:** New concern for TeamBuilder, integration with AgentPool, ~100 lines.

---

### G2.2: Custom Model Purposes

**Problem:** Only predefined purposes: `:execution`, `:planning`, `:evaluation`, `:summarization`, `:code_review`.

**Need:** Custom purposes for tiered reasoning (`:triage`, `:reasoning`, `:vision`).

**Proposed solution:**
```ruby
Smolagents.agent
  .model(:triage) { fast_model }        # Custom purpose
  .model(:complex_reasoning) { big_model }  # Another custom
  .build
```

**Implementation:** Modify ModelPoolConfig to accept arbitrary symbols, add accessor, ~30 lines.

---

### G2.3: Health Check with Model Verification

**Problem:** Health check only pings endpoint, doesn't verify specific model is loaded.

**Current state:**
```ruby
.with_health_check(cache_for: 5)  # Just checks endpoint responds
```

**Proposed solution:**
```ruby
.with_health_check(
  cache_for: 5,
  verify_model: true  # Also verify model is loaded
)
# Would call /v1/models and check if configured model_id is in list
```

**Implementation:** Modify health check to optionally query model list, ~40 lines.

---

### G2.4: Tool Access to Agent's Model Pool

**Problem:** Tools can't easily use agent's models (e.g., vision tool calling vision model).

**Current state:** Tools are stateless, no access to agent context.

**Proposed solution:**
```ruby
class VisionTool < Smolagents::Tool
  def execute(image_path:)
    # Access agent's model pool
    vision_model = context.models[:vision]
    vision_model.generate(...)
  end
end

# Or via injection at build time:
Smolagents.agent
  .tool(:analyze_image, "...", inject_models: [:vision]) do |image_path:, vision:|
    vision.generate(...)
  end
```

**Implementation:** Tool context injection, ~50 lines.

---

## Priority 3: Higher Effort, Medium Impact

### G3.1: Cost Tracking and Budget Limits

**Problem:** No built-in cost tracking or budget enforcement.

**Proposed solution:**
```ruby
Smolagents.agent
  .model { model }
  .cost_budget(max_usd: 1.00)
  .on(:budget_warning) { |e| log("80% of budget used") }
  .on(:budget_exhausted) { |e| graceful_stop }
  .build

# Cost calculation via configurable pricing:
Smolagents.configure do |c|
  c.model_pricing = {
    "gpt-4" => { input: 0.03, output: 0.06 },  # per 1K tokens
    "gpt-oss-20b" => { input: 0, output: 0 }   # local = free
  }
end
```

**Implementation:** New concern, event types, configuration, ~150 lines.

---

### G3.2: Checkpoint and Resume

**Problem:** Long-running agents can't be paused and resumed.

**Proposed solution:**
```ruby
Smolagents.agent
  .model { model }
  .checkpointing(
    interval: 5,           # Every 5 steps
    storage: :file,        # Or :redis, :postgres
    path: "/tmp/checkpoints"
  )
  .build

# Resume from checkpoint
agent.resume_from(checkpoint_id: "abc123")
```

**Implementation:** Serialization of agent state, storage adapters, ~300 lines.

---

### G3.3: Model Cluster Discovery

**Problem:** No dynamic discovery of available models across servers.

**Proposed solution:**
```ruby
cluster = Smolagents::ModelCluster.discover([
  "http://mac-studio.reverse-bull.ts.net:1234",
  "http://macbook-pro-m4.reverse-bull.ts.net:1234",
  "https://llama-cpp-ultra.reverse-bull.ts.net"
])

# Emits ModelDiscovered events for each found model
cluster.on(:model_discovered) { |e| log("Found #{e.model_id} on #{e.provider}") }

# Smart routing
model = cluster.resolve("gpt-oss-20b", prefer: :fastest)
```

**Implementation:** Discovery service, routing logic, ~400 lines.

---

## Priority 4: Future Considerations

### G4.1: Cross-Agent Communication

Agents can't directly message each other (only via coordinator).

### G4.2: Distributed State/Caching

No built-in distributed cache for multi-machine deployments.

### G4.3: Semantic Consistency Across Models

No guarantee that different models give semantically similar responses.

### G4.4: Network Partition Detection

Individual circuit breakers but no global partition awareness.

---

## Implementation Roadmap

### Phase 1: Quick Wins (G1.x)
- [ ] G1.1: `base_url` method
- [ ] G1.2: MockModel failure injection
- [ ] G1.3: Event sequence numbers

### Phase 2: Core Improvements (G2.x)
- [ ] G2.1: Parallel execution control
- [ ] G2.2: Custom model purposes
- [ ] G2.3: Health check model verification
- [ ] G2.4: Tool model pool access

### Phase 3: Advanced Features (G3.x)
- [ ] G3.1: Cost tracking
- [ ] G3.2: Checkpointing
- [ ] G3.3: Model cluster discovery

### Phase 4: Future (G4.x)
- Defer until core patterns are proven

---

## Testing Requirements

Each gap should have:
1. Unit tests for the feature
2. Integration test with mock models
3. Failure scenario tests
4. Documentation update

Example test structure:
```ruby
RSpec.describe "G1.2: MockModel Failure Injection" do
  it "fails for specified number of calls then succeeds" do
    model = MockModel.new
    model.fail_next(2, with: NetworkError)
    model.queue_final_answer("success")

    expect { model.generate([]) }.to raise_error(NetworkError)
    expect { model.generate([]) }.to raise_error(NetworkError)
    expect(model.generate([]).content).to eq('final_answer(answer: "success")')
  end
end
```
