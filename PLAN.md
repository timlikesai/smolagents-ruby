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

## Current Work

*Nothing currently in progress. All major initiatives complete.*

---

## Completed Work

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

### [Implementation] Complete Ractor Orchestrator
**Status:** Not Started
**Priority:** P0 (CRITICAL - Implementation Incomplete)

The Ractor orchestrator currently returns **mock results** instead of actually executing agents. This is a core feature that is not functional.

**Current State:**
```ruby
# lib/smolagents/orchestrators/ractor_orchestrator.rb:177-183
def execute_agent_task(task, _config)
  RactorMockResult.new(
    output: "Executed: #{task.prompt}",  # Just echoes prompt!
    steps: [],
    token_usage: TokenUsage.zero
  )
end
```

**The Problem:**
Ractors require all data to be "shareable" (deeply frozen, no mutable references). Agents contain:
- Model clients with HTTP connections (not shareable)
- API keys as instance variables
- Mutable tool state
- Logger references

**Solution Architecture:**

```
Parent Ractor                          Child Ractor
─────────────                          ────────────
agent.model.class.name ───────────────► Reconstruct model from class + config
agent.model.model_id   ───────────────►
agent.tools.keys       ───────────────► Rebuild tools from registry
task config            ───────────────► Create fresh agent
                                        Execute agent.run(prompt)
                       ◄─────────────── Return RactorSuccess/RactorFailure
```

**Implementation Steps:**

1. **Extend `prepare_agent_config`** to capture all reconstruction data:
   ```ruby
   def prepare_agent_config(agent, task)
     {
       model_class: agent.model.class.name,
       model_id: agent.model.model_id,
       model_config: extract_model_config(agent.model),  # NEW
       agent_class: agent.class.name,
       max_steps: task.config[:max_steps] || agent.max_steps,
       tool_names: agent.tools.keys.freeze,
       planning_interval: agent.planning_interval,        # NEW
       custom_instructions: agent.custom_instructions     # NEW
     }.freeze
   end
   ```

2. **Add `extract_model_config`** to safely serialize model settings:
   ```ruby
   def extract_model_config(model)
     {
       api_base: model.respond_to?(:api_base) ? model.api_base : nil,
       temperature: model.respond_to?(:temperature) ? model.temperature : nil,
       max_tokens: model.respond_to?(:max_tokens) ? model.max_tokens : nil,
       timeout: model.respond_to?(:timeout) ? model.timeout : nil
       # API key handled separately via ENV
     }.compact.freeze
   end
   ```

3. **Implement `execute_agent_task`** to reconstruct and run:
   ```ruby
   def self.execute_agent_task(task, config)
     # Reconstruct model
     model_class = Object.const_get(config[:model_class])
     model = model_class.new(
       model_id: config[:model_id],
       api_key: ENV["SMOLAGENTS_API_KEY"],  # From environment
       **config[:model_config]
     )

     # Reconstruct tools from registry
     tools = config[:tool_names].map { |name| Tools.get(name) }

     # Reconstruct agent
     agent_class = Object.const_get(config[:agent_class])
     agent = agent_class.new(
       model: model,
       tools: tools,
       max_steps: config[:max_steps],
       planning_interval: config[:planning_interval]
     )

     # Execute and return actual result
     agent.run(task.prompt)
   end
   ```

4. **Handle API key securely:**
   - Option A: Pass via `ENV` (Ractor can read environment)
   - Option B: Use `Ractor.make_shareable(api_key.dup.freeze)`
   - Option C: Add `RactorOrchestrator.new(agents:, api_key:)` parameter

5. **Update `RactorSuccess.from_result`** to extract from real RunResult:
   ```ruby
   def self.from_result(task_id:, run_result:, duration:, trace_id:)
     new(
       task_id: task_id,
       output: run_result.output,
       steps_taken: run_result.step_count,
       token_usage: run_result.token_usage,
       duration: duration,
       trace_id: trace_id
     )
   end
   ```

**Edge Cases to Handle:**
- [ ] Model class not found → RactorFailure with clear error
- [ ] Tool not in registry → RactorFailure with available tools list
- [ ] API key missing → RactorFailure before attempting reconstruction
- [ ] Agent execution timeout → Ractor timeout handling
- [ ] Model API errors → Propagate as RactorFailure

**Testing Strategy:**
- Unit tests with mocked Ractor (verify config serialization)
- Integration tests with real Ractor + local model (LM Studio)
- Verify token usage and step counts are accurate
- Test timeout behavior
- Test error propagation

**Acceptance Criteria:**
- [ ] `execute_agent_task` reconstructs real agent from config
- [ ] `execute_parallel` runs multiple agents concurrently
- [ ] `execute_single` runs one agent in isolated Ractor
- [ ] Token usage and steps accurately reported
- [ ] Errors propagate as RactorFailure with context
- [ ] API key handling is secure (not logged, not in error messages)
- [ ] Works with OpenAIModel, AnthropicModel, LiteLLMModel
- [ ] All tools from registry can be reconstructed
- [ ] Integration test passes with live local model

**Files to Modify:**
- `lib/smolagents/orchestrators/ractor_orchestrator.rb` - Main implementation
- `lib/smolagents/types/ractor_types.rb` - May need RunResult extraction helpers
- `spec/smolagents/orchestrators/ractor_orchestrator_spec.rb` - Enable skipped tests

**Dependencies:**
- Tools registry must have all built-in tools registered
- Models must support reconstruction from class + config
- Persistence manifests can inform serialization approach

---

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
**Priority:** P2

Enable Ractor-based parallel execution tests.

**Acceptance Criteria:**
- [ ] `#execute_parallel` test passing
- [ ] `#execute_single` test passing
- [ ] Document Ractor environment requirements

**Notes:** Currently skipped in `spec/smolagents/orchestrators/ractor_orchestrator_spec.rb`.

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

- **Overall:** 87.24%
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
| `orchestrators/ractor_orchestrator.rb` | 42% | Ractor environment required |
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

- **Total Tests:** 2247
- **Pending:** 42 (integration tests requiring live models/Docker)
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

## Orchestration Architecture

### Ractor Types (Data.define)

| Type | Purpose | Key Fields |
|------|---------|------------|
| `RactorTask` | Task submitted to Ractor | task_id, agent_name, prompt, config, timeout |
| `RactorSuccess` | Success result | task_id, output, steps_taken, token_usage, duration |
| `RactorFailure` | Failure result | task_id, error_class, error_message, steps_taken |
| `RactorMessage` | Message envelope | type (:task/:result), payload |
| `OrchestratorResult` | Aggregated result | succeeded[], failed[], duration |

### Current Limitation

RactorOrchestrator currently returns mock results. Full agent reconstruction inside Ractors requires serializable model configs (models with API clients aren't Ractor-shareable).

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

### [Testing] Ractor Orchestrator Core
**Status:** Not Started
**Priority:** P1

Core orchestration methods are **skipped** (require Ractor environment).

**File:** `lib/smolagents/orchestrators/ractor_orchestrator.rb`

**Required Tests (mock Ractor if needed):**
- [ ] `execute_parallel(tasks:, timeout:)` - Multiple agents
- [ ] `execute_single(agent_name:, prompt:, timeout:)` - Single agent
- [ ] Timeout handling and cleanup
- [ ] `Ractor::RemoteError` recovery
- [ ] Result aggregation (mixed success/failure)
- [ ] `max_concurrent` limit enforcement
- [ ] `OrchestratorResult` predicates (all_success?, any_success?)

**Approach:** Either mock Ractor or create minimal Ractor test environment.

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
| 2026-01-13 | Ractor completion is P0 | Core feature returns mock results - not functional |
| 2026-01-13 | Reconstruct agents in child Ractor | Only way to handle non-shareable model clients |
| 2026-01-13 | API key via ENV for Ractors | ENV is readable in child Ractors, secure approach |
| 2026-01-13 | Scheduler/Mappings tests are P0 | 0% coverage on core event timing modules |
| 2026-01-13 | Five complementary DSLs | Pipeline→Tool→Agent→Team→Goal compositional tower |
| 2026-01-13 | Unified Goal and PlanOutcome | Reduce duplication, single DSL to learn |
| 2026-01-13 | Removed alias_method from builders | Forward-only, no backwards compat |
| 2026-01-12 | Constants outside Data.define | RuboCop compliance, cleaner code |
| 2026-01-12 | Kept Outcome module separate from Goal | Orthogonal concerns (state vs task) |
| 2026-01-12 | No API key serialization | Security - keys must be provided at load time |

---

*Last updated: 2026-01-13 (Ractor implementation plan added)*
