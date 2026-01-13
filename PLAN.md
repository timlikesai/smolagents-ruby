# smolagents-ruby Project Plan

Single source of truth for all project work. Update this file as work progresses.

---

## Project Management

### How to Use This Document

1. **Before starting work**: Read this document to understand current state
2. **When planning**: Add new work items with clear acceptance criteria
3. **While working**: Update status as you go (not after)
4. **After completing**: Move items to Completed section with date

### Work Item Format

```
### [Category] Item Name
**Status:** Not Started | In Progress | Blocked | Complete
**Priority:** P0 (critical) | P1 (high) | P2 (medium) | P3 (low)

Description of what needs to be done.

**Acceptance Criteria:**
- [ ] Specific testable outcome
- [ ] Another testable outcome

**Notes:** Any context, blockers, or decisions made.
```

### Principles

- **Forward Only**: No backwards compatibility. When something improves, adopt everywhere.
- **Tests Pass**: Nothing ships with failing tests. 2249+ tests must pass.
- **RuboCop Clean**: All Ruby files pass linting before commit.
- **Documentation Lives Here**: No scattered TODO files. This is the plan.

---

## Ractor Usage Analysis (Critical Architecture Decision)

### The Question: What Actually Needs Ractors?

After comprehensive research, we determined that **only code execution needs Ractors**.

### The Isolation Boundary

The key architectural insight: **Ractors isolate MODEL OUTPUT processing, not MODEL CALLS**.

```
TRUSTED ZONE (Main Thread)              │  UNTRUSTED ZONE (Ractor)
────────────────────────────────────────┼────────────────────────────────────────
                                        │
agent.run(task)                         │
├── model.generate(messages) ──────────>│ HTTP request to OpenAI (we control this)
│   └── HTTP response <────────────────<│ JSON response (trusted data format)
│                                       │
├── Parse response (JSON)               │
│   └── Extract code from model output  │
│                                       │
└── IF code execution needed:           │
    └── executor.execute(code) ─────────┼──────> Ractor.new(code) { eval(code) }
        │                               │        └── ISOLATED: model-generated
        │                               │           code cannot access host
        │                               │           memory, globals, etc.
        │                               │
        └── Result <────────────────────┼────────< Message passing returns result
                                        │
```

**Why this matters:**
- Model HTTP calls are TRUSTED - we construct the request, we parse JSON response
- Model-generated CODE is UNTRUSTED - the model could output malicious Ruby
- Ractor isolation ensures malicious code can't escape the sandbox

### Where Ractors ARE Essential

**Code Execution** (`Executors::Ractor`) ✅
- Receives model-generated Ruby code
- Runs it in memory-isolated Ractor
- Protects host from malicious/buggy model outputs
- Tool calls route through message passing back to main Ractor
- TracePoint enforces operation limits
- **This is the ONLY correct use of Ractors in our architecture**

### Where Ractors Are NOT Needed

**Model HTTP Calls** (`OpenAIModel`, `AnthropicModel`)
- HTTP requests are **I/O-bound** operations
- The GVL is released during I/O operations anyway
- For parallel HTTP calls, Threads or Fibers work fine
- Ractors add overhead (data copying, serialization) without benefit
- **The ruby-openai gem works fine with threads**

**Multi-Agent Orchestration** (`RactorOrchestrator`)
- Current design: Reconstruct entire agents inside Ractors
- But HTTP calls happen in the Ractor → requires complex infrastructure
- **Simpler approach:** Use threads for parallelism, Ractor only for code sandbox

### Simplified Architecture

```
Main Thread / Worker Threads (for parallel agents)
├── Agent.run(task)
│   ├── model.generate(messages)    ← HTTP call (I/O, GVL released)
│   │   └── ruby-openai gem works normally
│   ├── Parse tool calls
│   └── executor.execute(code)      ← Ractor sandbox (CodeAgent only)
│       └── [Runs in isolated Ractor with tool message passing]
└── Return result
```

### What This Means for Our Code

| Component | Needs Ractor? | Reason |
|-----------|---------------|--------|
| `Executors::Ractor` | ✅ YES | Sandboxed code execution |
| `Executors::LocalRuby` | ❌ NO | In-process sandbox (simpler) |
| `OpenAIModel` | ❌ NO | I/O-bound HTTP calls |
| `AnthropicModel` | ❌ NO | I/O-bound HTTP calls |
| `RactorOrchestrator` | ⚠️ RETHINK | Thread-based orchestration simpler |
| `RactorSafeClient` | ⚠️ NOT FOR MODELS | Only needed inside code sandbox |
| `RactorModel` | ⚠️ NOT FOR AGENTS | Only if model called from sandbox |

### Implementation Implications

1. **Keep `Executors::Ractor`** - Well-designed, correct use case
2. **No changes to Models** - ruby-openai/anthropic gems work fine in main thread
3. **Simplify `RactorOrchestrator`** - Consider thread-based alternative
4. **Tools in code sandbox** - Still need message passing for tool calls from Ractor

### Parallel Agent Execution Options

**Option A: Thread-based (Recommended)**
```ruby
class ThreadOrchestrator
  def execute_parallel(agents:, tasks:)
    threads = agents.zip(tasks).map do |agent, task|
      Thread.new { agent.run(task) }
    end
    threads.map(&:value)  # Collect results
  end
end
```
- Simple, works with existing code
- GVL releases on I/O (model calls)
- No Ractor complexity

**Option B: Async-based (For heavy I/O)**
```ruby
require 'async'

class AsyncOrchestrator
  def execute_parallel(agents:, tasks:)
    Async do |task|
      agents.zip(tasks).map do |agent, prompt|
        task.async { agent.run(prompt) }
      end.map(&:wait)
    end
  end
end
```
- Non-blocking I/O
- Better for many concurrent agents
- Fiber scheduler handles yielding

**Option C: Keep RactorOrchestrator (For true isolation)**
- Only needed if agents must be memory-isolated from each other
- More complex, keeps current infrastructure
- Justified for untrusted/adversarial multi-agent scenarios

---

## What We DON'T Need to Do

Based on this analysis, we can **skip**:

1. ~~Model Ractor Detection~~ - Models don't run in Ractors
2. ~~SearchTool Proc Removal~~ - Tools called via message passing, not direct Ractor access
3. ~~RactorSafeClient for models~~ - Regular HTTP works fine in main thread
4. ~~Complex Tool Ractor-safety~~ - Tool calls route through main Ractor

## What We SHOULD Do

1. **Keep `Executors::Ractor`** as-is - Already correct
2. **Add `ThreadOrchestrator`** - Simple parallel agent execution
3. **Consider `AsyncOrchestrator`** - For I/O-heavy workloads
4. **Document the architecture** - Clarify when to use which executor/orchestrator

---

## Component Status Overview (Revised)

| Component | Status | Notes |
|-----------|--------|-------|
| **Executors::Ractor** | ✅ Done | Correct Ractor use for code sandboxing |
| **Executors::LocalRuby** | ✅ Done | In-process sandbox alternative |
| **Models** | ✅ No changes needed | Work fine with threads |
| **Event System** | ✅ Core architecture | Decoupled, testable, keep everywhere |
| **RactorOrchestrator** | ⚠️ Optional | Keep for true isolation, but threads usually suffice |
| **RactorSafeClient** | ⚠️ For sandbox only | Not needed for model HTTP calls |
| **Tool base class** | ✅ Done | Message passing handles Ractor calls |

---

## Current Priority Focus

Based on our clarified Ractor architecture and P0 simplification work, here are the actual priorities:

### Completed (P0 Simplification - 2026-01-13)
- [x] **Deleted Events::Scheduler** - 153 LOC of 100% unused code removed
- [x] **Flattened outcome types** - Deleted 3 unused types, created shared OutcomePredicates module (~250 LOC savings)
- [x] **SearchTool analysis complete** - DSL provides real value, deferred to P1 for design work

### P0 (Critical)
- [ ] **Event Mappings Tests** - 0% coverage on symbol→class resolution
- [ ] **Emitter-Consumer Integration Tests** - Full event flow not tested end-to-end

### P1 (High)
- [ ] **SearchTool simplification** - Convert Configuration class to Data.define, reduce complexity while preserving parser/auth flexibility
- [ ] **Code Coverage to 95%** - Currently 87.36%, several directories below 80%
- [ ] **Documentation Coverage to 95%** - Currently 70.74%

### P2 (Medium)
- [ ] **Delete unused concerns** - Auditable (54 LOC), Streamable (35 LOC), StepExecution (19 LOC), GemLoader (14 LOC)
- [ ] **Source Tracking Concern** - Useful for research agents
- [ ] **Builder Error Condition Tests** - Need negative test cases

### P3 (Low/Optional)
- [ ] **RactorOrchestrator Full Tests** - Optional feature, threads usually work
- [ ] **HuggingFace/Bedrock Models** - Can use LiteLLM instead
- [ ] **Local Model Auto-Detection** - Nice to have

### Not Needed (Removed)
- ~~Model Ractor Detection~~ - Models run in main thread
- ~~SearchTool Proc Removal~~ - Tools called via message passing
- ~~RactorSafeClient for models~~ - Only needed in code sandbox
- ~~Complex Tool Ractor-safety~~ - Message passing handles it
- ~~Events::Scheduler tests~~ - Module deleted (was 0% used)

---

## Completed Work

### [Architecture] Ractor Isolation Interface Design
**Status:** Complete (2026-01-13)
**Priority:** P0 (critical)

Designed the complete interface for Ractor-based code isolation, synthesizing research from Ruby 4.0 patterns, game loop architectures, and actor model principles.

**What was done:**
- Launched 3 research agents analyzing Ruby 4.0 Ractor/Port patterns, codebase DSL idioms, and event loop architectures
- Synthesized findings into cohesive interface design documented in PLAN.md
- Defined boundary types: `ToolCallRequest`, `ToolCallResponse`, `ExecutionResult` (Data.define)
- Documented message protocol between sandbox and main Ractor
- Designed bounded message processing (game loop pattern)
- Integrated with event system for observability
- Planned Ruby 4.0 `Ractor::Port` forward compatibility

**Key design principles:**
- Interface invisible to users - Agent/Tool authors never see Ractor complexity
- Single master loop - ReAct loop owns execution, executor exposes `execute()` not `run_forever()`
- Message-based tool calls - Events cross the boundary, not method calls
- All boundary data uses Data.define - Immutable, pattern-matchable, fits codebase

**Research artifacts:** `tmp/research_ruby40_events.md`, `tmp/research_event_architectures.md`

### [Architecture] Ractor Architecture Clarification
**Status:** Complete (2026-01-13)
**Priority:** P0 (critical)

Clarified where Ractors belong in the architecture based on I/O vs CPU analysis.

**What was done:**
- Identified that Ractors are for code execution isolation, NOT model HTTP calls
- Documented the isolation boundary: model OUTPUT (code) is untrusted, model CALLS are trusted
- Determined models don't need Ractor changes - they run in main thread
- Lowered priority of RactorOrchestrator - threads work for parallel agents
- Confirmed `Executors::Ractor` is the correct and only Ractor use case
- Event system remains orthogonal to Ractor architecture
- Removed unnecessary work items (Model Ractor Detection, SearchTool Proc Removal, etc.)

### [Architecture] Goal DSL Consolidation
**Status:** Complete (2026-01-13)
**Priority:** P1

Unified `Goal` and `PlanOutcome` into single expressive Data.define type.

**What was done:**
- Created unified `Goal` type with fluent criteria DSL
- Composition operators: `&` (all) and `|` (any)
- Agent binding: `.with_agent(agent).run!`
- Template support: `Goal.template("Research :topic").for(topic: "AI")`
- Deleted 6 redundant files (outcome_base, outcome_composite, outcome_collection, outcome_states, goal_states, goal_arrays)
- Kept `Outcome` module orthogonal for state constants

### [Architecture] Builder Refactoring
**Status:** Complete (2026-01-13)
**Priority:** P1

Applied Ruby 4.0 forward-only patterns to all builders.

**What was done:**
- Moved constants outside Data.define blocks (RuboCop compliance)
- Removed all `alias_method` calls (forward-only)
- Updated specs to use primary method names
- All 2249 tests pass

### [Feature] Agent Persistence
**Status:** Complete (2026-01-12)
**Priority:** P1

Save/load agents to disk with security (no API key serialization).

**What was done:**
- `AgentManifest`, `ModelManifest`, `ToolManifest` Data.define types
- Directory format: agent.json, tools/*.json, managed_agents/*/
- `Serializable` concern for agents
- `agent.save(path)` and `Agent.from_folder(path, model:)`
- Error hierarchy for load failures

### [Feature] DSL.Builder Framework
**Status:** Complete (2026-01-12)
**Priority:** P1

Custom builder creation with validation, help, and freeze.

**What was done:**
- `DSL.Builder(:field1, :field2) { }` factory method
- `builder_method` for declarative configuration
- `.help` introspection for REPL-friendly development
- `.freeze!` for production configuration safety
- Pattern matching support via Data.define

### [Feature] Model Reliability DSL
**Status:** Complete (2026-01-12)
**Priority:** P2

Resilience patterns for model interactions.

**What was done:**
- `.with_retry(max_attempts:, backoff:)`
- `.with_fallback(models)`
- `.with_health_check(interval:)`
- `.with_queue(max_size:)`
- Local server factories: `OpenAIModel.lm_studio()`, `.ollama()`, etc.

### [Feature] Telemetry & Instrumentation
**Status:** Complete (2026-01-12)
**Priority:** P2

Observability for agent operations.

**What was done:**
- `Telemetry::Instrumentation` with named events
- `LoggingSubscriber` for simple output
- `OTel` integration for OpenTelemetry
- Event types: agent.run, agent.step, model.generate, tool.call

### [Testing] Coverage Tooling
**Status:** Complete (2026-01-13)
**Priority:** P1

Code and documentation coverage measurement.

**What was done:**
- SimpleCov integration in spec_helper.rb
- 87.24% code coverage (80% threshold)
- YARD stats: 70.74% documentation coverage
- Rake tasks: `rake coverage:run`, `rake doc:stats`, `rake doc:coverage`
- Coverage reports at `coverage/index.html`
- Testing module excluded (requires live models)

---

## Backlog

### [Coverage] Code Coverage to 95%
**Status:** Not Started
**Priority:** P1

Improve code coverage from 87.24% to 95%+.

**Current by directory:**

| Directory | Coverage | Gap | Action |
|-----------|----------|-----|--------|
| orchestrators | 42.7% | Ractor env | Enable Ractor tests or mock |
| executors | 71.9% | 23% | Add Docker executor stubs |
| telemetry | 75.3% | 20% | Test OTel integration paths |
| events | 76.8% | 18% | Test scheduler edge cases |
| cli | 80.3% | 15% | Test command execution paths |
| models | 83.8% | 11% | Test streaming, error paths |
| types | 86.2% | 9% | Test edge cases |
| concerns | 86.6% | 8% | Test browser, async paths |

**Acceptance Criteria:**
- [ ] Overall coverage ≥95%
- [ ] No directory below 80%
- [ ] orchestrators tests enabled (mock Ractor if needed)
- [ ] executors/docker.rb stubbed tests
- [ ] telemetry paths fully exercised

**Approach:**
1. Start with lowest coverage directories
2. Use mocks/stubs for external dependencies (Ractor, Docker)
3. Add edge case tests for error handling paths
4. Run `bundle exec rspec` to verify

### [Coverage] Documentation Coverage to 95%
**Status:** Not Started
**Priority:** P1

Improve documentation coverage from 70.74% to 95%+.

**Current gaps:**

| Type | Documented | Undocumented | Target |
|------|------------|--------------|--------|
| Modules | 63 | 29 | Document all 29 |
| Classes | 147 | 19 | Document all 19 |
| Constants | 100 | 112 | Document ~100 (skip internal) |
| Methods | 724 | 371 | Document ~350 public methods |

**Priority order (by impact):**
1. **Public API modules** - Smolagents::Builders, Smolagents::Concerns, Smolagents::CLI
2. **Builder callbacks** - on_error, on_step, on_task, on_tool, etc.
3. **Concern modules** - AsyncTools, Auditable, Browser, etc.
4. **Type classes** - Data.define types need @return docs
5. **Constants** - Skip internal, document public config

**Acceptance Criteria:**
- [ ] Overall documentation ≥95%
- [ ] All public modules documented
- [ ] All public classes documented
- [ ] All builder callback methods documented
- [ ] All concern modules have module-level docs
- [ ] Constants: public ones documented, internal marked @api private

**Approach:**
1. Run `bundle exec yard stats --list-undoc` for current list
2. Document modules/classes first (highest impact)
3. Document public methods with @param, @return, @example
4. Mark internal constants with @api private
5. Run `bundle exec rake doc:coverage` to verify

### [Feature] Source Tracking Concern
**Status:** Not Started
**Priority:** P2

Reusable concern for agents that visit URLs.

**Acceptance Criteria:**
- [ ] `Concerns::SourceTracking` module
- [ ] `agent.sources` returns all URLs visited
- [ ] Auto-deduplication of sources
- [ ] Integration with research-style agents

**Notes:** Suggested in `examples/research_assistant.rb:169`.

### [Testing] Ractor Orchestrator Tests
**Status:** Not Started
**Priority:** P3 (lowered)

Enable Ractor-based parallel execution tests.

**Acceptance Criteria:**
- [ ] `#execute_parallel` test passing
- [ ] `#execute_single` test passing
- [ ] Document Ractor environment requirements

**Notes:**
- Currently skipped in `spec/smolagents/orchestrators/ractor_orchestrator_spec.rb`
- **Lowered priority**: RactorOrchestrator is optional. Thread-based parallelism works for most use cases.
- Keep for scenarios requiring true memory isolation between agents.

### [Enhancement] HuggingFace Inference API
**Status:** Not Started
**Priority:** P3

Add HTTP client for HuggingFace Inference API.

**Acceptance Criteria:**
- [ ] `HuggingFaceModel` class with generate/generate_stream
- [ ] Authentication via HF_TOKEN
- [ ] Rate limiting respect
- [ ] Tests with WebMock stubs

**Notes:** Low priority - most users use local servers or direct API access.

### [Enhancement] Amazon Bedrock Support
**Status:** Not Started
**Priority:** P3

Add HTTP client for AWS Bedrock.

**Acceptance Criteria:**
- [ ] `BedrockModel` class with generate
- [ ] AWS credential handling
- [ ] Support for Claude on Bedrock
- [ ] Tests with WebMock stubs

**Notes:** Could be done via LiteLLM instead.

### [Enhancement] Local Model Auto-Detection
**Status:** Not Started
**Priority:** P3

Automatically detect running local LLM servers.

**Acceptance Criteria:**
- [ ] `OpenAIModel.auto_detect` tries common ports (1234, 11434, 8080, 8000)
- [ ] Returns first responding server
- [ ] Graceful fallback if none available

**Notes:** Suggested in `examples/local_models.rb:268`.

### [Enhancement] Model Health Check Method
**Status:** Not Started
**Priority:** P3

Simple connectivity testing for models.

**Acceptance Criteria:**
- [ ] `model.healthy?` returns true if server responding
- [ ] Non-blocking check with timeout
- [ ] Works with all model types

**Notes:** Suggested in `examples/local_models.rb:275`.

### [DSL] Data Pipeline DSL
**Status:** Not Started
**Priority:** P3

Intuitive data processing chains.

**Acceptance Criteria:**
- [ ] `Smolagents.pipeline.load(:source).transform { }.aggregate(:sum, :field)`
- [ ] Lazy evaluation
- [ ] Integration with ToolResult

**Notes:** Suggested in `examples/data_processor.rb:254`. May overlap with existing Pipeline.

### [DSL] Agent Workflow DSL
**Status:** Not Started
**Priority:** P3

Explicit workflow definitions for multi-agent teams.

**Acceptance Criteria:**
- [ ] `team.workflow { step(:agent) { |input| ... } }`
- [ ] Sequential and parallel step support
- [ ] Result passing between steps

**Notes:** Suggested in `examples/multi_agent_team.rb:188`.

---

## Feature Parity Status

See `FEATURE_PARITY.md` for detailed comparison with Python smolagents.

**Summary:** 100% parity achieved, with Ruby exceeding Python in:
- Chainable ToolResult
- Pattern matching
- Circuit breaker / rate limiting
- Fluent builder DSL
- Goal DSL with composition

---

## Coverage Metrics

### Code Coverage

- **Overall:** 87.13%
- **Threshold:** 80% overall, 30% per-file
- **Report:** `coverage/index.html`

Run with: `bundle exec rspec` (SimpleCov integrated)

**Excluded from coverage:**
- `lib/smolagents/testing/` - Requires live models for meaningful tests

**Files below 50% (require integration tests):**

| File | Coverage | Reason |
|------|----------|--------|
| `events/scheduler.rb` | 36% | Advanced scheduling feature |
| `concerns/step_execution.rb` | 40% | Requires agent execution context |
| `concerns/browser.rb` | 43% | Integration tests needed |
| `types/goal_dynamic.rb` | 44% | New feature |

### Documentation Coverage

- **Overall:** 70.74%
- **Target:** 90%
- **Report:** `bundle exec yard stats --list-undoc`

Run with: `bundle exec rake doc:stats`

**Undocumented by type:**

| Type | Documented | Undocumented | % |
|------|------------|--------------|---|
| Modules | 63 | 29 | 68% |
| Classes | 147 | 19 | 89% |
| Constants | 100 | 112 | 47% |
| Methods | 724 | 371 | 66% |

### Test Metrics

- **Total Tests:** 2275
- **Pending:** 42 (integration tests requiring live models/Docker/Ractor)
- **Target Time:** <10 seconds

Run with: `bundle exec rspec`

### Pending Test Categories

| Category | Count | Reason |
|----------|-------|--------|
| Live model tests | ~30 | Requires `LIVE_MODEL_TESTS=1` and running LM Studio/Ollama |
| Ractor orchestrator | 2 | Requires Ractor environment setup |
| Docker executor | ~5 | Requires Docker daemon |
| Model benchmarks | ~5 | Requires live model connections |

---

## Architecture Reference

```
lib/smolagents/
├── agents/        # CodeAgent, ToolCallingAgent
├── builders/      # AgentBuilder, ModelBuilder, TeamBuilder
├── concerns/      # 25+ composable modules
├── events/        # Typed events + emitter/consumer
├── executors/     # Ruby, Docker, Ractor
├── models/        # OpenAI, Anthropic, LiteLLM
├── persistence/   # Save/load agents
├── telemetry/     # Instrumentation, logging
├── tools/         # Tool base + 10 built-ins
├── types/         # Data.define types
└── pipeline.rb    # Composable tool chains
```

---

## DSL Design Principles

### The Five Complementary DSLs

| DSL | Purpose | Returns | Immutable | Pattern Match |
|-----|---------|---------|-----------|---------------|
| **AgentBuilder** | Configure agents | Agent | ✅ | ✅ |
| **TeamBuilder** | Compose agents | Coordinator Agent | ✅ | ✅ |
| **ModelBuilder** | Configure models + reliability | Model | ✅ | ✅ |
| **Pipeline** | Chain tool calls | ToolResult | ✅ | ✅ |
| **Goal** | Rich task representation | Goal (result) | ✅ | ✅ |

### Shared Patterns (Builders::Base)

All builders provide:
- **Immutability**: Each method returns new instance via `with_config(**kwargs)`
- **Fluent chaining**: `.model{}.tools().max_steps().build`
- **freeze!**: Lock configuration for production safety
- **help**: REPL-friendly introspection
- **Validation**: `builder_method` with validates lambda
- **Pattern matching**: Via Data.define

### Compositional Tower

```
Pipeline (deterministic tool chains)
    ↓ .as_tool()
Tool (reusable computation)
    ↓ AgentBuilder.tools()
AgentBuilder (single agent)
    ↓ TeamBuilder.agent()
TeamBuilder (multi-agent coordination)
    ↓ Goal.with_agent()
Goal (rich task with criteria)
```

---

## Event System Architecture

### Event Types (17 Data.define types)

**Tool Events:**
- `ToolCallRequested` - Before tool execution
- `ToolCallCompleted` - After tool execution (result, observation)

**Model Events:**
- `ModelGenerateRequested` - Before LLM API call
- `ModelGenerateCompleted` - After LLM response (tokens)

**Step/Task Events:**
- `StepCompleted` - Per-step tracking (outcome: success/error/final_answer)
- `TaskCompleted` - Task-level completion

**Sub-Agent Events:**
- `SubAgentLaunched`, `SubAgentProgress`, `SubAgentCompleted`

**Reliability Events:**
- `RateLimitHit` - Rate limit with computed due_at
- `RetryRequested`, `FailoverOccurred`, `RecoveryCompleted`
- `ErrorOccurred` - With recoverable flag
- `EventExpired` - Stale event cleanup

### Event Flow Pattern

```
Emitter (Model, Tool, Agent)
    ↓ emit_event()
EventQueue (priority queue with scheduling)
    ↓ pop_ready() / drain()
Consumer (Agent via .on())
    ↓ consume()
Handlers (registered callbacks)
```

### Priority Levels

```ruby
PRIORITY = {
  error: 0,      # Processed first
  immediate: 1,  # Ready events
  scheduled: 2,  # Future events (by due_at)
  background: 3  # Low priority
}
```

---

## Ractor Architecture

### Ruby 4.0 Ractor Fundamentals

Ractors provide true parallel execution with memory isolation. Unlike threads (which share memory and are limited by the GVL), each Ractor has its own GVL and cannot directly access objects from other Ractors.

**Core Concepts:**

| Concept | Description |
|---------|-------------|
| **Isolation** | Each Ractor runs in its own execution context with its own GVL |
| **Shareability** | Objects must be "shareable" to cross Ractor boundaries by reference |
| **Message Passing** | Non-shareable objects are copied (or moved) via message queues |
| **Block Isolation** | Ractor blocks cannot capture outer scope variables |

**Shareability Rules:**

```ruby
# SHAREABLE (can pass by reference)
42                              # Integers
3.14                            # Floats
:symbol                         # Symbols
true, false, nil                # Special constants
"frozen".freeze                 # Frozen strings (no unshareable refs)
[1, 2, 3].freeze                # Frozen arrays (if all elements shareable)
SomeClass                       # Class/Module references
Ractor.make_shareable(obj)      # Explicitly made shareable

# NOT SHAREABLE (must copy or reconstruct)
"mutable string"                # Unfrozen strings
[1, 2, 3]                       # Unfrozen arrays
{ key: "value" }                # Unfrozen hashes
Proc.new { }                    # All Procs (even frozen)
-> { }                          # All Lambdas (even frozen)
SomeClass.new                   # Instances with mutable state
```

**Communication Patterns:**

```ruby
# Pattern 1: Pass arguments at creation (copied automatically)
r = Ractor.new(config_hash) do |cfg|
  # cfg is a copy of config_hash
end

# Pattern 2: Send/Receive messages
r = Ractor.new do
  msg = Ractor.receive  # Block until message arrives
  process(msg)
end
r.send(data)            # Send data (copied if unshareable)

# Pattern 3: Get return value
r = Ractor.new { compute_result }
result = r.value        # Block until Ractor terminates

# Pattern 4: Select from multiple Ractors
r1 = Ractor.new { task1 }
r2 = Ractor.new { task2 }
ractor, value = Ractor.select(r1, r2)  # First to complete
```

### Ractor Types (Data.define)

| Type | Purpose | Key Fields |
|------|---------|------------|
| `RactorTask` | Task submitted to Ractor | task_id, agent_name, prompt, config, timeout |
| `RactorSuccess` | Success result | task_id, output, steps_taken, token_usage, duration |
| `RactorFailure` | Failure result | task_id, error_class, error_message, steps_taken |
| `RactorMessage` | Message envelope | type (:task/:result), payload |
| `OrchestratorResult` | Aggregated result | succeeded[], failed[], duration |

**Note:** These Data.define types are shareable when their values are shareable (primitives, frozen strings, symbols). In `RactorOrchestrator`, we convert to plain hashes because `config` may contain unshareable VALUES (model instances, agent objects), not because of Data.define itself. See "Data.define Ractor Shareability" section below.

### How Code Execution Ractor Works

The `Executors::Ractor` handles all Ractor complexity internally. The design:

```
Main Thread                              Ractor Sandbox
────────────────────────────────────────────────────────────────

executor.execute(code)
├── prepare_variables()                  → Freeze all values for Ractor
├── Ractor.new(code, vars) { }          ─┬─> Isolated execution
│                                        │   ├── TracePoint for operation limit
│                                        │   ├── BasicObject sandbox
│                                        │   └── Tool calls via message passing
├── Wait for result                     <┘
└── build_result()
```

**Key Design Points:**
- Code sandbox uses `BasicObject` subclass with no external access
- Tool calls from sandbox route back to main Ractor via messages
- `prepare_for_ractor()` recursively freezes objects
- Operation limits via TracePoint prevent infinite loops
- All Ractor complexity is encapsulated in this one class

### Tool Calls from Sandbox (Message Passing)

When agent code calls a tool inside the Ractor sandbox:

```ruby
# Inside Ractor sandbox:
result = search_tool(query: "Ruby")

# Actually does:
# 1. Sandbox method_missing detects tool call
# 2. Sends message to main Ractor: { type: :tool_call, name: "search_tool", args: ... }
# 3. Main Ractor receives, executes tool in trusted context
# 4. Sends response back to child Ractor
# 5. Child Ractor receives and returns value
```

This keeps tools in the trusted zone while code runs in the untrusted zone.

---

## Ractor Isolation Interface Design

### Design Goals

Based on research into Ruby 4.0 Ractor patterns, game loop architectures, and our existing codebase idioms, the isolation interface should:

1. **Be invisible to users** - Agent and Tool authors never see Ractor complexity
2. **Fit existing patterns** - Use Data.define, events, and concerns like everything else
3. **Single master loop** - The ReAct loop owns execution; executor exposes `execute()` not `run_forever()`
4. **Message-based tool calls** - Events cross the isolation boundary, not method calls

### The Interface: What Users See

```ruby
# User code never changes - Ractor isolation is transparent
executor = Executors::Ractor.new(tools: [search_tool, calculator])
result = executor.execute(code, language: :ruby)

case result
in ExecutionResult[output:, logs:, error: nil]
  # Success - use output
in ExecutionResult[error:]
  # Handle error
end
```

### Internal Architecture: How It Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│ TRUSTED ZONE (Main Thread)                                              │
│                                                                         │
│  executor.execute(code)                                                 │
│       │                                                                 │
│       ├── prepare_variables()  ─────> freeze all values                │
│       │                                                                 │
│       ├── Ractor.new(code, vars) ────────────────────┐                 │
│       │                                              │                 │
│       │   ┌─────────────────────────────────────────┐│                 │
│       │   │ UNTRUSTED ZONE (Ractor)                 ││                 │
│       │   │                                         ││                 │
│       │   │  sandbox.instance_eval(code)           ││                 │
│       │   │       │                                 ││                 │
│       │   │       ├── method_missing(:tool_name)   ││                 │
│       │   │       │       │                        ││                 │
│       │   │       │       ▼                        ││                 │
│       │   │       │   { type: :tool_call, ... }   ─┼┼─> Ractor.main.send()
│       │   │       │       ▲                        ││                 │
│       │   │       │   response ◄──────────────────┼┼── Ractor.receive
│       │   │       │       │                        ││                 │
│       │   │       ▼                                ││                 │
│       │   │   return result                        ││                 │
│       │   └─────────────────────────────────────────┘│                 │
│       │                                              │                 │
│       ◄──────────────────────────────────────────────┘                 │
│       │                                                                 │
│       └── build_result()                                               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Boundary Types (Data.define)

All data crossing the Ractor boundary uses these immutable types:

```ruby
module Executors
  # Request from sandbox to main Ractor
  ToolCallRequest = Data.define(:request_id, :tool_name, :args, :kwargs) do
    def to_message = { type: :tool_call, **to_h }.freeze
  end

  # Response from main Ractor to sandbox
  ToolCallResponse = Data.define(:request_id, :result, :error, :final_answer) do
    def success? = error.nil? && !final_answer
    def final? = !!final_answer

    def self.success(request_id:, result:)
      new(request_id:, result:, error: nil, final_answer: nil)
    end

    def self.error(request_id:, message:)
      new(request_id:, result: nil, error: message, final_answer: nil)
    end

    def self.final(request_id:, value:)
      new(request_id:, result: nil, error: nil, final_answer: value)
    end
  end

  # Final result from execution
  ExecutionResult = Data.define(:output, :logs, :error, :is_final) do
    def success? = error.nil?
    def final_answer? = is_final
  end
end
```

### Message Protocol

The sandbox and main Ractor communicate via a simple protocol:

**Sandbox → Main (Request):**
```ruby
{
  type: :tool_call,
  request_id: "uuid",
  tool_name: "search_tool",
  args: [],
  kwargs: { query: "Ruby" }
}
```

**Main → Sandbox (Response):**
```ruby
{ result: "search results..." }        # Success
{ error: "Unknown tool" }              # Error
{ final_answer: "42" }                 # FinalAnswer tool
```

**Sandbox → Main (Completion):**
```ruby
{
  type: :result,
  output: "computed value",
  logs: "stdout output",
  error: nil,
  is_final: false
}
```

### Bounded Processing Pattern

Following the game loop pattern, message processing is bounded:

```ruby
def process_messages(child_ractor)
  MAX_MESSAGE_ITERATIONS.times do
    message = Ractor.receive

    case message
    in { type: :result, **data }
      return data  # Done - exit cleanly
    in { type: :tool_call, name:, args:, kwargs:, caller_ractor: }
      response = execute_tool_safely(name, args, kwargs)
      caller_ractor.send(response)
    end
  end

  # Safety limit reached
  { output: nil, logs: "", error: "Message limit exceeded", is_final: false }
end
```

### Sandbox Classes (BasicObject)

Two sandbox types, both extending BasicObject for minimal surface:

```ruby
# Without tools - pure computation
class IsolatedSandbox < BasicObject
  def initialize(variables:, output_buffer:)
    @variables = variables
    @output_buffer = output_buffer
  end

  def method_missing(name, *)
    @variables.fetch(name.to_s) do
      ::Kernel.raise(::NoMethodError, "undefined method `#{name}' in sandbox")
    end
  end

  def puts(*) = @output_buffer.puts(*) || nil
  def print(*) = @output_buffer.print(*) || nil
  def state = @variables
end

# With tools - adds message passing
class ToolSandbox < IsolatedSandbox
  def initialize(tool_names:, **opts)
    super(**opts)
    @tool_names = tool_names
  end

  def method_missing(name, *args, **kwargs)
    return call_tool(name.to_s, args, kwargs) if @tool_names.include?(name.to_s)
    super
  end

  private

  def call_tool(name, args, kwargs)
    ::Ractor.main.send({
      type: :tool_call,
      name:, args:, kwargs:,
      caller_ractor: ::Ractor.current
    })

    case ::Ractor.receive
    in { result: value }     then value
    in { final_answer: v }   then ::Kernel.raise(FinalAnswerSignal, v)
    in { error: message }    then ::Kernel.raise(::RuntimeError, message)
    end
  end
end
```

### Integration with Event System

Tool calls from sandbox emit events for observability:

```ruby
def execute_tool_safely(name, args, kwargs)
  tool = @tools[name]
  return { error: "Unknown tool: #{name}" } unless tool

  # Emit event for telemetry (in trusted zone)
  emit_event(ToolCallRequested.new(tool_name: name, args:, kwargs:))

  begin
    result = tool.call(*args, **kwargs)
    emit_event(ToolCallCompleted.new(tool_name: name, result:))
    { result: prepare_for_ractor(result) }
  rescue FinalAnswerException => e
    { final_answer: prepare_for_ractor(e.value) }
  rescue => e
    emit_event(ErrorOccurred.new(error: e, recoverable: false))
    { error: "#{e.class}: #{e.message}" }
  end
end
```

### Ruby 4.0 Forward Compatibility

The current design uses `Ractor.receive`/`Ractor.send`. Ruby 4.0's `Ractor::Port` provides cleaner semantics:

```ruby
# Future: Ruby 4.0 Ractor::Port pattern
def execute_with_port(code)
  reply_port = Ractor::Port.new

  Ractor.new(code, reply_port) do |code_str, port|
    result = execute_sandboxed(code_str)
    port << result  # Non-blocking send
  end

  reply_port.receive  # Wait for result
end
```

The interface is designed to evolve to `Ractor::Port` without changing the public API.

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| BasicObject sandbox | Minimal attack surface, no Kernel methods |
| Message-based tool calls | Tools stay in trusted zone, results cross boundary |
| Bounded message loop | Prevents runaway tool calls, deterministic |
| Data.define for all boundary types | Immutable, pattern-matchable, fits codebase |
| Event emission in trusted zone | Observability without leaking into sandbox |
| prepare_for_ractor() | Automatic freezing, safe serialization |

### What This Design Gives Us

1. **Simplicity** - One class (`Executors::Ractor`) encapsulates all complexity
2. **Security** - Two-layer defense: AST validation + runtime isolation
3. **Observability** - Events emit for all tool calls, errors, completions
4. **Testability** - Mock the executor, inject responses, verify messages
5. **Extensibility** - Add new tool types without touching sandbox code
6. **Forward compatibility** - Ready for Ruby 4.0 `Ractor::Port`

---

## Critical Testing Plan

### [Testing] Events Scheduler Module
**Status:** Not Started
**Priority:** P0 (CRITICAL)

Scheduler module has **0% test coverage** despite being core to event timing.

**File:** `lib/smolagents/events/scheduler.rb` (153 LOC)

**Required Tests:**
- [ ] `schedule(event, delay: 5.0)` - Event due in N seconds
- [ ] `schedule_at(event, Time.now + 10)` - Event at specific time
- [ ] `schedule_after(event, 3.0)` - Alias verification
- [ ] `schedule_retry(request, retry_after:)` - Rate limit retry scheduling
- [ ] `handle_stale_events(threshold:)` - Cleanup past-due events
- [ ] `next_scheduled_in` - Time until next event
- [ ] `process_ready_events(max:)` - Batch processing
- [ ] `cancel_scheduled { predicate }` - Cancellation
- [ ] Integration with EventQueue

**Approach:** Mock `event_queue`, verify `due_at` is set correctly via `event.with()`.

---

### [Testing] Events Mappings Module
**Status:** Not Started
**Priority:** P0 (CRITICAL)

Mappings module has **0% test coverage** - handles symbol→class resolution.

**File:** `lib/smolagents/events/mappings.rb`

**Required Tests:**
- [ ] `resolve(:step_complete)` → `StepCompleted` class
- [ ] `resolve(StepCompleted)` → `StepCompleted` (passthrough)
- [ ] `valid?(:unknown_event)` → false
- [ ] All 15 EVENTS names resolve correctly
- [ ] All ALIASES resolve to correct events
- [ ] Error on unknown event names

**Approach:** Exhaustive mapping verification, error case testing.

---

### [Testing] Ractor Orchestrator Integration
**Status:** Complete (2026-01-13) - 36 tests
**Priority:** P3 (lowered - optional feature)

Comprehensive unit testing of all reconstruction logic. Only full Ractor execution tests are pending (require Ractor environment).

**File:** `lib/smolagents/orchestrators/ractor_orchestrator.rb`

**Note:** With our clarified architecture, RactorOrchestrator is an *optional* feature for when you need true memory isolation between agents. Thread-based parallelism works for most use cases. The primary Ractor use case is `Executors::Ractor` for code sandboxing.

**Completed (36 tests):**
- [x] `prepare_agent_config` captures all reconstruction data
- [x] `prepare_agent_config` with planning_interval, custom_instructions
- [x] `prepare_agent_config` max_steps priority (task config vs agent)
- [x] `extract_model_config` excludes sensitive data
- [x] `extract_model_config` with nil client, no generate method
- [x] `extract_model_config` returns empty frozen hash when no config
- [x] `execute_agent_task` happy path with valid config
- [x] `execute_agent_task` error conditions (missing API key, unknown model/tool/agent)
- [x] `execute_agent_task` with nil model_config
- [x] `execute_agent_task` with empty tools array
- [x] `execute_agent_task` with multiple tools
- [x] `execute_agent_task` with planning_interval and custom_instructions
- [x] `execute_agent_task` with CodeAgent class
- [x] Result aggregation (mixed success/failure)
- [x] `OrchestratorResult` predicates (all_success?, any_success?)
- [x] `extract_result` pattern matching
- [x] `create_ractor_error_failure` with cause and without

**Still Pending (optional - require Ractor environment):**
- [ ] `execute_parallel(tasks:, timeout:)` - Multiple agents in real Ractors
- [ ] `execute_single(agent_name:, prompt:, timeout:)` - Single agent in Ractor

---

### [Testing] Emitter-Consumer Integration
**Status:** Not Started
**Priority:** P1

Full event flow is not tested end-to-end.

**Required Tests:**
- [ ] Emitter → EventQueue → Consumer flow
- [ ] Handler execution order with multiple handlers
- [ ] Filter predicates across consume_batch
- [ ] Error in one handler doesn't block others
- [ ] Priority ordering in practice
- [ ] Scheduled event becomes ready over time (mock clock)

---

### [Testing] Builder Error Conditions
**Status:** Not Started
**Priority:** P2

Mostly happy-path testing exists; need negative cases.

**Required Tests:**
- [ ] `AgentBuilder.build` without model → ArgumentError
- [ ] `AgentBuilder.tools(:unknown)` → ArgumentError
- [ ] `ModelBuilder` validation with out-of-range values
- [ ] `TeamBuilder` with 0 agents → ArgumentError
- [ ] Frozen builder rejects all modifications
- [ ] Double-freeze is idempotent

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-01-13 | **Deleted Events::Scheduler module** | 153 LOC with 0% usage in lib/. All scheduling methods defined but never called. Dead code for a feature that never materialized. |
| 2026-01-13 | **Flattened outcome type hierarchy** | Deleted 3 unused types (AgentExecutionOutcome, StepExecutionOutcome, ToolExecutionOutcome). Created shared OutcomePredicates module to eliminate 70+ LOC of duplicate predicate methods. ExecutionOutcome + ExecutorExecutionOutcome remain. |
| 2026-01-13 | **SearchTool simplification deferred to P1** | Analysis revealed DSL provides real value: abstracts parsers (JSON/HTML/RSS), auth methods, HTML extraction, rate limiting. Needs design work, not a quick rewrite. |
| 2026-01-13 | **Data.define Ractor shareability documented** | Empirically verified Data.define IS shareable when values are shareable. Fixed misleading comments in ractor_orchestrator.rb. Added documentation to ractor_types.rb, executors/ractor.rb, and PLAN.md. |
| 2026-01-13 | **Ractor isolation interface design finalized** | Synthesized research on Ruby 4.0, game loops, actor model into cohesive design. Interface invisible to users, fits existing patterns. |
| 2026-01-13 | **Bounded message processing** | Game loop pattern - process max N messages per step, deterministic, testable |
| 2026-01-13 | **Data.define for all boundary types** | ToolCallRequest, ToolCallResponse, ExecutionResult - immutable, pattern-matchable |
| 2026-01-13 | **Event emission in trusted zone** | Observability without leaking into sandbox - tool calls emit events in main thread |
| 2026-01-13 | **Ractors for code execution ONLY** | Model HTTP calls are I/O-bound (GVL releases). Only model OUTPUT (generated code) is untrusted and needs isolation. |
| 2026-01-13 | **Isolation boundary: model output, not model calls** | HTTP to OpenAI is trusted (we control it). Code the model generates is untrusted. |
| 2026-01-13 | Thread/Async for parallel agents | For I/O parallelism, threads work fine. Ractors add overhead without benefit. |
| 2026-01-13 | Models don't need Ractor changes | Models run in main thread; only `Executors::Ractor` needs Ractor complexity. |
| 2026-01-13 | Tools stay in trusted zone | Tool calls from sandbox route via message passing back to main Ractor. |
| 2026-01-13 | RactorSafeClient for RactorOrchestrator | Used by RactorModel inside Ractors where ruby-openai gem fails. Main-thread models use gems directly. |
| 2026-01-13 | RactorModel for RactorOrchestrator | Used when agents run inside Ractors (parallel orchestration). Main-thread agents use normal models. |
| 2026-01-13 | Keep event system everywhere | Events provide decoupling, testability, extensibility regardless of Ractor usage |
| 2026-01-13 | Scheduler/Mappings tests are P0 | 0% coverage on core event timing modules |
| 2026-01-13 | Five complementary DSLs | Pipeline→Tool→Agent→Team→Goal compositional tower |
| 2026-01-13 | Unified Goal and PlanOutcome | Reduce duplication, single DSL to learn |
| 2026-01-13 | Removed alias_method from builders | Forward-only, no backwards compat |
| 2026-01-12 | Constants outside Data.define | RuboCop compliance, cleaner code |
| 2026-01-12 | Kept Outcome module separate from Goal | Orthogonal concerns (state vs task) |
| 2026-01-12 | No API key serialization | Security - keys must be provided at load time |

---

## Ractor Research Summary (2026-01-13)

Comprehensive analysis of Ruby 4.0.1 Ractor internals and I/O patterns.

### Key Findings

1. **Ractors are for CPU isolation, not I/O parallelism** - HTTP calls release the GVL anyway. Threads/Async work fine for I/O.

2. **The isolation boundary is model OUTPUT, not model CALLS** - HTTP requests to OpenAI are trusted (we construct them). Code the model generates is untrusted.

3. **`Executors::Ractor` is the only place we need Ractor complexity** - It sandboxes agent-generated code with memory isolation.

4. **Tool calls route via message passing** - Tools execute in main Ractor (trusted zone), results return to sandbox via messages.

5. **Models don't run in Ractors** - No need for RactorModel, RactorSafeClient for model calls. Regular ruby-openai gem works fine.

### Data.define Ractor Shareability (CRITICAL)

**Empirically verified (2026-01-13):** Data.define objects ARE Ractor-shareable when their values are shareable.

```ruby
# ✅ SHAREABLE - primitives, frozen strings, symbols, nested Data.define
Point = Data.define(:x, :y) { def sum = x + y }
p = Point.new(x: 1, y: 2)
Ractor.shareable?(p)  # => true

# ✅ SHAREABLE - custom methods in block do NOT affect shareability
# Methods are on the class, not stored as Procs in the instance

# ❌ NOT SHAREABLE - unfrozen strings (but make_shareable fixes it)
Point.new(x: "hello", y: "world")  # shareable? => false
Ractor.make_shareable(point)       # shareable? => true

# ❌ NOT SHAREABLE - Proc/Lambda VALUES, complex object VALUES
Point.new(x: 1, y: -> { 2 })       # shareable? => false (Proc value)
Point.new(x: 1, y: SomeClass.new)  # shareable? => false (object value)
```

**Shareability Rules for Data.define:**

| Value Type | Shareable? | Notes |
|------------|------------|-------|
| Integers, Floats, Symbols | ✅ YES | Primitives always shareable |
| `nil`, `true`, `false` | ✅ YES | Special constants |
| Frozen strings | ✅ YES | Must be `.freeze` or frozen literal |
| Unfrozen strings | ❌ NO | Use `Ractor.make_shareable` or freeze |
| Frozen arrays/hashes | ✅ YES | If all contents also shareable |
| Nested Data.define | ✅ YES | If nested values shareable |
| Procs/Lambdas | ❌ NO | Never shareable as values |
| Class/Module references | ✅ YES | Classes are shareable |
| Arbitrary objects | ❌ NO | Unless explicitly made shareable |

**Key Insight:** The `RactorOrchestrator` converts to hashes NOT because "Data.define uses Procs" but because `config` may contain unshareable VALUES (model instances, agent objects). For `Executors::Ractor`, we CAN use Data.define because we control the values.

### Final Architecture

| Component | Where It Runs | Why |
|-----------|---------------|-----|
| Model HTTP calls | Main thread | I/O-bound, GVL releases, threads work |
| JSON parsing | Main thread | Trusted operation (we control format) |
| Agent logic | Main thread | Stateful, event-driven, no isolation needed |
| **Code execution** | **Ractor sandbox** | **Untrusted model output needs isolation** |
| Tool execution | Main thread | Called via message passing from sandbox |
| Event system | Everywhere | Orthogonal to Ractor usage |

### What We Keep

- `Executors::Ractor` - Correct use of Ractors for sandboxing
- `Executors::LocalRuby` - Simpler in-process sandbox option
- Event system - Decoupled, testable, extensible

### What We Don't Need

- ~~RactorSafeClient for models~~ - Models run in main thread
- ~~RactorModel for agents~~ - Only code execution needs Ractor
- ~~Ractor-safe Tool redesign~~ - Tools called via message passing
- ~~Complex RactorOrchestrator~~ - Threads work for parallel agents

---

*Last updated: 2026-01-13 (Data.define Ractor shareability documented across codebase)*
