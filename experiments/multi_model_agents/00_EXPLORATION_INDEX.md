# Multi-Model Agent Exploration Index

## Infrastructure Context

Three machines with different capabilities:

| Machine | Endpoint | Characteristics | Models |
|---------|----------|-----------------|--------|
| Mac Studio | `http://mac-studio.reverse-bull.ts.net:1234/v1` | Lots of models | gpt-oss-20b (fairly fast) |
| MacBook Pro M4 | `http://macbook-pro-m4.reverse-bull.ts.net:1234/v1` | Lots of RAM | gpt-oss-20b (very fast), gpt-oss-120b (fairly fast) |
| LLaMA CPP Ultra | `https://llama-cpp-ultra.reverse-bull.ts.net/v1` | Constrained VRAM, fast GPUs | gpt-oss-20b (very fast) |

Additional utility models: LFM 2.5 1.2b, MedGemma (vision), various medium-sized models.

## Experiments

| File | Description | Tests | Status |
|------|-------------|-------|--------|
| [01_infrastructure_design.md](01_infrastructure_design.md) | Model infrastructure abstraction design | N/A | Design |
| [02_agent_archetypes.md](02_agent_archetypes.md) | Sophisticated agent patterns catalog | N/A | Design |
| [03_failure_modes.md](03_failure_modes.md) | Failure analysis and mitigations | N/A | Design |
| [04_tiered_reasoning.rb](04_tiered_reasoning.rb) | Fast/big model tiering | 14 | Complete |
| [05_research_swarm.rb](05_research_swarm.rb) | Parallel research agents | 18 | Complete |
| [06_visual_analysis_pipeline.rb](06_visual_analysis_pipeline.rb) | Vision + reasoning pipeline | 18 | Complete |
| [07_self_improving_agent.rb](07_self_improving_agent.rb) | Meta-learning with reflection | 18 | Complete |
| [08_gap_analysis.md](08_gap_analysis.md) | System gaps identified | N/A | Analysis |
| [09_distributed_analyst.rb](09_distributed_analyst.rb) | Full distributed system | 16 | Complete |

**Total: 84 passing tests**

## Key Findings

### What Works Well

1. **Multi-model DSL** - `.model(:execution) { }` / `.model(:planning) { }` is expressive
2. **Resilience patterns** - Fallbacks, retries, circuit breakers compose naturally
3. **Event system** - 40+ events provide excellent observability
4. **Inline tools** - Quick tool definition without boilerplate
5. **Team coordination** - Sub-agents as tools works cleanly
6. **Testing infrastructure** - MockModel enables fast deterministic tests

### Gaps Identified (Priority Order)

1. **G1.1** `base_url()` method needed for remote servers
2. **G1.2** MockModel failure injection for testing error paths
3. **G1.3** Event sequence numbers for async reconstruction
4. **G2.1** Parallel execution control in TeamBuilder
5. **G2.2** Custom model purposes beyond built-in types
6. **G2.3** Health check with model verification
7. **G2.4** Tool access to agent's model pool

See [08_gap_analysis.md](08_gap_analysis.md) for full details.

### Testing Patterns Established

```ruby
# Create test setup with mocks
result = Experiment.build_for_testing(
  model_responses: ["<code>\nfinal_answer(answer: \"test\")\n</code>"]
)

# Run and verify
run_result = result[:agent].run("query")
expect(run_result.output).to eq("test")

# Inspect mock calls
expect(result[:models][:execution].call_count).to eq(1)
```

## Architecture Patterns

### Tiered Reasoning
```
Query → [Fast Triage] → Simple? → [Fast Model]
                      → Complex? → [Big Model]
```

### Research Swarm
```
Query → [Coordinator] → [Broad, Deep, Academic] (parallel) → [Synthesizer]
```

### Visual Pipeline
```
Image → [Vision Model] → Description → [Reasoning Model] → Analysis
```

### Self-Improving
```
Task → Execute → Evaluate → Reflect → Store Learning → Apply to Future
```

### Distributed Analyst (Combined)
```
Query → [Triage] → [Simple|Research|Analysis|Visual] → [Synthesizer]
```

## Running the Experiments

```bash
# Run all experiment tests
bundle exec rspec spec/experiments/multi_model_agents/

# Run specific experiment
bundle exec rspec spec/experiments/multi_model_agents/04_tiered_reasoning_spec.rb

# Run individual example (with real models)
ruby experiments/multi_model_agents/04_tiered_reasoning.rb
```

## Next Steps

1. Implement G1.x gaps (quick wins)
2. Add integration tests with real model servers
3. Build monitoring dashboard using event streams
4. Create CLI for running experiments interactively
