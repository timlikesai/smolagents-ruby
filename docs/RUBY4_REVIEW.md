# Ruby 4.0 Codebase Review: Simplification Opportunities

**Date:** 2026-02-06
**Reviewer:** Claude (4 parallel deep-dive agents across all subsystems)
**Scope:** Full codebase — concerns, events, types, builders, models, tools, agents, executors, testing

---

## Executive Summary

The codebase is **well-architected** with strong patterns (Data.define everywhere, concern composition, event-driven design, immutable builders). However, there are significant opportunities to **reduce boilerplate** by leveraging Ruby 4.0 features and metaprogramming that weren't available when the code was written.

**Top 3 high-impact wins:**
1. **Type boilerplate reduction** — 80+ types repeat identical patterns (~3,500 lines recoverable)
2. **Data.define `with()` is built-in** — 20+ types manually reimplement what Ruby provides free
3. **Testing utilities bloat** — ~800 lines ship in the gem that should be dev-only

---

## 1. Data.define `with()` Is Already Built-In

**Impact:** HIGH | **Effort:** LOW | **Files:** 20+ types

Ruby's `Data.define` already provides a `with()` method that creates a copy with updated fields. We manually reimplement this in 20+ types.

**Current (repeated across types):**
```ruby
# lib/smolagents/types/retry_policy.rb:140-149
def with(**attrs)
  self.class.new(
    max_attempts: attrs.fetch(:max_attempts, max_attempts),
    base_interval: attrs.fetch(:base_interval, base_interval),
    max_interval: attrs.fetch(:max_interval, max_interval),
    backoff: attrs.fetch(:backoff, backoff),
    jitter: attrs.fetch(:jitter, jitter),
    retryable_errors: attrs.fetch(:retryable_errors, retryable_errors)
  )
end
```

**Fix:** Delete these methods entirely. `Data.define` provides `with()` natively:
```ruby
policy.with(max_attempts: 5)  # Already works without our override
```

**Files to audit:** Every type in `lib/smolagents/types/` that defines a custom `with()`.

---

## 2. Type Factory Boilerplate — PresetFactory Macro

**Impact:** HIGH | **Effort:** MEDIUM | **Files:** 50+ types | **Lines saved:** ~2,000

Nearly every config type repeats the same factory pattern:

```ruby
# lib/smolagents/types/privacy_config.rb:44-63
def self.default
  new(enabled: true, pii_types: common_types, strategy: :tokenize, ...)
end

def self.strict
  new(enabled: true, pii_types: all_types, strategy: :tokenize, ...)
end
```

**Proposed: Declarative preset DSL**
```ruby
# lib/smolagents/types/support/preset_factory.rb
module TypeSupport
  module PresetFactory
    def preset(name, **defaults)
      define_singleton_method(name) { new(**defaults) }
    end
  end
end

# Usage — replaces 10-20 lines per type:
PrivacyConfig = Data.define(:enabled, :pii_types, :strategy, ...) do
  extend TypeSupport::PresetFactory

  preset :default, enabled: true, strategy: :tokenize, ...
  preset :strict,  enabled: true, strategy: :tokenize, pii_types: ALL_TYPES, ...
end
```

**Already exists but underutilized:** `lib/smolagents/types/support/factory_builder.rb` — needs wider adoption.

---

## 3. Predicate Method Generation — Expand StatePredicates

**Impact:** HIGH | **Effort:** MEDIUM | **Files:** 50+ types | **Lines saved:** ~1,500

50+ types manually define identical `?` method patterns:

```ruby
# lib/smolagents/types/memory_config.rb:43-66
def full? = strategy == :full
def mask? = strategy == :mask
def summarize? = strategy == :summarize
def hybrid? = strategy == :hybrid
```

`TypeSupport::StatePredicates` already exists but only partially adopted:

```ruby
# What exists:
include TypeSupport::StatePredicates
state_predicates success: :success, error: :error, timeout: :timeout

# What we still hand-write in 50+ types:
def enabled? = enabled
def tokenize? = strategy == :tokenize
def active? = status == :active
```

**Action:** Audit all types with `:status` or `:strategy` fields and convert to `state_predicates`.

---

## 4. ImmutableUpdate Support Module

**Impact:** MEDIUM | **Effort:** LOW | **Files:** 20+ types | **Lines saved:** ~60

20+ types define identical `with()` using the `to_h` merge pattern:

```ruby
# Appears in setup_config.rb, result_format_config.rb, model_pool_config.rb, etc.
def with(**)
  self.class.new(**to_h, **)
end
```

**Fix:** Create shared module (or rely on Data.define's built-in `with()` — see item 1):
```ruby
module TypeSupport::ImmutableUpdate
  def with(**updates) = self.class.new(**to_h, **updates)
end
```

---

## 5. Event Mappings: Lambda Indirection -> Autoload

**Impact:** MEDIUM | **Effort:** MEDIUM | **Files:** events/mappings.rb

150+ event mappings use lambda wrappers for lazy loading:

```ruby
# lib/smolagents/events/mappings.rb:40-154
EVENTS = {
  tool_call: -> { ToolCallRequested },
  tool_complete: -> { ToolCallCompleted },
  # ... 150+ more
}
```

**Replace with Ruby's `autoload`:**
```ruby
module Events
  autoload :ToolCallRequested, "smolagents/events/tool_call_requested"
  autoload :ToolCallCompleted, "smolagents/events/tool_call_completed"

  EVENTS = {
    tool_call: :ToolCallRequested,
    tool_complete: :ToolCallCompleted,
  }

  def self.resolve(name)
    const_get(EVENTS[name])  # Autoloads on first access
  end
end
```

---

## 6. AsyncQueue.DrainSignal -> Ruby Queue

**Impact:** MEDIUM | **Effort:** LOW | **Files:** events/async_queue.rb | **Lines saved:** ~20

Hand-rolled Mutex/ConditionVariable synchronization:

```ruby
# lib/smolagents/events/async_queue.rb:20-42
class DrainSignal
  def initialize
    @mutex = Mutex.new
    @cv = ConditionVariable.new
    @done = false
  end
  # ... 20 lines of synchronization
end
```

**Replace with Ruby's Queue:**
```ruby
def drain(timeout: SHUTDOWN_TIMEOUT)
  return true unless running?

  signal = Queue.new
  push(:drain_marker) { signal.push(true) }

  begin
    signal.pop(timeout: timeout)
    true
  rescue ThreadError
    false
  end
end
```

Eliminates the DrainSignal class entirely.

---

## 7. Pattern Matching Underutilized

**Impact:** MEDIUM | **Effort:** LOW | **Files:** Multiple

### 7a. CallLog matching (testing)
```ruby
# CURRENT: lib/smolagents/testing/call_log.rb:177
def matches?(pattern)
  return match_tool?(pattern) if pattern.key?(:tool)
  return match_model?(pattern) if pattern.key?(:model)
  ...
end

# RUBY 4.0:
def matches?(pattern)
  case pattern
  in { tool: tool_sym, args: expected_args }
    tool_call? && match_value?(name, tool_sym) &&
      expected_args.all? { |k, v| match_value?(args[k], v) }
  in { tool: tool_sym }
    tool_call? && match_value?(name, tool_sym)
  in { model: model_sym }
    model_call? && match_value?(name, model_sym)
  else
    pattern.all? { |k, v| match_value?(send(k), v) }
  end
end
```

### 7b. Transform utility
```ruby
# CURRENT: lib/smolagents/utilities/transform.rb:84-91
case obj
when *PRIMITIVES then obj
when Array then obj.map { |item| freeze(item) }.freeze
when Hash then obj.transform_values { |val| freeze(val) }.freeze
when String then obj.frozen? ? obj : obj.dup.freeze
else safe_freeze(obj)
end

# Could use case/in for String guard clause
```

### 7c. Data.define deconstruct_keys
Types already include `TypeSupport::Deconstructable` — document pattern matching usage:
```ruby
case health_check(model)
in HealthStatus[status: :healthy, latency_ms: ..500]
  "Fast and healthy"
in HealthStatus[status: :degraded]
  "Slow but working"
in HealthStatus[status: :unhealthy, error:]
  handle_error(error)
end
```

---

## 8. Inconsistent Block Parameters

**Impact:** LOW | **Effort:** LOW | **Files:** Multiple

Mix of `_2` (numbered params), `it` (new), and named params:

```ruby
# lib/smolagents/concerns/registry_dependencies.rb:32-36
def standalone = @concerns.select { _2.dependencies.empty? }.keys  # _2
def dependent = @concerns.reject { _2.dependencies.empty? }.keys   # _2

# Same file, line 51:
unregistered = info.dependencies.reject { @concerns.key?(it) }      # it
```

**Fix:** Standardize on `it` for single-parameter blocks (Ruby 4.0 idiom).

Note: `_2` is needed for multi-param blocks (hash iteration gives key, value), but here `.select` on a hash gives `[key, value]` pairs — the `_2` usage is correct for accessing the value. However, using `.values.select { it.dependencies.empty? }` would be clearer.

---

## 9. Builder Concerns: 14 Mixins -> 5 Logical Groups

**Impact:** MEDIUM | **Effort:** MEDIUM | **Files:** builders/agent_builder.rb

```ruby
# CURRENT: 14 separate includes
include Base, EventHandlers, ModelConcern, AgentToolsConcern,
        AgentSettersConcern, AgentBuildConcern, ManagedAgentsConcern,
        ExecutionConcern, InlineToolConcern, MemoryConcern,
        PlanningConcern, RefineConcern, SpawnConcern,
        SpecializationConcern, ToolResolution, OrchestrationConcern,
        AgentCheckpointConcern, AgentPrivacyConcern

# PROPOSED: 5 logical bundles
include AgentBuilder::Core        # Model, Tools, Setters, Build
include AgentBuilder::Execution   # Execution, Memory, Planning
include AgentBuilder::Advanced    # Refine, Spawn, ManagedAgents
include AgentBuilder::Security    # Privacy, Checkpoint
include AgentBuilder::Orchestration
```

---

## 10. Centralize Builder Validators

**Impact:** MEDIUM | **Effort:** LOW | **Files:** 3 builders

Validation lambdas are duplicated across builders:

```ruby
# agent_builder.rb:82
validates: ->(v) { v.is_a?(Integer) && v.positive? && v <= Config::MAX_STEPS_LIMIT }

# model_builder.rb:120
validates: ->(v) { v.is_a?(Integer) && v.positive? && v <= 100_000 }
```

**Fix:** Central validator registry:
```ruby
module Validators
  POSITIVE_INTEGER = ->(v) { v.is_a?(Integer) && v.positive? }
  MAX_STEPS = ->(v) { POSITIVE_INTEGER.call(v) && v <= Config::MAX_STEPS_LIMIT }
  MAX_TOKENS = ->(v) { POSITIVE_INTEGER.call(v) && v <= 100_000 }
  TEMPERATURE = ->(v) { v.is_a?(Numeric) && v.between?(0.0, 2.0) }
end

# Usage:
register_method :max_steps, validates: Validators::MAX_STEPS
register_method :temperature, validates: Validators::TEMPERATURE
```

---

## 11. Testing: Ship vs. Dev-Only Separation (Phase G.3)

**Impact:** HIGH | **Effort:** MEDIUM | **Lines saved from gem:** ~800

### Keep in shipped gem (~1,200 lines):
- MockModel + queue/query modules
- CallLog + support
- Basic helpers (model, tool, spy)
- Call log matchers
- TestMode API
- FailureMarker

### Move to dev-only (~800 lines):
| File | Lines | Reason |
|------|-------|--------|
| `scenarios.rb` | 188 | Pre-built test patterns |
| `auto_stub.rb` | 111 | Auto-generation |
| `auto_gen.rb` | 95 | Code generation |
| `behavior_tracer.rb` | 106 | Debugging |
| `model_benchmark/` | ~350 | Benchmarking suite |
| `requirement_builder/` | ~150 | Requirements testing |
| `result_store/` | ~120 | Result persistence |
| `comparison_table.rb` | 66 | Reporting |
| `validators.rb` | 100 | Internal validation |
| `test_runner.rb` | 98 | Test infrastructure |

### ~~Duplicate shared examples~~ (CORRECTED)
`lib/smolagents/testing/shared_examples.rb` (3 public API examples: agent, tool, model) and
`spec/support/shared_examples/type_behavior.rb` (11 internal type examples) are **not duplicates**.
They serve different purposes and both should be kept.

---

## 12. Dispatch Method Consolidation

**Impact:** LOW | **Effort:** LOW | **Files:** events/emitter.rb

Two nearly identical methods:

```ruby
# lib/smolagents/events/emitter.rb:146-162
def dispatch_event(event)       # async
def dispatch_event_sync(event)  # sync
```

**Merge:**
```ruby
def dispatch_event(event, sync: false)
  if @event_queue
    @event_queue.push(event)
  elsif respond_to?(:consume) && @event_handlers&.any?
    sync ? consume(event) : AsyncQueue.push(event) { consume(_1) }
  end
  event
end
```

---

## 13. BaseConcern `define_composite` Complexity

**Impact:** LOW | **Effort:** MEDIUM | **Files:** concerns/base_concern.rb

Uses `define_singleton_method` to create `included` hooks:

```ruby
def self.define_composite(primary_module, *sub_modules, class_methods: nil, ...)
  define_included_hook(primary_module, sub_modules, class_methods, ...)
  define_extended_hook(primary_module, sub_modules, ...) if support_extend
end
```

Most cases could just use explicit `include` in the module definition — simpler and more debuggable:

```ruby
module MyModule
  include SubA
  include SubB
end
```

---

## Summary: Priority Matrix

### Phase G Integration (Simplification)

| # | Item | Lines Saved | Effort | Phase |
|---|------|-------------|--------|-------|
| 1 | Delete manual `with()` overrides | ~200 | 2h | G.4 |
| 2 | PresetFactory macro for type factories | ~2,000 | 1d | G.4 |
| 3 | Expand StatePredicates adoption | ~1,500 | 1d | G.4 |
| 4 | ImmutableUpdate module | ~60 | 30m | G.4 |
| 5 | Event mappings -> autoload | ~50 | 4h | G.1 |
| 6 | DrainSignal -> Queue | ~20 | 30m | G.1 |
| 7 | Pattern matching adoption | ~40 | 2h | G.4 |
| 8 | Standardize `it` parameter | ~0 | 1h | G.4 |
| 9 | Bundle builder concerns | ~0 (clarity) | 4h | G.4 |
| 10 | Centralize validators | ~30 | 2h | G.4 |
| 11 | Testing dev/ship separation | ~800 | 1d | G.3 |
| 12 | Dispatch method merge | ~15 | 30m | G.1 |
| 13 | Simplify BaseConcern | ~30 | 4h | G.4 |

**Total recoverable lines: ~4,745**
**Current gem: ~16k lines -> Target: ~11-12k lines**

### Quick Wins (do first, < 1 day total)

1. Delete manual `with()` overrides (item 1)
2. ImmutableUpdate module (item 4)
3. DrainSignal -> Queue (item 6)
4. Dispatch method merge (item 12)
5. Standardize `it` parameter (item 8)

### High-Value Refactors (1-2 days each)

6. PresetFactory macro (item 2)
7. StatePredicates expansion (item 3)
8. Testing separation (item 11)

### Nice-to-Haves (integrate during other work)

9. Pattern matching adoption (item 7)
10. Builder concern bundling (item 9)
11. Event mappings autoload (item 5)
12. Validator centralization (item 10)
13. BaseConcern simplification (item 13)

---

## What's Already Excellent

- **No `require "set"` or `require "pathname"`** — Already Ruby 4.0 compliant
- **No `frozen_string_literal: true` comments** — Clean
- **Data.define used everywhere** — 80+ types, all immutable
- **Endless methods used consistently** — `def name = @name`
- **Set used as core class** — No legacy requires
- **Hash shorthand used** — `{name:, age:}` style
- **Event-driven architecture** — No instrumentation wrappers
- **MockModel design** — Thread-safe, FIFO, excellent error messages
- **Builder DSL** — Immutable, fluent, well-tested

The codebase follows modern Ruby 4.0 idioms in most places. The main opportunities are DRYing up repeated patterns across 80+ types and cleaning up testing utilities for gem packaging.
