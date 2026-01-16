# smolagents-ruby Project Plan

> **When updating this file:** Remove completed sections, consolidate history, keep it lean.
> The plan should be actionable, not archival. If work is done, collapse it to a single line in Completed.

Delightfully simple agents that think in Ruby.

See [ARCHITECTURE.md](ARCHITECTURE.md) for vision, patterns, and examples.

---

## Principles

- **Ship it**: Working software over perfect architecture
- **Simple first**: If it needs explanation, simplify it
- **Test everything**: No feature without tests
- **Delete unused code**: If nothing calls it, remove it
- **Cops guide development**: Fix the code, not disable the cop
- **DSL consistency**: Verb prefixes (`define_*`, `register_*`), unified `fields:` terminology
- **Token efficiency**: Compact DSLs reduce boilerplate for AI agent consumption

---

## Current Status

**What works:**
- CodeAgent & ToolAgent - write Ruby code or use JSON tool calling
- Builder DSL - `Smolagents.agent.tools(:search).as(:researcher).model{}.build`
- Composable atoms - Toolkits (tool groups), Personas (behavior), Specializations (bundles)
- Models - OpenAI, Anthropic, LiteLLM adapters with reliability/failover
- Tools - base class, registry, 10+ built-ins, SearchTool DSL
- ToolResult - chainable, pattern-matchable, Enumerable
- Executors - Ruby sandbox, Docker, Ractor isolation
- Events - DSL-generated immutable types, Emitter/Consumer pattern
- Errors - DSL-generated classes with pattern matching
- Fiber-first execution - `fiber_loop()` as THE ReAct loop primitive
- Control requests - UserInput, Confirmation, SubAgentQuery with DSL
- Ruby 4.0 idioms enforced via RuboCop

**Metrics:**
- Code coverage: 93.65% (threshold: 80%)
- Doc coverage: 97.31% (target: 95%)
- Tests: 3170 examples, 0 failures
- RuboCop: 0 offenses

---

## Priority 1: Critical Fixes (P0)

> **Goal:** Fix failure modes discovered during research testing.
> **Research doc:** `exploration/FAILURE_MODES.md`

### UTF-8 Sanitization

| Task | Priority | Notes |
|------|----------|-------|
| Sanitize tool output before JSON serialization | P0 | `text.encode('UTF-8', invalid: :replace, undef: :replace)` |
| Add sanitization in HTTP response handling | P0 | ArXiv returns malformed UTF-8 |

### Circuit Breaker Categorization

| Task | Priority | Notes |
|------|----------|-------|
| Define `CIRCUIT_BREAKING_ERRORS` allowlist | P0 | Only true service failures should trip circuit |
| Exclude encoding errors from circuit count | P0 | `JSON::GeneratorError` is local, not service issue |
| Exclude rate limits from circuit count | P0 | Use retry with backoff instead |

---

## Priority 2: Orchestration Patterns (Research-Driven)

> **Goal:** Implement advanced orchestration patterns based on 2025 research synthesis.
> **Research doc:** `exploration/ORCHESTRATION_RESEARCH.md`
>
> **Key 2025 Findings:**
> - Multi-agent orchestration: 80-140x quality improvements
> - Pre-Act planning: 70% improvement over ReAct
> - Self-correction blind spot: External validators needed
> - Difficulty-aware routing: 11% accuracy at 64% cost

### Phase 0: Pre-Act Planning (High Impact - 70% Improvement)

| Task | Priority | Notes |
|------|----------|-------|
| Add planning phase before action | HIGH | Generate multi-step plan first |
| Plan refinement after each step | HIGH | Incorporate tool outputs into plan |
| Planning DSL (`.phase(:plan, :act, :reflect)`) | MEDIUM | Explicit phase configuration |

### Phase 1: Agent Temporal Context

| Task | Priority | Notes |
|------|----------|-------|
| System prompt timestamp injection | HIGH | Inject date/time/timezone at session start |

### Phase 2: Agent Modes (Metacognition)

| Task | Priority | Notes |
|------|----------|-------|
| Design `AgentMode` types | HIGH | `:reasoning`, `:evaluation`, `:correction` |
| Mode switching in fiber loop | HIGH | Agent can transition between modes |

### Phase 3: Goal State Tracking

| Task | Priority | Notes |
|------|----------|-------|
| Design `GoalTracker` concern | HIGH | Explicit goal state in agent |
| Subgoal decomposition | HIGH | Goals → subgoals hierarchy |

### Phase 4: Structured Error Handling

| Task | Priority | Notes |
|------|----------|-------|
| Error decomposition types | MEDIUM | `ErrorDetection`, `ErrorLocalization`, `ErrorCorrection` |
| Structured retry in tool execution | MEDIUM | Detect/localize/correct, not just "try again" |

### Phase 5: Memory as Tools

| Task | Priority | Notes |
|------|----------|-------|
| Memory tool interface | HIGH | Store, retrieve, summarize, forget operations |
| Working memory limit | MEDIUM | Token budget for active context |

### Phase 6: External Validator Pattern

| Task | Priority | Notes |
|------|----------|-------|
| Validator hook in agent loop | MEDIUM | External check before accepting output |

### Phase 7: Cost-Aware Tool Selection

| Task | Priority | Notes |
|------|----------|-------|
| Tool cost metadata | LOW | Latency, API cost, reliability scores |

### Phase 8: Hierarchical Delegation

| Task | Priority | Notes |
|------|----------|-------|
| Supervisor agent mode | MEDIUM | Decompose and delegate tasks |
| Worker agent orchestration | MEDIUM | Specialized worker agents |

---

## Priority 3: Consumer Hardware Orchestration

> **Goal:** Democratize powerful agent capabilities through intelligent orchestration of small models.
> **Vision:** Make the most of whatever hardware people have - local, cloud, or hybrid.
> **Research doc:** `exploration/ORCHESTRATION_RESEARCH.md` (Consumer Hardware section)
>
> **Key Research Findings:**
> - SLM-MUX: Two small models can beat 72B model through orchestration
> - Self-MoA: Same model ensemble beats mixing different models (6.6% improvement)
> - Self-Refine: 20% improvement with no training, just prompting
> - CISC: Confidence-weighted voting reduces samples by 40%

### Phase 1: Self-Refine Loop (Quick Win, 20% Improvement)

| Task | Priority | Notes |
|------|----------|-------|
| Implement `Smolagents.refine` builder | HIGH | Generate → Feedback → Refine cycle |
| Configurable feedback/refine prompts | HIGH | User can customize critique style |
| Stop conditions | MEDIUM | `until:`, `max_iterations:`, `unchanged?` |

### Phase 2: Swarm Ensemble (Self-MoA Pattern)

| Task | Priority | Notes |
|------|----------|-------|
| Implement `Smolagents.swarm` builder | HIGH | Parallel model instances |
| Temperature spread for diversity | HIGH | Same model, different temperatures |
| Confidence-weighted aggregation | HIGH | CISC-style voting |

### Phase 3: Hybrid Local/Cloud Routing

| Task | Priority | Notes |
|------|----------|-------|
| Model registry with cost metadata | MEDIUM | Free (local) vs paid (cloud) |
| Cost-aware routing DSL | MEDIUM | Prefer local, fallback to cloud |

### Phase 4: Debate Pattern

| Task | Priority | Notes |
|------|----------|-------|
| Implement `Smolagents.debate` builder | MEDIUM | Proposer → Critic → Judge |
| Role-based prompting | MEDIUM | Different personas per role |

---

## Priority 4: Security-Aware Routing

> **Goal:** Route data to appropriate models/infrastructure based on sensitivity and compliance.
> **Use cases:**
> - Newsrooms: source protection, whistleblower data, investigative materials
> - Healthcare: HIPAA, PHI, patient records
> - Finance: SOC2, trading data, customer financials
> - Legal: attorney-client privilege, litigation holds, contracts, discovery
> - HR: employee PII, performance reviews, salary data, investigations
> - Enterprise: data sovereignty, cross-border restrictions
> **Research doc:** `exploration/ORCHESTRATION_RESEARCH.md` (Security-Aware Routing section)

### Phase 1: Data Classification

| Task | Priority | Notes |
|------|----------|-------|
| Sensitivity classifier interface | HIGH | Detect PII, PHI, confidential data |
| Classification-based routing | HIGH | Local for sensitive, cloud otherwise |

### Phase 2: Compliance Modes

| Task | Priority | Notes |
|------|----------|-------|
| Compliance preset DSL | MEDIUM | `:hipaa`, `:gdpr`, `:sox`, `:fedramp` |
| PHI/PII sanitization pipeline | MEDIUM | Redact before sending to cloud |
| Audit trail integration | MEDIUM | Immutable logging for compliance |

### Phase 3: Ephemeral Processing

| Task | Priority | Notes |
|------|----------|-------|
| Zero retention mode | MEDIUM | No logging, no caching, no history |

### Phase 4: Air-Gapped Operation (Future)

> **Status:** Backlog - nice to have for high-security environments

---

## Priority 5: Parallel Tool Execution

> **Goal:** Implement speculative parallel tool calls with early yield.

### Already Implemented

| Component | Status | Location |
|-----------|--------|----------|
| `EarlyYield` concern | ✅ | `lib/smolagents/concerns/agents/early_yield.rb` |
| `ToolRetry` concern | ✅ | `lib/smolagents/concerns/resilience/tool_retry.rb` |

### Remaining Work

| Task | Priority | Notes |
|------|----------|-------|
| Integrate early yield into agent loop | MEDIUM | Use quality predicates for early return |
| Parallel tool call hints in prompts | LOW | Encourage parallel tool usage |

---

## Backlog

| Item | Priority | Notes |
|------|----------|-------|
| Sandbox DSL builder | LOW | Composable sandbox configuration |
| Headless browser executor | EXPLORATORY | Docker-based browser for JS-heavy sites |
| Plan caching (AgentReuse) | EXPLORATORY | Cache plans for similar requests |
| Automatic architecture search | EXPLORATORY | SwarmAgentic-style PSO optimization |

---

## Completed

| Date | Summary |
|------|---------|
| 2026-01-15 | **Security-Aware Routing Research**: 15+ papers on privacy/compliance. Patterns: data classification, compliance modes, ephemeral processing. |
| 2026-01-15 | **Consumer Hardware Orchestration Research**: 40+ papers. SLM-MUX, Self-MoA, Self-Refine, CISC voting, debate patterns. |
| 2026-01-15 | **Orchestration Research**: 25+ papers synthesized. Pre-Act, Agent Modes, Memory as Tools, External Validators. |
| 2026-01-15 | **Parallel Execution & Resilience**: EarlyYield, ToolRetry concerns. Browser mode for SearchTool. |
| 2026-01-15 | **Composable Agent Architecture**: Toolkits, Personas, Specializations. 35 composition tests. |
| 2026-01-15 | **RuboCop Compliance & Test Infrastructure**: Shared RSpec examples, complexity fixes, doc generation hook. |
| 2026-01-15 | **Fiber-First Execution Model**: 7 phases complete. `fiber_loop()` as THE ReAct primitive, control requests, events. 72 new tests. |
| 2026-01-14 | **Module Splits & RuboCop Campaign**: http/, security/, react_loop/, model_health/. All 91 offenses fixed. |
| 2026-01-13 | **Documentation**: YARD 97.31%, event system simplification (603→100 LOC), dead code removal (~860 LOC). |
| 2026-01-12 | **Infrastructure**: Agent persistence, DSL.Builder, Model reliability, Telemetry. |

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| `define_*` verb prefix | Consistent DSL naming across all macros |
| `fields:` terminology | Matches Data.define members |
| Events, not callbacks | Events are data (testable). Callbacks are behavior. |
| Forward-only | Delete unused code. No backwards compatibility. |
| Concern boundaries | Events::* for events, Builders::* for builders |
| Token efficiency | DSLs reduce boilerplate for AI agents |
| Cops guide development | Fix code, don't disable cops |
| Composable atoms | Toolkits/Personas/Specializations separate Mode, Tools, Behavior |
| Method-based access | `Toolkits.search` cleaner than SCREAMING_CASE constants |
| Auto-expansion | `.tools(:search)` expands toolkits, no splat needed |
| Research-driven design | Orchestration patterns cite specific papers |
| System prompt temporal context | Inject date/time/timezone at session start |
| DSL consistency | Support both block and symbol: `.model { }` and `.model(:lm_studio, "gemma")` |
| Security-first routing | Data classification determines model routing |
| Patterns harden design | Include enterprise patterns even if rarely used |
