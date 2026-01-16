# Agent Orchestration Research Synthesis

Research conducted 2026-01-15 using ArXiv and our agent research harness.

## Attribution

Papers cited in this document should be referenced in code comments where their
patterns are implemented. Use format: `@see http://arxiv.org/abs/XXXX.XXXXX`

## Key Papers and Patterns

### 1. Hierarchical Multi-Agent Orchestration

**Project Synapse: Hierarchical Multi-Agent Framework**
- **Citation**: Yadav, Dherange & Shivam (2026). http://arxiv.org/abs/2601.08156v1
- **Pattern**: Resolution Supervisor agent performs strategic task decomposition
- **Delegation**: Supervisor delegates subtasks to specialized worker agents
- **Orchestration**: Uses LangGraph for complex/cyclical workflows
- **Implication**: We need a supervisor mode that can decompose tasks and delegate

**Dynamic Task Delegation for Hierarchical Agents**
- **Citation**: Libkind & Spivak (2024). http://arxiv.org/abs/2410.08373v2
- **Mathematical model**: Polynomial functors for hierarchical delegation
- **Key insight**: Agent interfaces compose via tensor product
- **Implication**: Agent interfaces should be composable and type-safe

### 2. Internal State and Metacognition

**Truly Self-Improving Agents Require Intrinsic Metacognitive Learning**
- **Citation**: Liu & van der Schaar (2025). http://arxiv.org/abs/2506.05109v1
- **Core claim**: Effective self-improvement requires intrinsic metacognitive learning
- **Definition**: Agent's intrinsic ability to evaluate, reflect on, and adapt learning
- **Three capabilities**: Self-evaluation, self-reflection, self-adaptation
- **Implication**: Agents need internal modes for evaluation and reflection

**Decomposing LLM Self-Correction: The Accuracy-Correction Paradox**
- **Citation**: Li (2025). http://arxiv.org/abs/2601.00828v1
- **Decomposition**: Self-correction = error detection + error localization + error correction
- **Finding**: Intrinsic self-correction (without external feedback) largely ineffective
- **Implication**: Need structured error handling, not just "try again"

**RetrySQL: Training with Retry Data for Self-Correcting Generation**
- **Citation**: Rączkowska et al. (2025). http://arxiv.org/abs/2507.02529v2
- **Pattern**: Training with retry data for self-correcting query generation
- **Key insight**: Learning from failure trajectories improves correction ability
- **Implication**: Retry mechanisms should feed back into agent learning

### 3. Goal Tracking and Planning

**Goal-oriented Prompt Engineering**
- **Citation**: Li, Leung & Shen (2024). http://arxiv.org/abs/2401.14043
- **Key insight**: Goal-oriented formulation > anthropomorphic prompting
- **Pattern**: Guide LLMs toward goals rather than expecting human-like reasoning
- **Five-stage framework**: Decompose → action selection → execute → evaluate → select valuable sub-goals
- **Implication**: Goals should be explicit in agent state, not implicit

**CATP-LLM: Cost-Aware Tool Planning**
- **Citation**: Wu et al. (2024). http://arxiv.org/abs/2411.16313
- **Problem**: Tool planning should consider execution costs (latency, API costs)
- **Pattern**: Cost-aware offline reinforcement learning for tool planning
- **Tool Planning Language (TPL)**: Multi-branch non-sequential plans for concurrent execution
- **Result**: 28-30% higher plan performance, 25-46% lower costs than GPT-4
- **Implication**: Tool selection should factor in reliability, latency, cost

**AgentReuse: Plan Reuse Mechanism**
- **Citation**: Li (2025). http://arxiv.org/abs/2512.21309
- **Problem**: LLM plan generation latency reaches 25+ seconds for complex tasks
- **Pattern**: Intent classification to evaluate request similarity, reuse cached plans
- **Result**: 93% effective plan reuse, 93% latency reduction
- **Implication**: Plan caching could accelerate repeated tasks

### 4. Agent Architecture Patterns

**KG-Agent: Autonomous Agent for Knowledge Graph Reasoning**
- **Citation**: Jiang et al. (2024). http://arxiv.org/abs/2402.11163
- **Components**: LLM + multifunctional toolbox + KG-based executor + knowledge memory
- **Pattern**: Autonomous agent that actively makes decisions until finished
- **Result**: 10K samples tuning LLaMA-7B outperforms state-of-the-art with larger LLMs
- **Implication**: Clear separation of LLM, tools, executor, and memory

**LLM-based Autonomous Agents Survey**
- **Citation**: Wang et al. (2023, updated 2025). http://arxiv.org/abs/2308.11432
- **Framework**: Unified framework covering majority of LLM-based autonomous agents
- **Evolution**: Rule-based → modern LLM + perception + planning + tools
- **Evaluation**: Current benchmarks insufficient; need holistic framework
- **Implication**: We need robust evaluation patterns

**Cognitive Architectures for Language Agents (CoALA)**
- **Citation**: Sumers et al. (2023). http://arxiv.org/abs/2309.02427
- **Framework**: Draws from cognitive science and symbolic AI
- **Memory model**: Working memory + long-term (episodic, semantic, procedural)
- **Action space**: External (grounding) + Internal (reasoning, retrieval, learning)
- **Key insight**: LLMs function as probabilistic production systems
- **Implication**: Organize agents around cognitive primitives

---

## DSL Design Implications

Based on research, our DSL should support:

### 1. Agent Modes (Internal State)
```ruby
# Research pattern: Self-evaluation, reflection, adaptation modes
Smolagents.agent
  .mode(:reasoning)      # Internal reasoning before action
  .mode(:evaluation)     # Evaluate own output quality
  .mode(:correction)     # Self-correction with structured error handling
  .build
```

### 2. Goal Tracking
```ruby
# Research pattern: Explicit goal state, not implicit
Smolagents.agent
  .goal("Find the street address of NYT headquarters")
  .subgoals { |g|
    g.add("Identify relevant search terms")
    g.add("Execute searches")
    g.add("Extract address from results")
  }
  .on(:goal_complete) { |e| ... }
  .build
```

### 3. Hierarchical Delegation
```ruby
# Research pattern: Supervisor delegates to specialized workers
Smolagents.team
  .supervisor { |s|
    s.strategy(:decompose_and_delegate)
    s.workers(:researcher, :verifier, :synthesizer)
  }
  .on(:task_delegated) { |e| ... }
  .on(:result_aggregated) { |e| ... }
  .build
```

### 4. Retry-then-Verify Pattern
```ruby
# Research pattern: Structured error handling, not just retry
Smolagents.agent
  .on_error(:tool_failure) { |e|
    e.detect   # What failed?
    e.localize # Where specifically?
    e.correct  # How to fix?
  }
  .verify_strategy(:cross_reference)
  .build
```

### 5. Cost-Aware Tool Selection
```ruby
# Research pattern: Factor in reliability, latency, cost
Smolagents.agent
  .tool_selection(:cost_aware) {
    prefer :wikipedia, when: { type: :encyclopedic }
    prefer :brave_search, when: { type: :current_events }
    fallback :web_search
  }
  .build
```

---

## Implementation Priorities

Based on research findings:

| Priority | Feature | Research Basis | Effort |
|----------|---------|----------------|--------|
| **P1** | Agent Modes (reasoning, evaluation) | Metacognition papers | MEDIUM |
| **P1** | Goal State Tracking | Goal-oriented prompt paper | MEDIUM |
| **P2** | Structured Error Handling | Self-correction decomposition | MEDIUM |
| **P2** | Hierarchical Delegation | Project Synapse, Dynamic Delegation | HIGH |
| **P3** | Cost-Aware Tool Selection | CATP-LLM | LOW |
| **P3** | Plan Caching | Plan Reuse paper | LOW |

---

## 2025 Research Update (Latest Findings)

### 5. Multi-Agent Orchestration Frameworks (2025)

**Multi-Agent LLM Orchestration for Incident Response**
- **Citation**: Drammeh (2025). http://arxiv.org/abs/2511.15755
- **Finding**: Multi-agent orchestration achieves 100% actionable recommendations vs 1.7% single-agent
- **Result**: 80x improvement in action specificity, 140x in solution correctness
- **Implication**: Orchestration fundamentally transforms quality, not just efficiency

**Difficulty-Aware Agentic Orchestration (DAAO)**
- **Citation**: http://arxiv.org/abs/2509.11079
- **Pattern**: Dynamically generate query-specific workflows based on predicted difficulty
- **Components**: VAE for difficulty estimation, modular operator allocator, cost-aware LLM router
- **Result**: SOTA with 11.21% accuracy improvement at 64% inference cost
- **Implication**: Adapt workflow complexity to query difficulty

**Multi-Agent Collaboration via Evolving Orchestration**
- **Citation**: http://arxiv.org/abs/2505.19591
- **Pattern**: Puppeteer-style paradigm with centralized orchestrator directing agents
- **Training**: RL to adaptively sequence and prioritize agents
- **Finding**: Improvements stem from compact, cyclic reasoning structures
- **Implication**: Orchestrator should be trainable/adaptive

**Orchestral AI Framework**
- **Citation**: http://arxiv.org/abs/2601.02577
- **Pattern**: Unified, type-safe interface for building LLM agents across providers
- **Features**: Tool calling, context compaction, workspace sandboxing, user approval workflows, sub-agents, memory, MCP
- **Implication**: Reference architecture for production agent systems

### 6. Agent Communication Protocols (2025)

**Survey of AI Agent Protocols**
- **Citation**: http://arxiv.org/abs/2504.16736
- **Problem**: No standard for agent-to-agent or agent-to-tool communication
- **Taxonomy**: Context-oriented vs inter-agent, general-purpose vs domain-specific
- **Implication**: Need protocol abstraction layer

**Agent Interoperability Protocols Survey**
- **Citation**: http://arxiv.org/abs/2505.02279
- **Protocols covered**:
  - **MCP** (Model Context Protocol) - Anthropic's context acquisition standard
  - **A2A** (Agent-to-Agent) - Google's enterprise-focused protocol
  - **ANP** (Agent Network Protocol) - Decentralized agent internet vision
  - **ACP** (Agent Communication Protocol) - REST-native multimodal messaging
- **Adoption roadmap**: MCP → ACP → A2A → ANP
- **Implication**: Start with MCP for tool integration (we already support this)

**TalkHier: Structured Communication for Multi-Agent Systems**
- **Citation**: http://arxiv.org/abs/2502.11098
- **Pattern**: Structured communication protocol + hierarchical refinement system
- **Implication**: Agent messages should have structured format, not just free text

### 7. ReAct Loop Improvements (2025)

**Pre-Act: Multi-Step Planning Before Acting**
- **Citation**: http://arxiv.org/abs/2505.09970
- **Pattern**: Create multi-step execution plan with detailed reasoning BEFORE acting
- **Result**: 70% improvement in Action Recall over ReAct, 28% goal completion improvement
- **Key insight**: Plan incrementally incorporates previous steps and tool outputs
- **Implication**: Add planning phase before action phase in ReAct loop

**Multi-Agent Reflexion (MAR)**
- **Citation**: http://arxiv.org/abs/2512.20845
- **Problem**: Single-agent Reflexion has confirmation bias, repeated errors
- **Solution**: Diverse reasoning personas + judge model that synthesizes critiques
- **Pattern**: Separate acting, diagnosing, critiquing, and aggregating
- **Result**: MAR 47% EM vs Reflexion+ReAct 44% EM
- **Implication**: Use multiple perspectives for self-evaluation

**Model-First Reasoning (MFR)**
- **Citation**: http://arxiv.org/abs/2512.14474
- **Pattern**: Construct structured problem model BEFORE reasoning
- **Components**: Entities, state variables, actions with preconditions/effects, constraints
- **Result**: Reduces constraint violations, improves long-horizon consistency
- **Implication**: Consider explicit problem modeling step

### 8. Agent Memory Systems (2025)

**Memory in the Age of AI Agents (Survey)**
- **Citation**: http://arxiv.org/abs/2512.13564
- **Taxonomy**: Factual memory, experiential memory, working memory
- **Finding**: Traditional long/short-term taxonomy insufficient
- **Research frontiers**: Memory automation, RL integration, multimodal, multi-agent, trustworthiness
- **Implication**: Need richer memory taxonomy than just STM/LTM

**Agentic Memory (AgeMem)**
- **Citation**: http://arxiv.org/abs/2601.01885
- **Pattern**: Unified LTM+STM management via tool-based actions
- **Operations**: Store, retrieve, update, summarize, discard
- **Key insight**: Agent autonomously decides memory operations
- **Implication**: Memory operations should be tools, not implicit

**Memoria: Scalable Agentic Memory**
- **Citation**: http://arxiv.org/abs/2512.12686
- **Components**: Session-level summarization + weighted knowledge graph
- **Pattern**: Short-term coherence + long-term personalization
- **Implication**: Combine session summaries with persistent knowledge graph

### 9. Self-Correction and Verification (2025)

**MASC: Metacognitive Self-Correction for Multi-Agent Systems**
- **Citation**: http://arxiv.org/abs/2510.14319
- **Problem**: Single faulty step cascades across agents
- **Pattern**: Real-time, step-level error detection + correction agent
- **Result**: Up to 8.47% AUC-ROC improvement
- **Implication**: Intercept errors before they propagate downstream

**ReSeek: Self-Correcting Search Agents**
- **Citation**: http://arxiv.org/abs/2510.00568
- **Problem**: Early mistakes lead to irrevocable erroneous paths
- **Pattern**: JUDGE action to evaluate information and re-plan search strategy
- **Implication**: Add explicit evaluation checkpoints in search loops

**Self-Correction Blind Spot**
- **Citation**: http://arxiv.org/abs/2507.02778
- **Finding**: LLMs can't correct own errors but CAN correct identical external errors (64.5% blind spot rate)
- **Solution**: "Wait" prompt reduces blind spots by 89.3%
- **Implication**: Pause before self-correction, or use external validator

**AgentGuard: Runtime Verification**
- **Citation**: http://arxiv.org/abs/2509.23864
- **Pattern**: Verify dynamic processes, not just static outputs
- **Methods**: Automata-based control + multi-agent verification collaboration
- **Implication**: Runtime monitoring of agent behavior

### 10. Tool Selection Strategies (2025)

**Tool Preferences are Unreliable**
- **Citation**: http://arxiv.org/abs/2505.18135
- **Finding**: Tool selection based solely on natural language descriptions is fragile
- **Result**: Minor description edits yield up to 10x usage changes
- **Implication**: Tool descriptions need standardization, consider structured metadata

**AutoTool: Dynamic Tool Selection**
- **Citation**: http://arxiv.org/abs/2512.13278
- **Pattern**: Frame tool selection as sequence ranking (Plackett-Luce)
- **Result**: 6.4% math/science, 4.5% QA, 7.7% code, 6.9% multimodal improvement
- **Implication**: Tool selection benefits from explicit ranking model

**Agent-as-Tool: Hierarchical Tool Calling**
- **Citation**: http://arxiv.org/abs/2507.01489
- **Pattern**: Detach tool calling from reasoning - separate agent handles tools
- **Implication**: Consider tool-calling as delegated responsibility

### 11. Task Planning and Decomposition (2025)

**GoalAct: Global Planning + Hierarchical Execution**
- **Citation**: http://arxiv.org/abs/2504.16563
- **Pattern**: Continuously updated global plan + high-level skill decomposition
- **Skills**: Searching, coding, writing, etc.
- **Result**: SOTA with 12.22% success rate improvement
- **Implication**: Maintain global plan while executing hierarchically

**TwoStep: Classical Planning + LLM Goal Decomposition**
- **Citation**: http://arxiv.org/abs/2403.17246
- **Pattern**: LLM for commonsense goal decomposition, classical planner for execution
- **Result**: Faster planning + fewer execution steps
- **Implication**: Hybrid neuro-symbolic approach for planning

**Neuro-Symbolic Task Planning**
- **Citation**: http://arxiv.org/abs/2409.19250
- **Pattern**: LLM decomposes to subgoals, then symbolic or MCTS-based planning per subgoal
- **Key insight**: Decomposition reduces search space
- **Implication**: Match planning method to subgoal complexity

**Agentic Workflow Best Practices (Production Guide)**
- **Citation**: http://arxiv.org/abs/2512.08769
- **Nine best practices**:
  1. Tool-first design over MCP
  2. Pure-function invocation
  3. Single-tool, single-responsibility agents
  4. Externalized prompt management
  5. KISS principle adherence
- **Implication**: Reference checklist for production deployments

---

## Updated DSL Design Implications

### 6. Memory as Tools
```ruby
# Research pattern: Agent autonomously manages memory via tools
# @see http://arxiv.org/abs/2601.01885
Smolagents.agent
  .memory_tools(:store, :retrieve, :summarize, :forget)
  .working_memory_limit(10_000)  # tokens
  .on(:memory_stored) { |e| ... }
  .build
```

### 7. Pre-Act Planning Phase
```ruby
# Research pattern: Plan before acting for 70% improvement
# @see http://arxiv.org/abs/2505.09970
Smolagents.agent
  .phase(:plan)    # Generate multi-step plan first
  .phase(:act)     # Execute with plan refinement
  .phase(:reflect) # Evaluate and learn
  .build
```

### 8. Difficulty-Aware Routing
```ruby
# Research pattern: Adapt workflow to query complexity
# @see http://arxiv.org/abs/2509.11079
Smolagents.agent
  .difficulty_router { |query|
    estimate_complexity(query)  # VAE-based or heuristic
  }
  .when(:simple)  { |a| a.single_shot }
  .when(:medium)  { |a| a.react_loop(max_steps: 5) }
  .when(:complex) { |a| a.multi_agent_orchestration }
  .build
```

### 9. Self-Correction with External Validator
```ruby
# Research pattern: External validation beats intrinsic self-correction
# @see http://arxiv.org/abs/2507.02778
Smolagents.agent
  .validator { |output|
    # Separate model or rule-based check
    ValidatorAgent.check(output)
  }
  .on_invalid { |e| e.pause.reflect.retry }
  .build
```

---

## Updated Implementation Priorities

| Priority | Feature | Research Basis | Effort |
|----------|---------|----------------|--------|
| **P0** | UTF-8 sanitization | Failure mode #9 | LOW |
| **P0** | Circuit breaker categorization | Failure mode #10 | LOW |
| **P1** | Pre-Act planning phase | Pre-Act (70% improvement) | MEDIUM |
| **P1** | Agent Modes (reasoning, evaluation) | Metacognition papers | MEDIUM |
| **P1** | Goal State Tracking | Goal-oriented prompt paper | MEDIUM |
| **P1** | Memory as tools | AgeMem | MEDIUM |
| **P2** | Self-correction with validator | Self-Correction Blind Spot | MEDIUM |
| **P2** | Structured Error Handling | Self-correction decomposition | MEDIUM |
| **P2** | Hierarchical Delegation | Project Synapse, AgentOrchestra | HIGH |
| **P2** | Difficulty-aware routing | DAAO | MEDIUM |
| **P3** | Multi-Agent Reflexion | MAR | HIGH |
| **P3** | Cost-Aware Tool Selection | CATP-LLM, AutoTool | LOW |
| **P3** | Plan Caching | AgentReuse | LOW |
| **P3** | Agent protocols (MCP/A2A) | Protocol surveys | MEDIUM |

---

## Research Gaps to Fill

1. **Mode switching triggers**: When should agent switch from action to evaluation?
2. **Goal completion detection**: How to know when a goal is satisfied?
3. **Delegation granularity**: When to decompose vs execute directly?
4. **Error correction strategies**: What correction approaches work best?
5. **Difficulty estimation**: How to accurately predict query complexity?
6. **Memory retention policy**: What to keep vs. forget in long sessions?

---

## Key Takeaways from 2025 Research

1. **Multi-agent orchestration provides 80-140x quality improvements** - not just marginal gains
2. **Pre-Act planning before action yields 70% improvement** - worth the latency trade-off
3. **Self-correction has a blind spot** - external validators outperform intrinsic correction
4. **Tool selection is fragile** - descriptions need standardization, consider ranking models
5. **Memory should be explicit tools** - agent decides what to remember/forget
6. **Difficulty-aware routing** - adapt complexity to query, 11% accuracy at 64% cost
7. **Protocols matter** - MCP as starting point, plan for A2A/ANP future

---

## Consumer Hardware Orchestration (Small Model Patterns)

> **Vision**: Democratize powerful agent capabilities for consumer hardware through intelligent
> orchestration of small (≤4B parameter) models running locally.

### 12. Small Model Ensembles (2025)

**SLM-MUX: Orchestrating Small Language Models**
- **Citation**: http://arxiv.org/abs/2510.05077
- **Finding**: Two small models can BEAT Qwen-2.5 72B through intelligent orchestration
- **Result**: 13.4% improvement on MATH, 8.8% on GPQA, 7.0% on GSM8K
- **Key insight**: "Multi-core" approach beats scaling monolithic models
- **Implication**: Orchestration provides uplift that would otherwise require massive hardware

**Self-MoA: Self Mixture of Agents**
- **Citation**: http://arxiv.org/abs/2502.00674
- **Surprising finding**: Ensembling the SAME model beats mixing different LLMs
- **Result**: 6.6% improvement over mixed MoA on AlpacaEval 2.0
- **Key insight**: Self-consistency across multiple samples > model diversity
- **Implication**: Don't need multiple different models - one good small model is enough

**SwarmSys: Decentralized Swarm Agents**
- **Citation**: http://arxiv.org/abs/2510.10047
- **Architecture**: Explorers (propose paths) + Workers (execute) + Validators (check consistency)
- **Pattern**: Debate-consensus cycles that reinforce effective reasoning
- **Implication**: Role specialization within same model instance

**SwarmAgentic: Automated System Generation**
- **Citation**: http://arxiv.org/abs/2506.15672
- **Pattern**: PSO-based evolution of agent systems from scratch
- **Result**: 261.8% improvement over ADAS on TravelPlanner
- **Implication**: Agent architectures can be automatically optimized

### 13. Multi-Agent Debate Patterns

**Multi-Agent Debate Study**
- **Citation**: http://arxiv.org/abs/2511.07784
- **Finding**: Intrinsic reasoning strength + group diversity are key drivers
- **Caveat**: Structural parameters (order, visibility) offer limited gains
- **Implication**: Focus on model capability and persona diversity

**Talk Isn't Always Cheap: Debate Failure Modes**
- **Citation**: http://arxiv.org/abs/2509.05396
- **Warning**: Debate can fail when agents prioritize persuasion over truth
- **Implication**: Need grounding mechanisms to prevent rhetorical drift

**Multi-Agent LLM Dialogues for Ideation**
- **Citation**: http://arxiv.org/abs/2507.08350
- **Structure**: Ideation → Critique → Revision
- **Pattern**: Separate roles for proposing, critiquing, and revising
- **Implication**: Explicit phase structure improves output quality

### 14. Voting and Aggregation Strategies

**Confidence-Informed Self-Consistency (CISC)**
- **Citation**: http://arxiv.org/abs/2502.06233
- **Pattern**: Weighted majority vote based on model confidence scores
- **Result**: 40% reduction in required samples
- **Implication**: Confidence-weighted voting is more efficient than pure majority

**Optimal Self-Consistency (Blend-ASC)**
- **Citation**: http://arxiv.org/abs/2511.12309
- **Pattern**: Dynamically allocate samples based on question difficulty
- **Result**: 6.8x fewer samples than vanilla self-consistency
- **Implication**: Adaptive sampling massively reduces compute

**Ranked Voting Self-Consistency**
- **Citation**: http://arxiv.org/abs/2505.10772
- **Methods**: Instant-runoff, Borda count, mean reciprocal rank
- **Pattern**: Use ranking information, not just plurality
- **Implication**: Sophisticated voting outperforms simple majority

### 15. Iterative Refinement

**Self-Refine (Foundational)**
- **Citation**: http://arxiv.org/abs/2303.17651
- **Pattern**: Generate → Self-feedback → Refine (iterate)
- **Result**: ~20% improvement on average across tasks
- **Key insight**: No additional training required
- **Implication**: Single model can improve its own output iteratively

**EVOLVE: Self-Refinement via Preference Optimization**
- **Citation**: http://arxiv.org/abs/2502.05605
- **Pattern**: Iterative preference training with self-refinement data collection
- **Goal**: Bridge performance gap between small and large models
- **Implication**: Small models can learn to self-refine effectively

**SSR: Socratic Self-Refine**
- **Citation**: http://arxiv.org/abs/2511.10621
- **Pattern**: Decompose into (sub-question, sub-answer) pairs for step-level confidence
- **Result**: Outperforms SOTA iterative refinement baselines
- **Implication**: Fine-grained verification enables precise refinement

### 16. Speculative Execution (Draft-Verify)

**Speculative Decoding Pattern**
- **Concept**: Small fast model drafts tokens, larger model verifies
- **Benefit**: Parallelizes what would be serial computation
- **Typical speedup**: 2-5x

**SLED: Speculative Decoding for Edge**
- **Citation**: http://arxiv.org/abs/2506.09397
- **Pattern**: Edge device drafts locally, server verifies
- **Result**: 2.6-2.9x system capacity increase
- **Implication**: Hybrid local/remote architecture for consumer hardware

**Cascade Speculative Drafting**
- **Citation**: http://arxiv.org/abs/2312.11462
- **Pattern**: Multiple draft models in cascade (smallest first)
- **Vertical cascade**: Eliminates autoregressive from neural models
- **Horizontal cascade**: Optimizes time allocation
- **Implication**: Layered drafting for maximum efficiency

### 17. Edge Deployment Research

**LLM Inference on Single-Board Computers**
- **Citation**: http://arxiv.org/abs/2511.07425
- **Finding**: SBCs reliably support models up to 1.5B parameters
- **Result**: Llamafile achieves 4x higher throughput than Ollama
- **Implication**: Even Raspberry Pi can run useful agent inference

**Consumer Blackwell GPUs for LLM Deployment**
- **Citation**: http://arxiv.org/abs/2601.09527
- **Hardware**: RTX 5060 Ti, 5070 Ti, 5090
- **Finding**: Consumer GPUs becoming viable for production inference
- **Implication**: Local deployment increasingly practical

---

## Consumer Hardware DSL Patterns

Based on research, DSL patterns for small model orchestration:

### 10. Swarm Ensemble (Self-MoA Pattern)
```ruby
# Research: Same model ensemble beats mixing different models
# @see http://arxiv.org/abs/2502.00674
Smolagents.swarm
  .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
  .workers(5)                           # 5 parallel instances
  .temperature_spread(0.3..0.9)         # Diversity via temperature
  .aggregate(:confidence_weighted)       # CISC-style voting
  .build
```

### 11. Debate-then-Synthesize
```ruby
# Research: Multi-agent debate with role separation
# @see http://arxiv.org/abs/2512.20845
Smolagents.debate
  .model { small_model }
  .proposers(2)                         # Generate initial answers
  .critics(2)                           # Critique proposals
  .judge { small_model }                # Synthesize final answer
  .rounds(2)                            # Debate iterations
  .ground_truth_check { |answer| ... }  # Prevent rhetorical drift
  .build
```

### 12. Iterative Refinement
```ruby
# Research: Self-Refine yields 20% improvement, no training needed
# @see http://arxiv.org/abs/2303.17651
Smolagents.refine
  .model { small_model }
  .max_iterations(3)
  .feedback_prompt("Critique your answer. What could be improved?")
  .refine_prompt("Improve your answer based on the critique.")
  .stop_when { |output, iteration| output.unchanged? || iteration >= 3 }
  .build
```

### 13. Speculative Draft-Verify
```ruby
# Research: Small drafter + verifier = 2-5x speedup
# @see http://arxiv.org/abs/2506.09397
Smolagents.speculative
  .drafter { tiny_model }               # Fast, may be wrong
  .verifier { small_model }             # Slower, more accurate
  .draft_tokens(5)                      # Tokens to draft before verify
  .accept_threshold(0.8)                # Confidence to accept draft
  .build
```

### 14. Adaptive Sampling (Blend-ASC)
```ruby
# Research: 6.8x fewer samples with adaptive allocation
# @see http://arxiv.org/abs/2511.12309
Smolagents.sample
  .model { small_model }
  .strategy(:adaptive)                  # Allocate samples by difficulty
  .min_samples(1)
  .max_samples(10)
  .confidence_threshold(0.9)            # Stop when confident
  .voting(:ranked)                      # Borda count or instant-runoff
  .build
```

### 15. Swarm Roles (Explorer-Worker-Validator)
```ruby
# Research: SwarmSys role specialization
# @see http://arxiv.org/abs/2510.10047
Smolagents.swarm
  .model { small_model }
  .explorers(2) { |e| e.prompt("Propose solution paths") }
  .workers(3) { |w| w.prompt("Execute and develop solutions") }
  .validators(2) { |v| v.prompt("Check consistency and correctness") }
  .consensus_rounds(2)
  .build
```

---

## Updated Implementation Priorities (with Consumer Hardware)

| Priority | Feature | Research Basis | Effort |
|----------|---------|----------------|--------|
| **P0** | UTF-8 sanitization | Failure mode #9 | LOW |
| **P0** | Circuit breaker categorization | Failure mode #10 | LOW |
| **P1** | Pre-Act planning phase | Pre-Act (70% improvement) | MEDIUM |
| **P1** | Self-Refine loop | Self-Refine (20% improvement) | LOW |
| **P1** | Swarm ensemble (Self-MoA) | Self-MoA (6.6% over mixed) | MEDIUM |
| **P1** | Confidence-weighted voting | CISC (40% fewer samples) | LOW |
| **P2** | Debate pattern | MAR, Multi-agent debate | MEDIUM |
| **P2** | Speculative draft-verify | SLED | HIGH |
| **P2** | Adaptive sampling | Blend-ASC (6.8x efficiency) | MEDIUM |
| **P3** | Swarm roles | SwarmSys | HIGH |
| **P3** | Automatic architecture search | SwarmAgentic | EXPLORATORY |

---

## Key Insights for Consumer Hardware

1. **Two small models > one large model** - SLM-MUX shows 72B-beating results with orchestrated small models
2. **Same model ensemble works** - Self-MoA: don't need different models, just different samples/temperatures
3. **Confidence-weighted voting is 40% more efficient** - CISC reduces samples needed
4. **Self-Refine needs no training** - 20% improvement from prompt-only iterative refinement
5. **Edge deployment is viable** - Raspberry Pi runs 1.5B models; consumer GPUs handle production loads
6. **Speculative execution works locally** - Draft on edge device, verify on slightly larger model

---

## Security-Aware Routing (Data Privacy & Compliance)

> **Vision:** Route data to appropriate models/infrastructure based on sensitivity, compliance
> requirements, and data residency rules. Local for sensitive, cloud for general.
>
> **Use Cases:**
> - **Newsrooms**: Source protection, whistleblower data, investigative materials
> - **Healthcare**: HIPAA, PHI, patient records, clinical trials
> - **Finance**: SOC2, trading algorithms, customer financials, fraud investigation
> - **Legal**: Attorney-client privilege, litigation holds, contracts, discovery, M&A
> - **HR**: Employee PII, performance reviews, salary/comp data, workplace investigations
> - **Government**: Classified data, ITAR, FedRAMP, cross-border restrictions

### 18. Private and Confidential LLM Inference (2025)

**Confidential LLM Inference with TEEs**
- **Citation**: http://arxiv.org/abs/2509.18886
- **Solution**: Trusted Execution Environments (Intel TDX, SGX) for secure inference
- **Result**: Under 10% throughput overhead, 20% latency overhead
- **Hardware**: Llama2 7B/13B/70B running in CPU TEEs
- **Implication**: Hardware-backed security is practical for production

**Confidential and Efficient LLM Inference (CMIF)**
- **Citation**: http://arxiv.org/abs/2509.09091
- **Pattern**: Embedding layer in client TEE, subsequent layers on GPU server
- **Privacy**: Report-Noisy-Max mechanism protects inputs
- **Implication**: Split architecture for privacy-preserving inference

**Confidential Prompting (Petridish)**
- **Citation**: http://arxiv.org/abs/2409.19134
- **Goal**: Secure user prompts from untrusted cloud LLM
- **Innovation**: Secure Partitioned Decoding (SPD)
- **Use cases**: Personal data, clinical records, financial documents
- **Implication**: Cloud inference with prompt privacy

**PrivacyRestore**
- **Citation**: http://arxiv.org/abs/2406.01394
- **Pattern**: Privacy removal before sending, restoration after receiving
- **Benefit**: Plug-and-play, no model modification needed
- **Implication**: Transparent privacy layer for any LLM API

### 19. Compliance Frameworks (GDPR, HIPAA, SOC2)

**Zero Data Retention for Enterprise AI**
- **Citation**: http://arxiv.org/abs/2510.11558
- **Requirement**: User inputs/outputs never retained after interaction
- **Regulations**: GDPR, HIPAA, SOC2 all require this capability
- **Data residency**: Must process within legal jurisdiction
- **Implication**: Ephemeral processing mode for sensitive queries

**HIPAA-Compliant Agentic AI**
- **Citation**: http://arxiv.org/abs/2504.17669
- **Components**:
  1. Attribute-Based Access Control (ABAC) for PHI governance
  2. Hybrid PHI sanitization (regex + BERT-based detection)
  3. Immutable audit trails for compliance verification
- **Requirement**: Business Associate Agreement (BAA) for API calls
- **Implication**: Healthcare agents need sanitization pipeline

**Compliance as Trust Metric**
- **Citation**: http://arxiv.org/abs/2601.01287
- **Pattern**: Automated Compliance Engine (ACE) with LLM policy translator
- **Innovation**: Convert GDPR/HIPAA rules to executable Prolog rules
- **Implication**: Runtime compliance checking, not just design-time

### 20. Federated and Distributed Learning

**Federated Learning Survey**
- **Citation**: http://arxiv.org/abs/2504.17703
- **Pattern**: Collaborative training without centralizing data
- **Compliance**: Designed for GDPR and HIPAA requirements
- **Implication**: Multi-organization training without data sharing

**DP-FedLoRA: Privacy-Enhanced Federated Fine-Tuning**
- **Citation**: http://arxiv.org/abs/2509.09097
- **Pattern**: LoRA + Differential Privacy for edge device fine-tuning
- **Result**: Strong privacy guarantees with minimal performance loss
- **Implication**: Fine-tune on sensitive local data without exposure

**FedShield-LLM**
- **Citation**: http://arxiv.org/abs/2506.05640
- **Components**: FL + LoRA + Fully Homomorphic Encryption + Pruning
- **Goal**: Scalable, secure, regulation-compliant training
- **Implication**: Production-ready federated LLM infrastructure

**Blockchain-Enabled Federated Learning (FedAnil)**
- **Citation**: http://arxiv.org/abs/2502.17485
- **Pattern**: Decentralized FL with blockchain for enterprise
- **Benefit**: No single point of trust, auditable training
- **Implication**: Multi-enterprise collaboration without trust assumptions

### 21. Security Threats and Defenses

**Agentic AI Security Survey**
- **Citation**: http://arxiv.org/abs/2510.23883
- **Threat example**: EchoLeak (CVE-2025-32711) - Copilot exfiltrating sensitive data
- **Defense**: Sandboxing to prevent data leakage and code injection
- **Implication**: Agent sandboxing is security-critical

**LLM-Based Agent Risk Survey**
- **Citation**: http://arxiv.org/abs/2411.09523
- **Finding**: ReAct-prompted GPT-4 vulnerable in ~25% of test cases
- **Risks**: Prompt leakage, indirect injection via tools
- **Implication**: Tool invocation is an attack surface

---

## Security-Aware Routing DSL Patterns

### 16. Data Classification Routing
```ruby
# Route based on data sensitivity classification
# @see http://arxiv.org/abs/2510.11558
Smolagents.agent
  .classify_data { |input|
    case detect_sensitivity(input)
    when :pii, :phi then :local_only
    when :confidential then :private_cloud
    else :any
    end
  }
  .models {
    local(:sensitive) { on_prem_model }
    private(:confidential) { azure_confidential }
    cloud(:general) { openai_model }
  }
  .build
```

### 17. Compliance-Aware Routing
```ruby
# Route based on regulatory requirements
# @see http://arxiv.org/abs/2504.17669
Smolagents.agent
  .compliance(:hipaa) {
    sanitize_phi: true,           # PHI detection and redaction
    audit_trail: true,            # Immutable logging
    baa_required: true,           # Only BAA-signed providers
    data_residency: :us_only      # Geographic constraint
  }
  .models {
    hipaa_compliant(:primary) { azure_healthcare_api }
    local(:fallback) { on_prem_llama }
  }
  .build
```

### 18. Zero Data Retention Mode
```ruby
# Ephemeral processing - nothing persists
# @see http://arxiv.org/abs/2510.11558
Smolagents.agent
  .ephemeral_mode(true)           # No logging, no caching
  .memory(:disabled)               # No conversation history
  .model { compliant_provider }
  .build
```

### 19. Multi-Tenant Isolation
```ruby
# Separate processing per tenant/customer
Smolagents.agent
  .tenant_isolation { |request|
    request.tenant_id             # Route to tenant-specific resources
  }
  .models_per_tenant {
    tenant_a: { local_model_a },
    tenant_b: { local_model_b },
    default: { shared_model }
  }
  .build
```

---

## Key Insights for Security-Aware Routing

1. **TEEs are production-ready** - Under 10% overhead for confidential inference
2. **Zero retention is achievable** - Ephemeral processing for GDPR/HIPAA/SOC2
3. **PHI sanitization is essential** - Regex + ML hybrid catches most PII/PHI
4. **Data residency matters** - Route to jurisdiction-appropriate infrastructure
5. **Audit trails required** - Immutable logging for compliance verification
6. **Tool invocation is attack surface** - Sandbox agent actions
7. **Federated learning works** - Train across orgs without sharing data

---

## Next Steps

1. **Immediate**: Fix UTF-8 sanitization and circuit breaker categorization (P0)
2. **Short-term**: Implement Self-Refine loop - simplest 20% win (P1)
3. **Short-term**: Implement swarm ensemble with confidence voting (P1)
4. **Medium-term**: Add debate pattern for complex reasoning (P2)
5. **Medium-term**: Speculative draft-verify for local speedup (P2)
6. **Long-term**: Automatic architecture search (P3)
