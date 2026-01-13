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

### [Documentation] API Reference Generation
**Status:** Not Started
**Priority:** P2

Generate comprehensive API documentation.

**Acceptance Criteria:**
- [ ] YARD documentation complete on all public methods
- [ ] Generated HTML docs
- [ ] Examples in documentation
- [ ] Published to docs site

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

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-01-13 | Unified Goal and PlanOutcome | Reduce duplication, single DSL to learn |
| 2026-01-13 | Removed alias_method from builders | Forward-only, no backwards compat |
| 2026-01-12 | Constants outside Data.define | RuboCop compliance, cleaner code |
| 2026-01-12 | Kept Outcome module separate from Goal | Orthogonal concerns (state vs task) |
| 2026-01-12 | No API key serialization | Security - keys must be provided at load time |

---

*Last updated: 2026-01-13 (coverage tooling added)*
