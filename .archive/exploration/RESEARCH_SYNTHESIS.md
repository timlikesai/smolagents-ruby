# Agent Architecture Research Synthesis

Based on academic research (via ArXiv) and our empirical failure mode analysis, here are recommendations for improving smolagents-ruby.

## Key Papers Found

### 1. ReAct: Synergizing Reasoning and Acting (Yao et al., 2022)
**Link:** http://arxiv.org/abs/2210.03629v3

**Key Insight:** Generate reasoning traces AND actions in an **interleaved** manner.
- Reasoning traces help the model plan
- Actions execute against the environment
- The interleaving creates synergy

**Implication for smolagents-ruby:**
- Our ToolCallingAgent needs a "thinking" step before tool calls
- Current format: `tool_name(args)` → Should become: `Thought: ... tool_name(args)`
- The "Thought" gives the model space to reason about what to do

### 2. Learning From Failure (Wang et al., 2024)
**Link:** http://arxiv.org/abs/2402.11651v2

**Key Insight:** Train on NEGATIVE examples (failures), not just successes.
- LLMs are optimized for generation, not tool use
- Previous work only used successful trajectories
- Integrating failures helps models recover

**Implication for smolagents-ruby:**
- Our error feedback is on the right track
- Should explicitly show: "This failed because X. Try Y instead."
- Model needs to see failure patterns to learn recovery

### 3. Small LLMs Are Weak Tool Learners (Shen et al., 2024)
**Link:** http://arxiv.org/abs/2401.07324v3

**Key Insight:** Tool use requires multiple capabilities:
1. Understanding queries
2. Task planning
3. Tool invocation
4. Result summarization

Small LLMs struggle with ALL of these in one model.

**Implication for smolagents-ruby:**
- Our 4B model (gemma-3n-e4b) is "small" by these standards
- Should simplify each capability separately
- Consider: simpler planning, clearer tool descriptions, structured summarization prompts

## Where Information Should Live

Based on research and our failure analysis, here's where different types of information belong:

### System Prompt (High-level, stable)

```
You are an agent that solves tasks by calling Ruby tools.
You operate over MULTIPLE STEPS. Each step you can:
1. Think about what you need
2. Call a tool to get information
3. Use the results to plan next steps
4. Call final_answer when done

ALWAYS include your reasoning before calling a tool.
```

**Put here:**
- Agent identity ("you are a Ruby agent")
- Multi-step awareness ("you operate over multiple steps")
- ReAct pattern ("Think, then act")
- Meta-rules that apply to all tasks

### Tool Descriptions (Specific, actionable)

```
wikipedia: Search Wikipedia for encyclopedic facts.
  BEST FOR: established facts, definitions, historical info
  TIP: For addresses, search "[Company] Building"
  TIP: For actors, search "[Show] cast"
```

**Put here:**
- What the tool does
- What it's best for
- Search strategy tips
- Known limitations

### Observation Feedback (Dynamic, contextual)

```
✓ Found 2 Wikipedia articles

## The New York Times Building
620 Eighth Avenue, between 40th and 41st Streets...

NEXT STEPS:
- If this answers your question, call final_answer
- If you need more detail, search for specific topic
```

**Put here:**
- Status indicators (✓/✗/⚠)
- The actual results
- Explicit next step suggestions
- Recovery options if partial/failed

### State Transition Feedback (NEW - between steps)

```
STEP 2 of max 8
Original question: "What is the street address of NYT?"
Tools called so far: [wikipedia("New York Times")]
Information gathered: Headquartered at "The New York Times Building"
Missing: Specific street address

Consider: Search for "New York Times Building" to get address
```

**Put here:**
- Current step number and max
- Original question (prevent drift)
- What's been tried
- What's still needed
- Suggestions for this step

## Recommended Changes

### 1. Add Thought Step to Agent Loop

**Current:**
```
Task: "What is the address of NYT?"
wikipedia(query: "New York Times")
```

**Proposed:**
```
Task: "What is the address of NYT?"
Thought: I need to find the address. I'll search Wikipedia for information about NYT.
wikipedia(query: "New York Times")
```

### 2. Add Step Awareness

**Current:** Model doesn't know what step it's on
**Proposed:** Include in observation:
```
[Step 2/8] Previous: searched "New York Times" - found mention of building but no address
```

### 3. Improve Tool Descriptions with Strategies

**Current:**
```
wikipedia: Search Wikipedia for encyclopedic information.
```

**Proposed:**
```
wikipedia: Search Wikipedia for encyclopedic information.
  SEARCH STRATEGIES:
  - For addresses: search "[Name] Building" or "[Name] headquarters"
  - For people: search full name
  - If results mention an entity, search for that entity specifically
```

### 4. Add Original Question Reminder

When the model has made several calls, remind it:
```
REMINDER: Original question was "What is the street address of NYT?"
Your information so far mentions "The New York Times Building" but no street address.
Try: wikipedia(query: "New York Times Building")
```

## Implementation Priority

| Change | Impact | Effort | Priority |
|--------|--------|--------|----------|
| Search strategies in tool descriptions | HIGH | LOW | 1 |
| Thought step in prompt | HIGH | MEDIUM | 2 |
| Step number in observations | MEDIUM | LOW | 3 |
| Original question reminder | HIGH | MEDIUM | 4 |
| State transition feedback | MEDIUM | HIGH | 5 |

## Research Questions for Further Investigation

1. **Multi-LLM architectures** - Should we use different models for planning vs execution?
2. **Self-verification** - Can the model check its own answer before final_answer?
3. **Query decomposition** - Should complex questions be automatically broken down?
4. **Learning from sessions** - Can we track what works and adjust prompts?

## Future Architecture: Swappable HTTP Executors

Sites like DuckDuckGo block simple HTTP requests via TLS fingerprinting and JavaScript
challenges. A future architecture could support swappable executors:

```ruby
# Simple HTTP (default) - fast, no dependencies
agent = Smolagents.agent
  .tools(:wikipedia)  # Wikipedia works with simple HTTP
  .build

# Docker-based headless browser - for sites requiring full browser
agent = Smolagents.agent
  .tools(:duckduckgo)
  .http_executor(:headless_browser)  # Uses Docker container
  .build
```

**Design Principles:**
- Same tool interface, different backend
- Docker container runs headless Chrome (Ferrum/Puppeteer)
- Agent doesn't know or care about the executor
- Configuration flag to swap implementations
- Graceful fallback: try HTTP first, escalate to browser if blocked

## Summary

The key insight from research is that **small models need more scaffolding**:
- More explicit reasoning steps (ReAct)
- Clear failure recovery guidance (Learning from Failure)
- Simplified individual capabilities (Multi-LLM paper)

Our empirical findings confirm this - the model succeeds when given:
- Search strategy guidance
- Actionable next steps
- Status indicators
- Step awareness

The path forward is clear: **more structure, more feedback, more guidance**.
