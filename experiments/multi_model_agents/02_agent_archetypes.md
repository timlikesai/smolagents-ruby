# Agent Archetypes: Sophisticated Patterns

## Archetype 1: Tiered Reasoning Agent

**Concept:** Use fast small models for quick decisions, escalate to larger models for complex reasoning.

```
User Task
    ↓
┌─────────────────┐
│  Fast Triage    │  ← gpt-oss-20b on llama_ultra (very fast)
│  (Classify)     │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
 Simple   Complex
    ↓         ↓
┌─────────┐ ┌─────────┐
│ Fast    │ │ Big     │  ← gpt-oss-120b on macbook_pro
│ Execute │ │ Reason  │
└─────────┘ └─────────┘
```

**Key Events:**
- `model_generate_requested` → track which model handles what
- `step_complete` → measure complexity at each step
- `failover` → when big model falls back to smaller

**DSL Expression:**
```ruby
# Multi-model agent with routing
Smolagents.agent
  .model(:triage) { fast_20b }     # Quick classification
  .model(:execution) { fast_20b }  # Simple task execution
  .model(:reasoning) { big_120b }  # Complex reasoning
  .tools(:search, :calculate, :analyze)
  .as(:tiered_reasoner)
  .build
```

**Gap:** Currently can only specify `:execution`, `:planning`, `:evaluation`, `:summarization`, `:code_review`. Need custom model purposes or dynamic routing.

---

## Archetype 2: Research Swarm

**Concept:** Parallel research agents, each with different search strategies, results aggregated by a synthesizer.

```
                    User Query
                        ↓
              ┌─────────────────┐
              │   Coordinator   │  ← Fast model for orchestration
              └────────┬────────┘
                       │
       ┌───────────────┼───────────────┐
       ↓               ↓               ↓
┌────────────┐  ┌────────────┐  ┌────────────┐
│ Researcher │  │ Researcher │  │ Researcher │
│  (Broad)   │  │  (Deep)    │  │ (Academic) │
└─────┬──────┘  └─────┬──────┘  └─────┬──────┘
      │               │               │
      └───────────────┼───────────────┘
                      ↓
              ┌─────────────────┐
              │   Synthesizer   │  ← Big model for synthesis
              └─────────────────┘
```

**Key Events:**
- `agent_launch` → track swarm expansion
- `agent_complete` → collect results
- `agent_progress` → monitor parallel progress

**DSL Expression:**
```ruby
broad_researcher = Smolagents.agent
  .model { fast_20b }
  .tools(:web_search)
  .instructions("Search broadly, find diverse sources")
  .build

deep_researcher = Smolagents.agent
  .model { fast_20b }
  .tools(:web_search, :scrape)
  .instructions("Go deep on primary sources")
  .build

academic_researcher = Smolagents.agent
  .model { fast_20b }
  .tools(:arxiv_search, :scholar_search)
  .instructions("Find academic papers and citations")
  .build

swarm = Smolagents.team
  .model { fast_20b }  # Coordinator
  .agent(broad_researcher, as: "broad")
  .agent(deep_researcher, as: "deep")
  .agent(academic_researcher, as: "academic")
  .coordinate("Run all researchers in parallel, then synthesize")
  .build
```

**Gap:** TeamBuilder doesn't express parallel vs sequential execution. `.coordinate()` is just instructions, not control flow.

---

## Archetype 3: Visual Analysis Pipeline

**Concept:** Image input → vision model analysis → reasoning model interpretation.

```
Image Input
     ↓
┌─────────────┐
│ Vision Model│  ← MedGemma or similar
│ (Extract)   │
└─────┬───────┘
      │ Structured description
      ↓
┌─────────────┐
│ Reasoning   │  ← gpt-oss-120b
│ (Interpret) │
└─────────────┘
```

**Key Events:**
- `tool_complete` → image processing done
- `model_generate_completed` → track model-specific latency

**DSL Expression:**
```ruby
Smolagents.agent
  .model(:vision) { vision_model }      # Image processing
  .model(:execution) { reasoning_model } # Interpretation
  .tool(:analyze_image, "Extract info from image", image_path: String) do |image_path:|
    # Calls vision model internally
    vision_response = @models[:vision].generate([
      { role: "user", content: [
        { type: "image_url", image_url: { url: image_path } },
        { type: "text", text: "Describe this image in detail" }
      ]}
    ])
    vision_response.content
  end
  .build
```

**Gap:** No built-in image/multimodal tool support. Tools can't easily access agent's model pool.

---

## Archetype 4: Self-Improving Agent with Reflection

**Concept:** Agent that learns from failures, refines approaches, and maintains a knowledge base.

```
Task
  ↓
┌─────────────┐
│   Execute   │ ←─────────────────────┐
└─────┬───────┘                       │
      │                               │
   Success?  ──No──→ ┌────────────┐   │
      │              │  Reflect   │   │
     Yes             │  (Why fail)│   │
      │              └─────┬──────┘   │
      ↓                    │          │
┌─────────────┐      ┌─────┴──────┐   │
│   Record    │      │  Adjust    │───┘
│  (Success)  │      │  Strategy  │
└─────────────┘      └────────────┘
```

**Key Events:**
- `reflection_recorded` → capture learnings
- `refinement_complete` → track iterations
- `evaluation_complete` → assess quality

**DSL Expression:**
```ruby
Smolagents.agent
  .model(:execution) { fast_20b }
  .model(:evaluation) { big_120b }  # Deeper reflection
  .tools(:search, :calculate)
  .refine(max_iterations: 3, threshold: 0.8)
  .evaluation(enabled: true)
  .on(:reflection_recorded) { |e| knowledge_base.store(e.reflection) }
  .on(:refinement_complete) { |e| metrics.track_improvement(e.iterations, e.improved) }
  .build
```

**This pattern is well-supported by current DSL!**

---

## Archetype 5: Consensus Agent

**Concept:** Multiple models vote on decisions, consensus required for high-stakes actions.

```
Decision Point
      ↓
┌─────┬─────┬─────┐
│ M1  │ M2  │ M3  │  ← Different models/servers
└──┬──┴──┬──┴──┬──┘
   │     │     │
   └─────┼─────┘
         ↓
   ┌───────────┐
   │ Consensus │  If 2/3 agree → proceed
   │  Check    │  Else → human review
   └───────────┘
```

**Key Events:**
- `control_yielded` → pause for human review
- `control_resumed` → human decision received

**DSL Expression:**
```ruby
# Build three parallel evaluators
evaluators = [fast_20b_server1, fast_20b_server2, fast_20b_server3].map do |model|
  Smolagents.agent.model { model }.as(:evaluator).build
end

# Custom tool for consensus checking
consensus_tool = Smolagents.inline_tool(:check_consensus, "Get consensus on a decision") do |decision:|
  results = evaluators.map { |e| e.run("Evaluate: #{decision}. Respond APPROVE or REJECT with reason.") }
  approvals = results.count { |r| r.include?("APPROVE") }

  if approvals >= 2
    "CONSENSUS REACHED: #{approvals}/3 approved"
  else
    emit(Events::ControlYielded.new(
      request_type: :confirmation,
      request_id: SecureRandom.uuid,
      prompt: "No consensus (#{approvals}/3). Approve anyway?"
    ))
  end
end
```

**Gap:** No built-in voting/consensus mechanism. Would need to be custom-built with tools.

---

## Archetype 6: Cost-Aware Router

**Concept:** Route simple queries to cheap/fast models, complex queries to expensive models.

```
Query
  ↓
┌─────────────┐
│ Complexity  │  ← Tiny model or heuristic
│ Estimator   │
└─────┬───────┘
      │
   ┌──┴──┐
 Low    High
   ↓      ↓
┌─────┐ ┌─────┐
│Fast │ │Big  │
│Free │ │Paid │
└─────┘ └─────┘
```

**Key Events:**
- `model_generate_completed.token_usage` → track costs
- Custom event for routing decisions

**DSL Expression:**
```ruby
# Cost tracking wrapper
class CostTracker
  def initialize
    @costs = Hash.new(0.0)
  end

  def track(event)
    cost = calculate_cost(event.model_id, event.token_usage)
    @costs[event.model_id] += cost
  end
end

tracker = CostTracker.new

agent = Smolagents.agent
  .model(:execution) { fast_free_model }
  .model(:reasoning) { big_paid_model }
  .on(:model_generate_completed) { |e| tracker.track(e) }
  .build
```

**Gap:** No built-in cost tracking or budget limits. Token usage is tracked but not costs.

---

## Summary: Pattern Support Matrix

| Pattern | DSL Support | Gaps |
|---------|-------------|------|
| Tiered Reasoning | Partial | Custom model purposes, dynamic routing |
| Research Swarm | Good | Parallel execution control |
| Visual Pipeline | Partial | Multimodal tools, model pool access |
| Self-Improving | Good | Well-supported |
| Consensus | Partial | Voting mechanism, parallel execution |
| Cost-Aware | Partial | Cost tracking, budget limits |
