# smolagents-ruby

Highly-testable agents that think in Ruby.

---

## Current Status

| Metric | Value |
|--------|-------|
| RSpec Tests | 5655 (0 failures, 26 pending) |
| Line Coverage | 92.25% |
| RuboCop Offenses | 0 |
| YARD Doctests | 46 runs, 42 assertions, 0 failures |
| Model Compliance | 3 models passing L0-L8 at 98%+ |

---

## Current DSL

```ruby
.model { }                    # WHAT thinks (required)
.tools(...)                   # WHAT it uses (optional)
.tool(:name, "desc") { }      # Inline tool definition
.as(:persona)                 # HOW it behaves (optional)
.memory(budget:, strategy:)   # Context management
.planning                     # Pre-Act planning (70% improvement)
.can_spawn(allow: [...])      # Enable sub-agent spawning
.refine(max_iterations:)      # Self-refine loop (20% improvement)
.evaluate(on: :each_step)     # Progress evaluation
```

---

## Completed Phases

| Phase | Focus | Tests Added |
|-------|-------|-------------|
| 1-5 | Foundation, ReActLoop, Concerns | 323 |
| 6-8 | Model Testing Framework | 5000+ |
| 9 | Architectural Alignment | 332 |

**Total: 55 agents across 9 phases, 5655 tests passing**

---

## Phase 10: Production Readiness

Operational necessities. Make it "just work" reliably.

### 10A. Non-Blocking Auto-Discovery

`Discovery::Scanner` blocks IRB when ports are closed.

| Task | Files |
|------|-------|
| Parallel threads for network checks | `discovery/scanner.rb` |
| Instant return with async results | |

### 10B. Async Event Emission

Slow event handlers block the reasoning loop.

| Task | Files |
|------|-------|
| Background queue for event dispatch | `events/consumer.rb` |

### 10C. Ractor-Safe Variables

Variables passed to Ractor executor may not be shareable.

| Task | Files |
|------|-------|
| `Ractor.make_shareable` on variables | `executors/ractor.rb` |

### 10D. SSRF Protection (Pinned DNS)

DNS rebinding can bypass IP checks.

| Task | Files |
|------|-------|
| Connect to validated IP, set Host header | `http/ssrf_protection.rb` |

### 10E. Tool Output Segregation

Tool outputs may contain prompt injection.

| Task | Files |
|------|-------|
| Wrap outputs in delimiters | `concerns/agents/react_loop/core.rb` |

### 10F. Sandbox Memory Limits

Large allocations can crash host.

| Task | Files |
|------|-------|
| RSS limit or DockerExecutor docs | `executors/local_ruby.rb` |

---

## Phase 11: Dynamic Tooling

Ruby's metaprogramming edge. Research-backed differentiator.

**Research:** ToolMaker (arXiv:2502.11705) - LLMs create executable tools. TOOLFLOW (ACL 2025) - dynamic tool routing outperforms static registries.

### 11A. JIT Tool Creation

Agents write and use tools at runtime.

```ruby
# Agent creates tool on the fly
tool = create_tool(
  name: "parse_xml",
  code: "def execute(xml) Nokogiri::XML(xml).to_h end"
)
result = parse_xml(data)
```

### 11B. Security Constraints

| Constraint | Implementation |
|------------|----------------|
| Anonymous Modules | `Module.new { ... }` - disposable |
| CodeValidator | Same checks as agent code |
| No IO | Pure data transformations |
| Optional approval | `.jit_tools(approval: :required)` |

### 11C. Tool Introspection

```ruby
available_tools  # => [:search, :parse_xml]
tool_schema(:search)  # => { inputs: {...}, output_type: "array" }
```

---

## Phase 12: Agent Autonomy

Enable agents to manage sub-tasks and recover from failures.

### 12A. `spawn` and `delegate`

Natural extension of existing `.can_spawn()` DSL.

```ruby
# Inside sandbox - spawn waits for result
child = spawn(task: "Research X", tools: [:search])
use(child.output)

# Inside sandbox - delegate is fire-and-forget
answer = delegate(to: :researcher, task: "Find Ruby version")
```

### 12B. Checkpointing

**Research:** STRATUS (NeurIPS 2025) - 150% improvement with undo-retry.

```ruby
agent.checkpoint do |safe|
  safe.run("Try risky operation")
end  # Rolls back memory if block fails
```

### 12C. Context Folding

**Research:** Agent-controlled memory (arXiv:2601.01885).

Extend existing `.memory()` DSL:

```ruby
.memory(strategy: :folding, keep: [:variables])
```

Auto-summarize history while preserving active variables.

---

## Backlog

Items moved here lack strong research backing or add complexity without proven value.

| Item | Reason Deferred |
|------|-----------------|
| StateSnapshot (variable HUD) | Adds overhead to every step, no research |
| PlanCompass (goal pinning) | Complex context manipulation |
| TypeInterface (RBS for tools) | Over-abstraction before need |
| Feedback Loop Primitive | Vague abstraction, unclear use case |
| AgentFactoryTool | `spawn` covers the use case |
| Debate Pattern | Only 3% improvement (47% vs 44% EM) |
| Consensus Strategies | Multiple strategies before proving one |
| Adaptive Routing | No research backing |
| Agent Modes | Vague - unclear DSL surface |
| Constrained Output | Depends on model support |
| Circuit Breaker | Low priority |
| Security-Aware Routing | Low priority |
| Memory Persistence | Low priority |
| GraphRAG | Complex, low priority |

---

## Research References

| Topic | Source | Finding |
|-------|--------|---------|
| Pre-Act Planning | arXiv:2505.09970 | 70% improvement |
| Self-Refine | arXiv:2303.17651 | 20% improvement |
| STRATUS | NeurIPS 2025 | **150% improvement** |
| ToolMaker | arXiv:2502.11705 | LLMs create tools |
| TOOLFLOW | ACL 2025 | Dynamic > static tools |
| Agent Memory | arXiv:2601.01885 | Agent-controlled memory |
| Self-Correction | ICLR 2024 | SLMs need external feedback |
| Reflexion | arXiv:2303.11366 | 91% HumanEval |

---

## Principles

- **Simple by Default** - One line for common cases
- **Ruby 4.0 Idioms** - Data.define, pattern matching, blocks
- **Ship It** - Working software over architecture
- **100/10 Rule** - Modules ≤100 lines, methods ≤10 lines
- **Test Everything** - MockModel, fast tests
- **Forward Only** - No backwards compatibility
