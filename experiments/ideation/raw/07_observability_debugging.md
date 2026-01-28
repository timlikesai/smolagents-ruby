# Observability, Debugging, and Introspection for AI Agents

## Research Summary

This document synthesizes research on how to make AI agent systems observable, debuggable, and introspectable. The goal: enable users to understand why an agent did what it did, replay failures, and tune their agents effectively.

---

## Part 1: Current State of Agent Debugging

### The Fundamental Challenge

LLM-based agents are inherently non-deterministic. Even with identical inputs and parameters, they generate different outputs on each execution. This creates critical challenges:
- **Reproducibility**: How do you debug when the execution trace disappears after each run?
- **Auditability**: How do you verify an agent made the right decision?
- **Optimization**: How do you improve behavior you cannot observe?

### How People Debug Agent Systems Today

#### 1. Observability Platforms (LangSmith, Langfuse, Arize)

**LangSmith** (LangChain ecosystem):
- Set one environment variable and tracing works
- Step-by-step visibility into agent workflows
- Pre-built dashboards tracking success rates, error rates, latency distribution
- Strong integration with LangChain/LangGraph

**Langfuse** (Open source alternative):
- Captures complete traces of LLM applications/agents
- Agent graphs now GA - visualizes true flow of execution
- Color-coded task status: orange (running), green (success), red (failure)
- Self-hostable for teams wanting control

**Arize Phoenix**:
- Built on OpenTelemetry (vendor/framework agnostic)
- Simulation capabilities for testing across scenarios and personas
- Quality metrics: LLM-as-Judge and human evals

#### 2. Enterprise Observability Integration

**Datadog LLM Observability**:
- End-to-end tracing across AI agents
- Visibility into inputs, outputs, latency, token usage, errors at each step
- Structured experiments and quality/security evaluations

**Traditional APM Extended**:
- If already on Datadog, add LLM Observability
- If on New Relic, use AI Monitoring
- If using W&B for experiments, try Weave

#### 3. Key Capabilities in Modern Tools

- End-to-end visibility: LLM calls, retrieval operations, embeddings, tool usage
- Multi-step workflow tracking for complex agent systems
- Session management to understand user journeys
- Cost tracking and token usage monitoring
- Quality metrics correlating with latency and cost

---

## Part 2: Visualization Tools for Agent Execution

### Agent-Specific Visualization

#### Trace Visualization
- **Waterfall views**: Show sequential execution of agent steps
- **Graph visualizations**: Display agent decision trees and branching logic
- **Timeline views**: Track when each operation occurred

#### Chain-of-Thought Visualization
- Components that show AI reasoning steps with search results and progress indicators
- Breaking down complex reasoning into clear, logical steps
- Real-time visualization as conclusions are reached

**LobeChat Example**: "Watch as complex problems unfold step by step through the innovative Chain of Thought visualization... transforms abstract thinking into an engaging, interactive experience."

#### Flame Graphs for Agents
Adapted from performance profiling, flame graphs can visualize:
- Stack depth (y-axis): Call hierarchy of agent operations
- Width: Time spent or frequency of code paths
- Colors: Status or category of operations

**Key insight from Brendan Gregg**: "The flame graph provides a new visualization for profiler output and can make for much faster comprehension, reducing the time for root cause analysis."

### Game AI Debugging: Lessons for LLM Agents

Game developers have solved similar problems with behavior trees:

**Unreal Engine AI Debugging**:
- Press apostrophe (') key to enable AI debugging
- Displays which branch of behavior tree is currently executing
- Shows Blackboard (state) information alongside tree visualization

**LimboAI (Godot)**:
- Colorizes tree items based on task status
- Orange for running, green for success, red for failure
- Bridges runtime debugging with editor visualization

**Key Patterns**:
- Real-time state visualization
- Color-coded status indicators
- Hierarchical decision tree display
- Runtime inspection without stopping execution

---

## Part 3: Time-Travel Debugging Concepts

### Core Approaches

**1. Record & Replay**
Record all non-deterministic inputs during execution. During debugging, deterministically replay using recorded inputs to reconstruct any prior state.

**2. Snapshotting**
Periodically take snapshots of entire program state. Roll back to saved states during debugging. Memory-intensive but enables arbitrary time jumps.

**3. Instrumentation**
Add code that logs state changes. Step backwards by reverting changes. Can significantly slow execution.

### Key Tools and Implementations

**rr (Record and Replay)**:
- Runs on stock Linux kernels, commodity hardware
- Records sources of non-deterministic input
- Replays by executing and inserting recorded data
- Slowdowns as low as 1.2x (12 minutes for a 10-minute suite)

**Microsoft TTD (WinDbg)**:
- Records process execution into trace files
- Replays forwards and backwards
- Eliminates need to restart debugging sessions

**Undo (LiveRecorder)**:
- Just-in-time instrumentation capturing minimum data
- 99% of program state reconstructed on demand
- Only non-deterministic inputs need recording
- Typical slowdown: 2-3x

### The Determinism Insight

> "Time travel debugging relies on the fact that many operations in a computer are actually deterministic and uses these as a way of identifying all sources of non-determinism."

For LLM agents, sources of non-determinism include:
- LLM responses (even with temperature=0)
- External tool calls (web searches, API calls)
- Timestamp-dependent operations
- Random selections

---

## Part 4: Replay and Reproducibility in Non-Deterministic Systems

### LangGraph Time Travel

**Checkpoint-Based State Replay**:
- Captures each state transition
- Transforms transient execution into replayable state machine
- Trace failures to specific workflow nodes
- Inspect intermediate state
- Re-execute from any checkpoint without full re-run

> "The LLM remains probabilistic, but the workflow becomes deterministic, debuggable, and auditable."

### Requirements for Deterministic Replay

1. **Input Consistency Validation**
   - Replay stubs validate inputs match recorded inputs
   - Detect cases where control flow diverged

2. **Metadata Verification**
   - Verify model IDs, tool IDs, version numbers
   - Surface mismatches if environment has drifted

3. **Frozen Context**
   - Ensure RAG retrieval is static for debug session
   - Pin external data sources

### Practical Debugging Techniques

To minimize randomness during investigation:
- **Fix the Seed**: If model provider supports it
- **Lower Temperature**: Temporarily reduce to 0 to isolate logic from creativity
- **Freeze Context**: Ensure retrieval is static
- **Cache Responses**: Store and replay known LLM responses

### AgentRR: Record & Replay for Agents

Core insight: Most program execution is deterministic. Only non-deterministic events need logging:
- External inputs
- Thread scheduling
- System call results
- Signals
- LLM responses

---

## Part 5: Tracing and Distributed Tracing Patterns

### OpenTelemetry for AI Agents

**Core Concepts**:
- **Trace**: Complete journey of a request
- **Span**: Individual operation within a trace
- **Context Propagation**: Trace context flows across service boundaries

**Span Types**:
- CLIENT: Outgoing requests
- SERVER: Request handling
- PRODUCER: Message/event publishing
- CONSUMER: Message/event processing
- INTERNAL: Operations within single service

### AI-Specific Tracing Considerations

Traditional tracing answers "where did the time go?" For AI systems, it must also answer:
- Did the agent choose the right tool for this user intent?
- Was the response grounded in retrieved context (RAG faithfulness)?
- Did prompt changes cause regressions?
- Which model/provider performed best (cost, quality, reliability)?

### Best Practices

1. **Consistent Naming**: Stable attributes across boundaries
2. **Context Propagation**: Headers/IDs flow across HTTP, gRPC, queues
3. **Labeled Prompt Changes**: Tag prompt_version and template_hash
4. **Granular Spans**: Split "black box" into key operations (retrieve, generate, evaluate, tool)

### OpenLLMetry (Traceloop)

SDK allowing teams to transmit LLM observability data to 10+ tools, enabling vendor-agnostic tracing.

---

## Part 6: Game Developer AI Debugging Techniques

### Behavior Tree Visualization

**Key Features**:
- Drag-and-drop editors for AI logic
- Runtime visualization of active branches
- State inspection without pausing execution
- Hierarchical view of decision logic

### Debugging Patterns from Games

1. **Visual State Machines**: See current state and transitions
2. **Blackboard Inspection**: View agent's "memory" or context
3. **Path Visualization**: See planned vs actual execution paths
4. **Hot Reload**: Update behavior without restarting
5. **Slow Motion Debugging**: Step through at reduced speed

### BehaviorTree.CPP (Robotics)

Production-ready framework featuring:
- Reactive, modular behaviors
- Debuggable by design
- Visual editor integration

### Industry Examples

- **Halo 5: Guardians**: BTs control entire squads of AI enemies
- **Bioshock, Spore**: Extensive behavior tree usage
- Unity, Unreal: Built-in BT editors and debuggers

---

## Part 7: Explainability and Interpretability Research

### Key Concepts

**Interpretability**: Degree to which humans can understand model's internal logic. Exists on a spectrum. High interpretability = non-experts can comprehend input/output relationships.

**Explainability**: Process of generating justification. XAI techniques reveal how and why decisions were made when internal logic is too complex.

### Major XAI Techniques

**LIME (Local Interpretable Model-Agnostic Explanations)**:
- Manipulates input data to create artificial variations
- Runs through model, observes output changes
- Creates interpretable "surrogate" models

**SHAP (SHapley Additive exPlanations)**:
- Based on cooperative game theory
- Calculates contribution of each input variable
- Considers all possible variable combinations

**DeepLIFT**:
- Compares neuron activation to reference
- Shows traceable links between activated neurons
- Reveals dependencies

### Counterfactual Explanations

"What minimal change to the input would change the output?"

Applications:
- Debugging predictive models
- Detecting spurious correlations
- Identifying unwanted biases
- Explaining negative decisions to users

Evaluation metrics:
- **Feasibility**: How realistic are the modifications?
- **Proximity**: How close to original input?
- **Sparsity**: How short is the explanation?
- **Stability**: How robust to model changes?

### Chain-of-Thought Faithfulness Concerns

Anthropic research reveals important limitations:
- Reasoning models "verbalize used hints at least 1% of the time"
- Often verbalize less than 20% of the time
- Claude 3.7 Sonnet mentioned hints only 25% of the time
- Models may engage in "bullshitting" - producing answers without caring if true

> "There's no specific reason why the reported Chain-of-Thought must accurately reflect the true reasoning process; there might even be circumstances where a model actively hides aspects of its thought process."

---

## Part 8: Automated Root Cause Analysis

### AI-Powered RCA

AI agents for Root Cause Analysis bring unique strengths:
- **Causal Inference**: Build cause-effect chains instead of correlating blindly
- **Pattern Recognition**: Detect recurring anomalies across logs and traces
- **Context Awareness**: Consider environment metadata (deployments, traffic spikes)
- **Adaptive Learning**: Models learn from past incidents

### Validation Strategies

1. Consistency checking across multiple data sources
2. Simulation-based validation
3. Comparison with known failure patterns
4. Predicting observable consequences, then monitoring for confirmation

### Notable Implementations

**RCAgent** (Cloud RCA):
- Autonomous root cause analysis for cloud systems
- Outperforms ReAct approach in comprehensive RCA
- Addresses context length challenges

**ChipAgents RCA** (Hardware):
- Analyzes designs, testbenches, logs, waveform databases
- Resolves errors 12x faster than human engineers
- Suggests fixes automatically

### Challenges

- **Context Length**: Logs, code, query results tend to be enormous
- **Human-AI Collaboration**: How to merge human intuition with agent patience?
- **Domain Expertise**: Agents lack engineer's specific knowledge

---

## Part 9: Event Sourcing for Agent Systems

### Core Pattern

Event Sourcing stores complete history of changes rather than just current state. Every modification becomes an immutable event appended to an event log.

> "Event Sourcing transforms your application's relationship with data from storing 'what is' to preserving 'what happened.'"

### Benefits for Agent Debugging

1. **Complete Audit Trail**: Every event can be audited
2. **State Reconstruction**: Replay events to reconstruct state at any point
3. **Time-Travel Queries**: "What was the state at time T?"
4. **Debugging**: Replay event streams to understand behavior

### CQRS Integration

Command Query Responsibility Segregation pairs naturally:
- **Write Side**: Handles commands that generate events
- **Read Side**: Builds projections for optimized queries

### Optimization: Snapshots

Periodically save entity's current state. To reconstruct:
1. Find most recent snapshot
2. Replay only events since that snapshot
3. Fewer events to process

### Considerations

- **Eventual Consistency**: Read data may lag
- **Complexity**: Tracing across command/query sides harder
- **When NOT to use**: Simple domains, current state sufficient, resource constraints

---

## Part 10: Delta Debugging for Failure Isolation

### Core Algorithm

Delta debugging isolates failure causes by systematically narrowing down failure-inducing circumstances until a minimal set remains.

**DDMIN (Delta Debugging Minimization)**:
- Finds minimal failure-inducing input from failing input
- Employs binary search algorithm

**DD (Delta Debugging)**:
- Isolates minimal failure-inducing difference
- Between passing and failing test case

### Applications

1. **Input Minimization**: Reduce large failing input to minimal reproducer
2. **User Interaction Isolation**: Find minimal sequence of actions causing crash
3. **Change Isolation**: Identify which code changes introduced failure

### Real-World Example

Mozilla browser crash case study:
- Originally crashed after 95 user actions
- Delta debugging reduced to minimal reproduction
- Fully automatic when test is deterministic

### Prerequisites

Same as fuzzing:
- Deterministic test case (or can be made deterministic)
- Runs quickly enough for multiple experiments
- Clear pass/fail oracle

---

## Part 11: Interactive Debugging and REPL

### AI-Native IDEs

**Cursor**:
- Deep codebase understanding
- Answer questions about entire project
- Context-aware refactors across files
- Ask "Why is this function failing when called from X?"

**Windsurf**:
- Proactive AI agent (Cascade)
- Anticipates next step
- Suggests fixes and optimizations
- Shifts from reactive to preventive debugging

### Specialized Tools

**Pointbreak**:
- Uses MCP to give AI live execution data from debugger
- "Without real execution data, AI coding assistants hallucinate fixes"
- Collaborates with AI to run debug sessions, set breakpoints, inspect variables

**Zentara Code**:
- Automated bug detection
- Context-aware fix suggestions
- Natural-language interaction for debugging

### REPL-Based Debugging Power

Benefits of starting REPL at breakpoint:
- All variables in scope available
- Can print interactively
- Access to all functions
- Call functions to find issues
- Evaluate arbitrary code in context

---

## Part 12: Streaming and Real-Time Observation

### Streaming Frameworks

**LangChain Streaming**:
- Surface live feedback from agent runs
- Stream agent progress with state updates after each step
- Stream LLM tokens as generated
- Stream custom user-defined signals

**OpenAI Agents SDK**:
- Subscribe to updates as run proceeds
- Show end-user progress and partial responses

**Google ADK**:
- LiveRequestQueue abstraction for continuous input
- Near real-time processing without waiting for "turn end"
- Continuous streaming eliminates concept of "turn"

### Real-Time Observability Features

**LiveKit Agent Observability**:
- Synchronized audio playback
- Transcripts
- Turn-by-turn traces
- Logs in single place
- Detect latency spikes for specific turns

**Confluent Streaming Agents**:
- Kafka's immutable log provides replayability
- Rewind, debug, test, audit agent behavior
- Event-based memory and context
- Fast and safe iteration

---

## Part 13: Creative Applications for smolagents-ruby

### Idea 1: Time-Travel Agent Console

```ruby
# Concept: Interactive debugging console with time-travel
agent.run_with_debug("Research Ruby 4.0 features") do |debug|
  debug.on(:step_complete) do |step|
    puts "Step #{step.number}: #{step.action}"
    puts "  Reasoning: #{step.reasoning}"
    puts "  Duration: #{step.duration}ms"
  end

  debug.breakpoint_on { |step| step.tool == :web_search }

  debug.on(:breakpoint) do |context|
    # Interactive REPL at this point
    context.inspect_memory
    context.inspect_tools_available
    context.step_forward
    context.step_backward  # Time travel!
    context.what_if { context.memory[:search_results] = different_results }
  end
end
```

### Idea 2: Event-Sourced Agent State

```ruby
# All agent state changes stored as events
class EventSourcedAgent
  def run(task)
    emit(TaskReceived.new(task: task))

    loop do
      thinking = think_about_task
      emit(ThoughtGenerated.new(reasoning: thinking))

      action = decide_action(thinking)
      emit(ActionDecided.new(action: action, reasoning: thinking))

      result = execute_action(action)
      emit(ActionExecuted.new(action: action, result: result))

      break if result.final?
    end
  end

  # Reconstruct state at any point
  def state_at(timestamp)
    events.before(timestamp).reduce(initial_state) { |state, event| event.apply(state) }
  end

  # Replay from any checkpoint
  def replay_from(checkpoint, with_modifications: {})
    state = state_at(checkpoint)
    state.merge!(with_modifications)
    continue_from(state)
  end
end
```

### Idea 3: Visual Trace Explorer

```ruby
# Generate interactive HTML trace visualization
trace = agent.run_traced("Complex research task")

TraceVisualizer.new(trace).render do |viz|
  viz.flame_graph(by: :duration)      # Where did time go?
  viz.decision_tree                    # What choices were made?
  viz.token_waterfall                  # LLM token flow
  viz.tool_timeline                    # Tool execution sequence
  viz.memory_evolution                 # How context changed
end
```

### Idea 4: Counterfactual Analysis

```ruby
# What-if analysis for agent decisions
original_run = agent.run_recorded("Find best Ruby testing framework")

# What if the agent had received different search results?
counterfactual = original_run.replay_with(
  step: 3,
  modifications: {
    tool_result: different_search_results
  }
)

# Compare outcomes
comparison = RunComparison.new(original_run, counterfactual)
comparison.divergence_point
comparison.outcome_difference
comparison.reasoning_diff
```

### Idea 5: Semantic Log Search

```ruby
# Natural language queries over agent logs
logs = AgentLogs.from_runs(last_100_runs)

# Find similar failures
logs.search("runs where the agent got stuck in a loop")
logs.search("cases where web search returned no results")
logs.search("successful runs that used the calculator tool")

# Aggregate insights
logs.patterns("common failure modes")
logs.correlation("tool usage vs success rate")
```

### Idea 6: Delta Debugging for Prompts

```ruby
# Find minimal prompt that causes failure
failing_prompt = "Complex prompt with many instructions that causes agent to fail..."

minimized = DeltaDebugger.minimize(failing_prompt) do |candidate|
  result = agent.run(candidate)
  result.failed?  # Oracle: does this prompt cause failure?
end

puts "Minimal failing prompt: #{minimized}"
# Returns smallest substring that still triggers the failure
```

### Idea 7: Behavior Tree Visualization for Agents

```ruby
# Render agent logic as interactive behavior tree
agent = Smolagents.agent
  .model { model }
  .tools(:search, :calculate)
  .planning(enabled: true)
  .build

# Generate behavior tree representation
tree = agent.to_behavior_tree

tree.visualize do |node|
  case node.status
  when :running then :orange
  when :success then :green
  when :failure then :red
  end
end

# Export for game engine tools
tree.export_to(:unreal_bt)
tree.export_to(:unity_behavior_designer)
```

### Idea 8: Checkpoint & Resume

```ruby
# Save agent state at any point, resume later
run = agent.run_with_checkpoints("Long research task")

# Automatic checkpoints after each step
run.on(:checkpoint) do |cp|
  cp.save_to("checkpoints/#{cp.id}.json")
end

# Resume from any checkpoint
later_run = AgentRun.restore_from("checkpoints/step_5.json")
later_run.continue

# Resume with modified context
later_run = AgentRun.restore_from("checkpoints/step_5.json")
later_run.inject_context(new_information: "Updated data...")
later_run.continue
```

### Idea 9: Explanation Generator

```ruby
# Generate human-readable explanations of agent behavior
run = agent.run("Find the best Ruby web framework")

explanation = run.explain do |e|
  e.summarize            # High-level summary
  e.decision_rationale   # Why each decision was made
  e.alternatives         # What other options were considered
  e.confidence_levels    # How confident at each step
  e.key_moments          # Critical turning points
end

# Format for different audiences
explanation.for_developer    # Technical details
explanation.for_business     # Business impact
explanation.for_audit        # Compliance-friendly
```

### Idea 10: Collaborative Debugging Agent

```ruby
# An agent that helps debug other agents
debug_agent = Smolagents.agent
  .model { reasoning_model }
  .tools(:trace_analyzer, :log_search, :pattern_matcher)
  .as(:debugger)
  .build

# Analyze a failed run
analysis = debug_agent.run(<<~PROMPT)
  Analyze this failed agent run and identify:
  1. What went wrong
  2. When it went wrong
  3. Why it went wrong
  4. How to fix it

  Run trace: #{failed_run.trace.to_json}
PROMPT
```

---

## Key Takeaways

### For Understanding "Why"

1. **Structured traces** with spans for each operation
2. **Chain-of-thought visibility** (with faithfulness caveats)
3. **Counterfactual analysis** ("what if X had been different?")
4. **Explanation generation** at multiple detail levels

### For Replaying Failures

1. **Event sourcing** - store changes, not just state
2. **Checkpoint-based replay** - save and restore at any point
3. **Deterministic replay** - record non-deterministic inputs
4. **Delta debugging** - minimize to essential failure case

### For Tuning Agents

1. **Automated prompt optimization** - evolutionary/RL approaches
2. **A/B comparison** of different configurations
3. **Semantic log search** - find patterns in historical runs
4. **Feedback loops** - collect success metrics, iterate

### Implementation Priority for smolagents-ruby

1. **Event emission** (already have Events system) - ensure comprehensive coverage
2. **Trace visualization** - flame graphs, decision trees
3. **Checkpoint/resume** - save state, replay from any point
4. **Semantic search** - query logs naturally
5. **Counterfactual comparison** - what-if analysis
6. **Delta debugging** - minimize failing cases

---

## Sources

### LLM Observability Platforms
- [Top 5 AI Agent Observability Platforms 2026](https://o-mega.ai/articles/top-5-ai-agent-observability-platforms-the-ultimate-2026-guide)
- [Top 9 LLM Observability Tools in 2025](https://logz.io/blog/top-llm-observability-tools/)
- [LangSmith Observability](https://www.langchain.com/langsmith/observability)
- [Langfuse for Agents](https://langfuse.com/blog/2024-07-ai-agent-observability-with-langfuse)
- [Arize AI Platform](https://arize.com/)
- [Datadog LLM Observability](https://www.datadoghq.com/product/llm-observability/)

### Time-Travel Debugging
- [rr: lightweight recording & deterministic debugging](https://rr-project.org/)
- [Undo - Time Travel Debugging](https://undo.io/)
- [Temporal: Time-travel debugging production code](https://temporal.io/blog/time-travel-debugging-production-code)
- [Replay.io: Why time travel?](https://docs.replay.io/basics/time-travel/why-time-travel)

### Distributed Tracing
- [OpenTelemetry Traces](https://opentelemetry.io/docs/concepts/signals/traces/)
- [OpenTelemetry Context Propagation](https://opentelemetry.io/docs/concepts/context-propagation/)
- [Distributed Tracing for AI Agents](https://dev.to/kuldeep_paul/a-practical-guide-to-distributed-tracing-for-ai-agents-1669)

### Game AI Debugging
- [Unreal Engine AI Debugging](https://dev.epicgames.com/documentation/en-us/unreal-engine/ai-debugging-in-unreal-engine)
- [LimboAI Behavior Tree Debugger](https://deepwiki.com/limbonaut/limboai/6.1-behavior-tree-debugger)
- [BehaviorTree.CPP](https://www.behaviortree.dev/)

### Explainability
- [IBM: What is Explainable AI (XAI)?](https://www.ibm.com/think/topics/explainable-ai)
- [DARPA XAI Program](https://www.darpa.mil/research/programs/explainable-artificial-intelligence)
- [Anthropic: Tracing the thoughts of a large language model](https://www.anthropic.com/research/tracing-thoughts-language-model)

### Replay and Reproducibility
- [LangGraph Time Travel](https://dev.to/sreeni5018/debugging-non-deterministic-llm-agents-implementing-checkpoint-based-state-replay-with-langgraph-5171)
- [Trustworthy AI Agents: Deterministic Replay](https://www.sakurasky.com/blog/missing-primitives-for-trustworthy-ai-part-8/)

### Event Sourcing
- [Microsoft: Event Sourcing Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing)
- [Microservices.io: Event Sourcing](https://microservices.io/patterns/data/event-sourcing.html)

### Delta Debugging
- [The Debugging Book: Delta Debugging](https://www.debuggingbook.org/html/DeltaDebugger.html)
- [Delta Debugging Wikipedia](https://en.wikipedia.org/wiki/Delta_debugging)

### Root Cause Analysis
- [Algomox: Automated RCA with Agentic AI](https://www.algomox.com/resources/blog/agentic_ai_rca_root_cause/)
- [RCAgent: Cloud Root Cause Analysis](https://arxiv.org/pdf/2310.16340)

### Flame Graphs
- [Brendan Gregg: Flame Graphs](https://www.brendangregg.com/flamegraphs.html)
- [Datadog: Flame Graph Guide](https://www.datadoghq.com/knowledge-center/distributed-tracing/flame-graph/)

### Streaming and Real-Time
- [LangChain Streaming](https://docs.langchain.com/oss/python/langchain/streaming)
- [Google ADK Real-time Streaming](https://developers.googleblog.com/en/beyond-request-response-architecting-real-time-bidirectional-streaming-multi-agent-system/)
- [LiveKit Agent Observability](https://blog.livekit.io/streamline-troubleshooting-with-agent-observability/)

### Prompt Optimization
- [Automatic Prompt Optimization](https://cameronrwolfe.substack.com/p/automatic-prompt-optimization)
- [Opik Agent Optimizer](https://www.comet.com/site/blog/automated-prompt-engineering/)
