# smolagents-ruby Implementation Plan

**Branch:** feature/tool-future-lazy-eval
**Updated:** 2026-01-26
**Version:** 2.0 (Post-Architecture Review)

---

## Executive Summary

This plan synthesizes findings from:
1. **Sonnet's Flux Design** - A greenfield event-driven agent framework proposal
2. **Consolidated Ideation Research** - 70+ ideas across 7 themes
3. **Architecture Comparison** - smolagents-ruby vs Flux patterns
4. **Gap Analysis** - Missing features and blind spots
5. **Model Ergonomics Study** - Small model friendliness assessment

**Core Insight**: "Help the model by giving it less to think about, not more."

---

## Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| Event System | ✅ Excellent | 75 event types, Emitter/Consumer pattern |
| Execution Model | ✅ Excellent | Ractor-based lazy futures, wave resolution |
| Tool System | ✅ Good | Schema validation, retry, timeout |
| Builder DSL | ✅ Good | Three-tier (Simple/Builder/Advanced) |
| Model Integration | ✅ Good | Multi-model, retry, circuit breaker |
| Documentation | ⚠️ Partial | YARD, guides needed |
| Small Model Support | ⚠️ Partial | Error hints, help system - needs more |
| Observability | ⚠️ Partial | Events exist, not queryable/replayable |
| Self-Healing | ✅ Good | Circuit breaker, loop detection, "Did You Mean?" |

**Test Suite:** 1788 examples, 95.7% coverage, ~6s parallel

---

## Priority Framework

### Tier 1: Critical Quick Wins (High Impact, Low Effort)
Features that immediately improve success rates with minimal code changes.

### Tier 2: Foundation Work (High Impact, Medium Effort)
Infrastructure that enables future capabilities.

### Tier 3: Strategic Bets (High Impact, High Effort)
Differentiating features that take investment.

### Tier 4: Polish & DX (Medium Impact)
Developer experience improvements.

---

## Tier 1: Critical Quick Wins

### 1.1 Loop Detection Middleware
**Impact:** Prevents most common catastrophic failure mode
**Effort:** 4-6 hours
**Status:** ✅ ALREADY IMPLEMENTED (lib/smolagents/concerns/agents/react_loop/repetition.rb)

```ruby
# Detects when agent is stuck repeating actions
module Concerns::Agents::LoopDetection
  SIMILARITY_THRESHOLD = 0.9
  MAX_REPEATS = 3

  def detect_loop(action_step)
    return false if @recent_actions.size < MAX_REPEATS

    current_hash = hash_action(action_step)
    repeat_count = @recent_actions.count { |h| similar?(h, current_hash) }

    if repeat_count >= MAX_REPEATS
      emit :loop_detected, action_hash: current_hash, repeat_count: repeat_count
      suggest_alternative_approach(action_step)
      true
    else
      false
    end
  end
end
```

**Blocked by:** Nothing
**Enables:** Reliable autonomous execution

---

### 1.2 Chain of Draft Prompting Mode
**Impact:** 80%+ token reduction for reasoning
**Effort:** 4-6 hours
**Status:** ✅ COMPLETED (2026-01-26)

Chain of Draft (CoD) elicits minimal drafts (5+ words) instead of verbose CoT reasoning. Research shows 7.6% of tokens for comparable accuracy.

```ruby
# In AgentBuilder
def reasoning_mode(mode)
  # :chain_of_thought - verbose reasoning (default)
  # :chain_of_draft - minimal drafts
  # :direct - no reasoning
  with_config(reasoning_mode: mode)
end

# In Prompts::Agent
CHAIN_OF_DRAFT_SUFFIX = <<~PROMPT
  Think step by step, but keep each step to 5-10 words maximum.
  Use shorthand, abbreviations, and notes-to-self style.
  Only the final answer needs to be complete.
PROMPT
```

**Blocked by:** Nothing
**Enables:** Cost-effective agents, faster responses

---

### 1.3 Progressive Tool Disclosure
**Impact:** Reduces cognitive load dramatically for small models
**Effort:** 2-3 days
**Status:** MISSING

Instead of loading all tool schemas upfront (100-200 tokens each), show metadata first (~20 tokens), full schema on selection.

```ruby
# Level 1: Metadata only (always shown)
TOOL_SUMMARY = <<~TOOLS
  Available tools:
  - search: Web search
  - calculate: Math expressions
  - read_file: Read file contents

  To use a tool: result = tool_name(...)
  For details: puts help(:tool_name)
TOOLS

# Level 2: Full schema (on help() or first use)
def expand_tool_schema(tool_name)
  tool = @tools[tool_name]
  <<~SCHEMA
    #{tool.name}(#{tool.args_signature}) -> #{tool.output_type}
    #{tool.description}

    Arguments:
    #{tool.inputs.map { |k, v| "  #{k}: #{v[:type]} - #{v[:description]}" }.join("\n")}

    Example: #{tool.example_call}
  SCHEMA
end
```

**Blocked by:** Nothing
**Enables:** Effective use of 7B-13B models

---

### 1.4 Budget/Context Awareness Signals
**Impact:** Helps models self-manage resources
**Effort:** 1-2 days
**Status:** PARTIALLY IMPLEMENTED (internal tracking exists)

Models currently don't know when context is running out. Add visible signals:

```ruby
# Inject into observation based on context usage
def context_awareness_signal(memory, step)
  usage = memory.token_usage_percent
  remaining = @max_steps - step.step_number - 1

  case usage
  when 0.9..
    "[URGENT: Context 90% full. Summarize findings and call final_answer NOW.]"
  when 0.75..0.9
    "[Context at #{(usage * 100).round}%. Consider summarizing soon.]"
  else
    nil
  end
end
```

**Blocked by:** Nothing
**Enables:** Fewer context overflow failures

---

### 1.5 "Did You Mean?" Error Messages
**Impact:** Faster recovery from typos
**Effort:** 4-6 hours
**Status:** ✅ COMPLETED (2026-01-26)

```ruby
# In tool resolution
def suggest_similar_tool(name, available_tools)
  distances = available_tools.map { |t| [t, levenshtein(name, t)] }
  closest = distances.min_by(&:last)

  if closest.last <= 3
    "Unknown tool '#{name}'. Did you mean '#{closest.first}'?"
  else
    "Unknown tool '#{name}'. Available: #{available_tools.join(', ')}"
  end
end
```

**Blocked by:** Nothing
**Enables:** Better DX, fewer retries

---

## Tier 2: Foundation Work

### 2.1 Event Sourcing Foundation
**Impact:** Enables replay, debugging, auditing
**Effort:** 1-2 weeks
**Status:** MISSING (events emit but don't persist)

All state changes should be reconstructible from event history:

```ruby
class EventStore
  def initialize(backend: :memory)
    @backend = backend
    @events = []
  end

  def append(event)
    @events << event.with(sequence: @events.size)
    @backend.persist(event) if @backend.respond_to?(:persist)
  end

  def replay(from: 0, to: nil)
    events = @events[from..(to || -1)]
    events.each { |e| yield e }
  end

  def state_at(sequence:)
    state = initial_state
    replay(to: sequence) { |e| state = apply_event(state, e) }
    state
  end
end
```

**Blocked by:** Nothing
**Enables:** Time-travel debugging, checkpointing, auditing

---

### 2.2 Checkpoint/Rollback Mechanism
**Impact:** Enables partial replay and recovery
**Effort:** 1 week
**Status:** MISSING

```ruby
class ExecutionCheckpoint
  attr_reader :step_number, :memory_snapshot, :state_snapshot, :timestamp

  def self.capture(agent, step)
    new(
      step_number: step.step_number,
      memory_snapshot: agent.memory.to_snapshot,
      state_snapshot: agent.state.dup,
      timestamp: Time.now
    )
  end

  def restore_to(agent)
    agent.memory.restore_from(memory_snapshot)
    agent.state.merge!(state_snapshot)
  end
end

# In AgentRunner
def create_checkpoint_if_stable(step)
  if step.success? && step.step_number % @checkpoint_interval == 0
    @checkpoints << ExecutionCheckpoint.capture(self, step)
  end
end
```

**Blocked by:** Event Sourcing (2.1)
**Enables:** Rollback on failure, what-if analysis

---

### 2.3 Model-Adaptive Prompting
**Impact:** Different prompts for different model capabilities
**Effort:** 1 week
**Status:** MISSING

```ruby
# Prompt adaptation by model size
module Prompts::ModelAdaptive
  LARGE_MODEL_TOKENS = 800  # Full instructions, 5 examples
  SMALL_MODEL_TOKENS = 250  # Simplified, 1-2 examples

  def generate_prompt(model_hint:, tools:, **options)
    case model_hint
    when :small   # 7B-13B
      generate_simplified_prompt(tools, max_examples: 2)
    when :medium  # 30B-70B
      generate_standard_prompt(tools, max_examples: 3)
    when :large   # 100B+
      generate_detailed_prompt(tools, max_examples: 5)
    end
  end

  def generate_simplified_prompt(tools, max_examples:)
    # Shorter sentences, simpler vocabulary
    # Fewer examples, explicit step-by-step format
    # Focus on recent messages only
  end
end
```

**Blocked by:** Nothing
**Enables:** Effective use of all model sizes

---

### 2.4 Failure Classification Taxonomy
**Impact:** Better retry/recovery decisions
**Effort:** 3-5 days
**Status:** UNDER-ENGINEERED (all errors treated similarly)

```ruby
module Errors
  class FailureClassification
    TRANSIENT = [:network_timeout, :rate_limit, :temporary_unavailable]
    PERMANENT = [:auth_failed, :invalid_input, :permission_denied]
    SEMANTIC = [:incoherent_response, :irrelevant_answer, :loop_detected]

    def classify(error)
      case error
      when Net::TimeoutError, Faraday::TimeoutError then :transient
      when AuthenticationError then :permanent
      when RateLimitError then :transient
      when ValidationError then :permanent
      else :unknown
      end
    end

    def retry_strategy_for(classification)
      case classification
      when :transient then :exponential_backoff
      when :permanent then :no_retry
      when :semantic then :alternative_approach
      when :unknown then :limited_retry
      end
    end
  end
end
```

**Blocked by:** Nothing
**Enables:** Smarter recovery, fewer wasted tokens

---

## Tier 3: Strategic Bets

### 3.1 Time-Travel Debugging Console
**Impact:** Revolutionary debugging experience
**Effort:** 2-3 weeks
**Status:** MISSING

```ruby
class TimeTravel
  def initialize(event_store)
    @store = event_store
  end

  # Jump to any point in execution
  def goto(step:)
    @store.state_at(sequence: step_to_sequence(step))
  end

  # What if we had made a different choice?
  def counterfactual(at_step:, with_action:)
    state = goto(step: at_step - 1)
    simulate_from(state, with_action)
  end

  # Find minimal prompt that causes failure
  def delta_debug_prompt(failing_step)
    # Binary search on prompt components
  end

  # Visual trace of execution
  def flame_graph
    @store.events.group_by(&:category).transform_values do |events|
      events.map { |e| { name: e.type, duration_ms: e.duration_ms } }
    end
  end
end
```

**Blocked by:** Event Sourcing (2.1), Checkpointing (2.2)
**Enables:** True understanding of agent behavior

---

### 3.2 Semantic Circuit Breaker
**Impact:** Catches semantic failures, not just technical ones
**Effort:** 1 week
**Status:** MISSING

```ruby
module Concerns::Resilience::SemanticCircuitBreaker
  SEMANTIC_FAILURES = [
    :incoherent_response,    # Output doesn't parse
    :irrelevant_answer,      # Doesn't address task
    :loop_detected,          # Repeated actions
    :confidence_decay,       # Declining quality
    :goal_drift              # Straying from objective
  ]

  def check_semantic_health(response, context)
    issues = []

    issues << :incoherent_response if !parseable?(response)
    issues << :irrelevant_answer if relevance_score(response, context) < 0.3
    issues << :confidence_decay if confidence_trending_down?(context)
    issues << :goal_drift if goal_alignment_score(response, context) < 0.5

    if issues.any?
      emit :semantic_failure_detected, issues: issues
      trip_semantic_breaker(issues)
    end
  end
end
```

**Blocked by:** Goal tracking (exists), Confidence tracking (partial)
**Enables:** Proactive failure prevention

---

### 3.3 Mixture-of-Agents (MoA) Pattern
**Impact:** Small model ensembles matching large models
**Effort:** 2 weeks
**Status:** MISSING

Research shows MoA achieves 65.8% win rate on benchmarks with small models:

```ruby
# In TeamBuilder
def mixture_of_agents(mode: :debate)
  # :debate - Agents argue, converge on answer
  # :voting - Majority/supermajority decision
  # :layers - Proposers → Aggregators pattern
  with_config(moa_mode: mode)
end

class MoAOrchestrator
  def execute(task)
    # Layer 1: Multiple proposers generate solutions
    proposals = @proposers.map { |p| p.async.run(task) }.map(&:value)

    # Layer 2: Aggregator synthesizes best answer
    @aggregator.run(
      task: task,
      proposals: proposals,
      instruction: "Synthesize the best answer from these proposals"
    )
  end
end
```

**Blocked by:** TeamBuilder (exists), Event orchestration (exists)
**Enables:** Cost-effective high-quality results

---

### 3.4 Privacy-First Architecture (from Flux design)
**Impact:** PII protection as architectural concern
**Effort:** 2-3 weeks
**Status:** MISSING

```ruby
module Privacy
  class PIIDetector
    PATTERNS = {
      email: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z]{2,}\b/i,
      phone: /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/,
      ssn: /\b\d{3}-\d{2}-\d{4}\b/,
      credit_card: /\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b/
    }

    def detect(text)
      PATTERNS.flat_map { |type, pattern| text.scan(pattern).map { |m| { type:, match: m } } }
    end
  end

  class PIIProtection
    def protect(text, strategy: :tokenize)
      pii = @detector.detect(text)
      return text if pii.empty?

      case strategy
      when :tokenize then tokenize(text, pii)
      when :mask then mask(text, pii)
      when :remove then remove(text, pii)
      end
    end

    def restore(text)
      @token_map.each { |token, original| text = text.gsub(token, original) }
      text
    end
  end
end
```

**Blocked by:** Nothing
**Enables:** Compliance, local model fallback for PII

---

## Tier 4: Polish & Developer Experience

### 4.1 Test Mode First-Class API
**Impact:** Safe experimentation, reproducible testing
**Effort:** 1-2 days
**Status:** PARTIAL (MockModel exists, not first-class)

```ruby
# Global test mode
Smolagents.test_mode!

# Or per-agent
agent = Smolagents.agent
  .model { Smolagents::Testing::MockModel.new(responses: [...]) }
  .logging(:verbose)  # Log all LLM calls
  .build

# Assertions
expect(model).to be_exhausted
expect(agent.call_log).to include(tool: :search, args: { query: "Ruby" })
```

**Blocked by:** Nothing
**Enables:** Better testing, CI/CD

---

### 4.2 Request Logging API
**Impact:** Debug visibility into LLM calls
**Effort:** 4-6 hours
**Status:** PARTIAL (internal logging exists)

```ruby
agent = Smolagents.agent
  .model { model }
  .logging(:requests)  # Log prompts and responses
  .build

# Access after execution
agent.request_log.each do |entry|
  puts "Prompt: #{entry.prompt[0..100]}..."
  puts "Response: #{entry.response[0..100]}..."
  puts "Tokens: #{entry.usage}"
end
```

**Blocked by:** Nothing
**Enables:** Better debugging, cost analysis

---

### 4.3 Tool Result Type Hints
**Impact:** Clearer tool usage guidance
**Effort:** 1 day
**Status:** ✅ COMPLETED (2026-01-26)

```ruby
# Instead of: search(query: string) -> array
# Show:       search(query: string) -> Array<{title: String, url: String, snippet: String}>

def output_type_hint
  case @output_schema
  when Hash
    "Hash with keys: #{@output_schema[:properties].keys.join(', ')}"
  when Array
    "Array of #{@output_schema[:items][:type]}"
  else
    @output_type
  end
end
```

**Blocked by:** Nothing
**Enables:** Fewer tool usage errors

---

### 4.4 Documentation (Existing Backlog)
**Impact:** Adoption and maintainability
**Effort:** 1-2 weeks
**Status:** NOT STARTED

| Task | Description |
|------|-------------|
| YARD docs | All DSL builder methods |
| Multi-model guide | Building agents with multiple models |
| Parallel agents guide | Sub-agent spawning patterns |
| Event patterns guide | Subscription, emission, error handling |
| Future system docs | AgentFuture vs RactorLazy::ToolFuture |

**Blocked by:** Nothing (can run in parallel)
**Enables:** Adoption, contributions

---

## Implementation Roadmap

### Phase A: Quick Wins (Week 1-2)

| Task | Effort | Impact | Status |
|------|--------|--------|--------|
| 1.1 Loop Detection | 6h | Critical | ✅ Already existed |
| 1.2 Chain of Draft | 6h | High | ✅ Done |
| 1.5 "Did You Mean?" | 4h | Medium | ✅ Done |
| 4.3 Tool Result Type Hints | 1d | Medium | ✅ Done |

**Outcome:** ✅ COMPLETE - Immediate improvement in success rates and token efficiency

### Phase B: Foundation (Week 3-5)

| Task | Effort | Impact | Blocked By |
|------|--------|--------|------------|
| 1.3 Progressive Tool Disclosure | 3d | High | - |
| 1.4 Budget/Context Signals | 2d | High | - |
| 2.1 Event Sourcing Foundation | 1w | Critical | - |
| 2.4 Failure Classification | 3d | High | - |

**Outcome:** Infrastructure for debugging, better resource management

### Phase C: Model Adaptation (Week 6-7)

| Task | Effort | Impact | Blocked By |
|------|--------|--------|------------|
| 2.3 Model-Adaptive Prompting | 1w | High | 1.3 |
| 4.1 Test Mode API | 2d | Medium | - |
| 4.2 Request Logging API | 4h | Medium | - |

**Outcome:** Full support for small/medium models

### Phase D: Strategic Features (Week 8-12)

| Task | Effort | Impact | Blocked By |
|------|--------|--------|------------|
| 2.2 Checkpoint/Rollback | 1w | High | 2.1 |
| 3.1 Time-Travel Debugging | 2w | High | 2.1, 2.2 |
| 3.2 Semantic Circuit Breaker | 1w | High | 2.4 |
| 3.3 Mixture-of-Agents | 2w | High | - |

**Outcome:** Production-grade debugging, advanced patterns

### Phase E: Privacy & Polish (Week 13+)

| Task | Effort | Impact | Blocked By |
|------|--------|--------|------------|
| 3.4 Privacy-First Architecture | 2w | Medium | - |
| 4.4 Documentation | 2w | Medium | - |

**Outcome:** Enterprise readiness, community adoption

---

## Risk Matrix

| Feature | Technical Risk | Adoption Risk | Mitigation |
|---------|---------------|---------------|------------|
| Loop Detection | Low | Low | Pattern proven elsewhere |
| Chain of Draft | Low | Medium | Opt-in, doesn't change defaults |
| Event Sourcing | Medium | Low | Incremental adoption |
| Time-Travel Debug | Medium | Low | Developer tool only |
| MoA Pattern | Medium | Medium | Research-backed |
| Privacy Architecture | High | Low | Comprehensive testing |

---

## What We're NOT Doing

Based on the analysis, these are explicitly deprioritized:

1. **Full Ractor-based Event Bus** - Current Fiber-based approach works well
2. **Automatic Model Fingerprinting** - Needs data collection infrastructure first
3. **Byzantine Fault Tolerance** - Edge case until multi-agent is mature
4. **Grammar-Constrained Decoding** - Requires model-level integration
5. **Distributed Session State** - Overkill for current use cases

---

## Success Metrics

After implementing through Phase C:

| Metric | Current | Target |
|--------|---------|--------|
| Small model (7B) success rate | ~50% | 80%+ |
| Average tokens per task | Baseline | -50% (with CoD) |
| Loop/stuck rate | Unknown | <5% |
| Time to debug failure | Hours | Minutes |
| Test coverage | 95.7% | 98%+ |

---

## Architecture Reference

### Event System (Existing - Excellent)
```ruby
emit :step_complete, step_number: 1, outcome: :success
on_tools { |e| handle(e) }
on_lifecycle { |e| track(e) }
```

### Multi-Model Patterns (Existing - Good)
```ruby
Smolagents.agent
  .model(:execution) { fast_model }
  .model(:planning) { big_model }
  .model(:evaluation) { fast_model }
  .build
```

### Future Patterns (Existing - Excellent)
```ruby
# Lazy evaluation with wave-based resolution
result = search(query: "Ruby")  # Returns ToolFuture
result["title"]                  # Triggers batch resolution
```

---

## Quick Reference

```bash
rake spec          # Run tests (~6s)
rake spec_fast     # Skip slow/integration
rake ci            # Full CI
rake commit_prep   # Fix + Stage + Verify
```

---

## Appendix: Research Sources

- `experiments/ideation/CONSOLIDATED_IDEAS.md` - 70+ ideas, risk/reward matrix
- `experiments/ideation/raw/01-08_*.md` - Raw research from 8 exploration streams
- `../agent-ruby/` - Sonnet's Flux greenfield design (12 design documents)

---

*Updated: 2026-01-26*
*Version: 2.0 (Post-Architecture Review)*
