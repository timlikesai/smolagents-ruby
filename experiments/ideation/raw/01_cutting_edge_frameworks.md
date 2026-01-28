# Cutting-Edge Agent Frameworks: Research Notes (2025-2026)

Research compiled: January 2026

This document captures innovative features, novel approaches, and unconventional ideas from the latest agent framework research. Focus is on patterns that help smaller, local models perform better by reducing cognitive load.

---

## Table of Contents

1. [Framework Landscape Overview](#framework-landscape-overview)
2. [Novel Tool Calling Patterns](#novel-tool-calling-patterns)
3. [Memory and State Management](#memory-and-state-management)
4. [Error Recovery and Self-Healing](#error-recovery-and-self-healing)
5. [Context Optimization for Smaller Models](#context-optimization-for-smaller-models)
6. [Planning and Reasoning Architectures](#planning-and-reasoning-architectures)
7. [Progressive Disclosure and Dynamic Loading](#progressive-disclosure-and-dynamic-loading)
8. [Structured Output and Constrained Generation](#structured-output-and-constrained-generation)
9. [Guardrails and Safety](#guardrails-and-safety)
10. [Speculative Execution](#speculative-execution)
11. [Key Academic Papers](#key-academic-papers)
12. [Ideas for smolagents-ruby](#ideas-for-smolagents-ruby)

---

## Framework Landscape Overview

### Major Frameworks (2025-2026)

| Framework | Key Innovation | Best For |
|-----------|---------------|----------|
| **LangGraph** | Cyclical graph-based state machines | Complex workflows with conditional logic |
| **CrewAI** | Role-based multi-agent crews | Team-oriented task splitting |
| **Microsoft Agent Framework** | Merged AutoGen + Semantic Kernel | Enterprise production deployments |
| **OpenAI Agents SDK** | Replaced experimental Swarm (March 2025) | Production-ready handoff patterns |
| **HuggingFace smolagents** | ~1000 lines, code-first approach | Lightweight, minimal abstractions |

### Market Context
- AI agents market: $5.4B (2024) to $7.6B (2025), projected $50B by 2030
- 45.8% CAGR reflects shift from passive AI to autonomous systems

### Key Trend: Architecture Evolution
- 2023: Linear chains (step 1 -> step 2 -> step 3)
- 2025: Stateful graphs where agents revisit steps based on context
- LangGraph's rise reflects this shift toward graph-based, stateful designs

**Sources:**
- [Top AI Agent Frameworks 2025 - Codecademy](https://www.codecademy.com/article/top-ai-agent-frameworks-in-2025)
- [Agentic AI Frameworks 2026 - AlphaMatch](https://www.alphamatch.ai/blog/top-agentic-ai-frameworks-2026)
- [Microsoft Agent Framework - Visual Studio Magazine](https://visualstudiomagazine.com/articles/2025/10/01/semantic-kernel-autogen--open-source-microsoft-agent-framework.aspx)

---

## Novel Tool Calling Patterns

### Code Execution Over Direct Tool Calls (MCP Pattern)

**Key Insight:** Direct tool calls consume context for each definition and result. Agents scale better by writing code to call tools instead.

From Anthropic's engineering blog:
- Loops, conditionals, and error handling done with familiar code patterns
- More efficient than alternating between MCP tool calls and sleep commands
- This is why HuggingFace smolagents uses CodeAgents as the primary type

**Why It Matters for Small Models:**
- Reduces the number of LLM round-trips
- Leverages the model's code training rather than JSON schema understanding
- Code naturally supports function nesting and reuse

### Tool Schema Simplification ("Less is More")

**Research Finding:** Selectively reducing available tools significantly improves function-calling performance.

Best practices:
- Keep under 20 functions at any time (OpenAI recommendation)
- Break complex tools into smaller, focused ones
- Use enums for fixed value sets
- Mark required parameters explicitly

**Idea:** Dynamic tool filtering based on task context. Route to specialized agents with ~5 tools each instead of one agent with ~20 tools.

### MCP-Zero: Active Tool Discovery

Traditional approaches have limitations:
- Injecting full tool schemas creates extreme context overhead
- Large MCP ecosystems can exceed 200k tokens just for tool descriptions

MCP-Zero solves this with **hierarchical routing**:
1. Server-level filtering matches against MCP server descriptions
2. Tool-level ranking based on semantic similarity
3. Iterative discovery - agent can refine requests and trigger another retrieval cycle

**Sources:**
- [Code Execution with MCP - Anthropic](https://www.anthropic.com/engineering/code-execution-with-mcp)
- [MCP Tool Discovery - Portkey](https://portkey.ai/blog/mcp-tool-discovery-for-llm-agents)
- [Less is More - arXiv](https://arxiv.org/html/2411.15399v1)

---

## Memory and State Management

### Memory Architecture Categories

Recent research identifies multiple memory layers:

| Layer | Purpose | Example Systems |
|-------|---------|-----------------|
| Working Memory | Current task context | Context window |
| Episodic Memory | Specific interaction recall | MemGPT, A-MEM |
| Semantic Memory | Learned patterns/knowledge | Knowledge graphs |
| Procedural Memory | How to do things | Tool usage patterns |

### A-MEM: Agentic Memory (Feb 2025)

Key innovation: Autonomous generation of contextual descriptions for new memories with intelligent connection establishment.

Features:
- Follows Zettelkasten method principles
- Dynamic indexing and linking
- Doubles performance on multi-hop reasoning tasks
- Cost-effective resource utilization

### Nemori: Cognitive-Inspired Architecture

Based on the Free-Energy Principle:
- Autonomously segments conversational streams into episodes (Boundary Alignment)
- Continually updates via active prediction-calibration loops
- Prediction discrepancies drive knowledge integration

### Key Principle: Separation of Concerns

**Transient vs. Persistent stores:**
- Short-term/working memory (within session)
- Long-term, cross-session persistent memory

**Dynamic organizational structures with explicit mechanisms for:**
- Creation
- Update
- Retention
- Pruning

### Multi-Agent Transactive Memory

Like human teams knowing "who knows what":
- Meta-memory capabilities for cognitive resource allocation
- Avoid redundant processing across agents
- Working memory constraints necessitate external memory architectures

**Sources:**
- [Memory in the Age of AI Agents - arXiv](https://arxiv.org/abs/2512.13564)
- [A-MEM - arXiv](https://arxiv.org/abs/2502.12110)
- [Mem0 - arXiv](https://arxiv.org/pdf/2504.19413)

---

## Error Recovery and Self-Healing

### The Problem

Most agent systems remain fragile:
- Hallucinate tool schemas
- Repeat failing calls
- Drift out of valid state
- Require continuous human babysitting
- Structurally just one-shot reasoners chained together

### VIGIL: Reflective Runtime for Self-Healing Agents

Core architecture:
- Supervisor agent observes sibling task agents
- Aggregates behavioral logs into decaying memory traces (EmoBank)
- Stage-gated diagnosis using Roses-Buds-Thorns (RBT) framework

**Key Insight:** If an agent can observe its own behavior, summarize outcomes, and reflect on failure modes using structured memory, it can generate better adaptations.

### Best Practices for Retry Logic (2025)

1. **Explicit failure classification** - distinguish transient vs. permanent errors
2. **Exponential backoff with jitter**
3. **Adaptive error handling**
4. **Observability integration**

### Self-Reflective Repair Frameworks

Instead of merely retrying:
- Formulate concrete repair plans
- Revise reasoning chains
- Propose code patches
- Adjust tool arguments
- Accumulate structured episodic and semantic memories

**Finding:** Explicit, structured reflection outperforms heuristic or passive retry strategies for non-trivial error recovery.

### Memory Isolation Pattern

Rebuild agents with two core ideas:
1. Retry logic
2. Memory isolation

Result: Self-healing agent that recovers on its own, avoiding infinite loops, broken toolchains, and memory chaos.

**Sources:**
- [VIGIL - arXiv](https://www.arxiv.org/pdf/2512.07094v2)
- [Self-Healing LangChain Agent - Medium](https://medium.com/@bhagyarana80/how-i-built-a-self-healing-langchain-agent-with-retry-logic-and-memory-isolation-b76044414de4)
- [Mastering Retry Logic Agents 2025 - SparkCo](https://sparkco.ai/blog/mastering-retry-logic-agents-a-deep-dive-into-2025-best-practices)

---

## Context Optimization for Smaller Models

### ACON: Agent Context Optimization

A unified framework for systematic context compression:

**Results:**
- Reduces memory usage by 26-54% (peak tokens)
- Preserves task success with large LLMs
- Enables small LMs to achieve 20-46% performance improvements

**Key insight:** Task-specific guidelines enable consistent compression without sacrificing performance.

### CORAL: Cognitive Resource Self-Allocation

Problem: LLM agents falter on long-horizon tasks due to cognitive overload - working memory becomes cluttered with irrelevant information.

Solution: Agent-callable working memory management toolset that allows maintaining crucial checkpoints of progress.

### Chain of Draft (CoD) - February 2025

**Revolutionary finding:** Match CoT accuracy while using only 7.6% of the tokens.

How it works:
- Generate minimalistic yet informative intermediate reasoning outputs
- Limit each reasoning step to ~5 words or less
- Simple prompt modification, no model changes required

Performance:
- GSM8k: 91% accuracy (vs CoT 95%) with 20% of tokens
- Latency reduced by up to 76-79%
- 39-76% token reduction across tasks

**Limitation:** Best in few-shot settings, accuracy drops in zero-shot.

### Context Compression Techniques

**Extractive vs. Abstractive:**
- Extractive (select important sentences) often outperforms abstractive
- Study: +7.89 F1 points at 4.5x compression - compression actually improved accuracy by filtering noise
- Abstractive at similar ratios decreased performance by 4.69 F1 points

**LLMLingua (Microsoft Research):**
- State-of-the-art prompt compression
- Up to 20x compression with only 1.5% performance loss on reasoning tasks

### Structured Summarization (Factory.ai)

"Anchored iterative summarization":
- Maintain persistent summary with explicit sections
- Session intent, file modifications, decisions made, next steps
- Only newly-truncated spans are summarized and merged

**Key insight:** Structure forces preservation.

**Sources:**
- [ACON - OpenReview](https://openreview.net/pdf?id=7JbSwX6bNL)
- [Chain of Draft - arXiv](https://arxiv.org/abs/2502.18600)
- [Context Management - JetBrains Research](https://blog.jetbrains.com/research/2025/12/efficient-context-management/)
- [Compressing Context - Factory.ai](https://factory.ai/news/compressing-context)

---

## Planning and Reasoning Architectures

### ReAct vs Plan-and-Execute

| Approach | Pattern | Best For |
|----------|---------|----------|
| **ReAct** | Thought -> Action -> Observation loop | Adaptiveness, simple tasks |
| **Plan-and-Execute** | Separate planning phase from execution | Governance, reliability |

ReAct downsides:
- Requires LLM call for each tool invocation
- Plans only 1 sub-problem at a time
- May lead to sub-optimal trajectories

### Tree of Thoughts (ToT)

Maintains a tree of thoughts where thoughts represent coherent language sequences as intermediate steps:
- Self-evaluate progress through deliberate reasoning
- Branch into multiple paths
- Backtrack or explore alternatives

**Challenge:** Can lead to redundant exploration, high compute complexity.

### Adaptive Graph of Thoughts (AGoT) - February 2025

Unifies CoT, ToT, and graph-based reasoning:
- +46.2% on GPQA through dynamic decomposition
- No pre-training, algorithmic tailoring, or hyper-parameter optimization required
- Matches benefits of RL-based reasoning training methods

### Task Decomposition Advances (2025)

**TDAG (May 2025):** Dynamic Task Decomposition and Agent Generation
- Dynamically breaks complex tasks into smaller subtasks
- Assigns each to specifically generated subagents

**UniDebugger (Nov 2025):** Three-level hierarchical coordination
- Adaptively handles bugs of varying complexities

### Workflow Orchestration Patterns

| Pattern | Description | Use Case |
|---------|-------------|----------|
| **Sequential** | Tasks complete one after another | Simple, dependable workflows |
| **Parallel (scatter-gather)** | Tasks run simultaneously | Speed optimization |
| **Cyclic** | Feedback loops, revisit earlier steps | Refining outputs, quality checks |
| **DAG-based** | Directed acyclic graph with dependencies | Complex multi-step workflows |
| **State machine** | Explicit states, transitions, retries | Production requiring SLAs |

**Sources:**
- [AI Agent Planning: ReAct vs Plan-and-Execute](https://byaiteam.com/blog/2025/12/09/ai-agent-planning-react-vs-plan-and-execute-for-reliability/)
- [Adaptive Graph of Thoughts - arXiv](https://arxiv.org/html/2502.05078v1)
- [DAG Orchestration Pattern](https://deepwiki.com/arunpshankar/Agentic-Workflow-Patterns/3.1-dag-orchestration-pattern)

---

## Progressive Disclosure and Dynamic Loading

### The Problem: Context Rot

LLM performance degrades as context window fills up, even within technical limits.

**Quote:** "Agents lose IQ points when their context window is stuffed with irrelevant data."

### Progressive Disclosure Pattern

Instead of loading everything upfront:

**Three-tier loading strategy:**
1. **Index/Metadata** (~100 tokens) - names, descriptions, types
2. **Details** - full content only when needed
3. **Deep Dive** - original source files if required

### Claude Agent Skills Implementation

- Pre-load name and description of every skill at session start
- Lightweight metadata provides enough info for activation decisions
- Full instructions loaded only when skill is used

### Comparison: Skills vs MCP

| Aspect | MCP | Progressive Disclosure |
|--------|-----|----------------------|
| Loading | Everything at initiation | Just-In-Time |
| Context usage | Can consume entire window | Minimal until needed |
| Tool accuracy | Drops after 2-3 servers | Maintained |
| Scalability | Limited | High |

### Documentation-as-Code for Agents

Transform Markdown into agent-ready knowledge:
- Start from intent and boundaries
- Move toward execution details only when required
- Agents discover metadata, inspect structure, retrieve targeted sections

**Sources:**
- [Progressive Disclosure - AI Positive](https://aipositive.substack.com/p/progressive-disclosure-matters)
- [Claude Agent Skills - Digital Applied](https://www.digitalapplied.com/blog/claude-agent-skills-framework-guide)
- [Context Engineering Part 2 - Phil Schmid](https://www.philschmid.de/context-engineering-part-2)

---

## Structured Output and Constrained Generation

### Why It Matters

Structured outputs ensure:
- Schema adherence (not just valid JSON)
- No missing required keys
- No hallucinated enum values
- Direct extraction without post-processing

### Constrained Decoding

Modify generation process itself:
- Restrict token choices to valid paths
- Model still uses learned distributions
- Guides toward outputs satisfying structural requirements

**Performance:**
- NVIDIA NIM: Use `guided_json` with xgrammar backend for optimal speed
- vLLM 0.8.5: Jump decoding can skip known sequences

### Reasoning Models with Structured Output

DeepSeek R1 pattern:
- Generate reasoning in `<think>...</think>` tags
- Follow with JSON-formatted output
- Schema applies only to JSON section

**Idea for Ruby:** Separate reasoning trace from structured action output.

### SLM Advantage for Tool Calling

Small Language Models fine-tuned on narrow schemas:
- Emit cleaner, more constrained outputs
- Reduce brittle post-processing
- Fewer retries needed

**Example:** Google's FunctionGemma (270M parameters) - specifically designed for function calling on edge devices.

**Sources:**
- [Structured Outputs - OpenAI](https://platform.openai.com/docs/guides/structured-outputs)
- [Constrained Decoding - vLLM](https://developers.redhat.com/articles/2025/06/03/structured-outputs-vllm-guiding-ai-responses)
- [SLM Agents - Aisera](https://aisera.com/blog/small-language-model-agents/)

---

## Guardrails and Safety

### Layered Approach

Apply fast, low-cost checks first; escalate only when necessary:

| Check Type | Latency | Use Case |
|------------|---------|----------|
| Regex validation | Microseconds | Syntax, format |
| Neural classifiers | 10-100ms | Content moderation |
| LLM-as-judge | Seconds | Complex policy |

### MCP Schema-Based Safety Constraints

Embed in MCP manifests:
- Preconditions
- Postconditions
- Invariants

**Overhead:** ~8-13ms per tool call (negligible vs. 100-200ms LLM generation)

### Tool and Function Guardrails

Critical controls:
1. **Action allowlists per role** - define which tools each role can invoke
2. **Human approval for high-risk actions** - destructive/sensitive operations
3. **Input/output filters** - content moderation rules
4. **Role isolation** - strict tool usage guidelines

### Instruction Hierarchy for Prompt Injection Defense

OpenAI research:
- Improves safety results on all main evaluations
- Up to 63% increased robustness
- Generalizes to criteria excluded from training

**Multi-agent defense framework:**
- Combined approach reduces successful attack rates from 73.2% to 8.7%
- Maintains 94.3% of baseline task performance

**Sources:**
- [LLM Guardrails Best Practices - Datadog](https://www.datadoghq.com/blog/llm-guardrails-best-practices/)
- [Formal Safety Constraints Using MCP Schemas](https://www.ijirmps.org/papers/2025/6/232848.pdf)
- [Securing AI Agents Against Prompt Injection - arXiv](https://arxiv.org/abs/2511.15759)

---

## Speculative Execution

### Speculative Actions for Agents

Inspired by microprocessor speculative execution and speculative decoding:

**Concept:** Predict and tentatively pursue most likely next actions using faster models, while slower ground-truth executors catch up.

**Framework generalizes to:**
- Internal tool APIs
- External tool APIs
- MCP-server APIs
- Human responses

### SPAgent: Two-Level Scheduling

1. **Intra-Speculation Request Scheduling** - dynamically regulate speculative request emission
2. **Inter-Request Scheduling** - globally prioritize requests

**Results:** 1.08x to 1.65x speedup compared to baselines

### Suffix Decoding

Better performance for high-repetition tasks:
- Code-editing
- Agentic loops (self-reflection, self-consistency)
- RL rollouts

**Sources:**
- [Speculative Actions - OpenReview](https://openreview.net/pdf?id=P0GOk5wslg)
- [SPAgent - Tsinghua](https://nicsefc.ee.tsinghua.edu.cn/nics_file/pdf/66ef348c-c150-46d7-b2fc-c6f2afb217a5.pdf)

---

## Key Academic Papers

### Must-Read Papers (2025)

| Paper | Key Contribution |
|-------|------------------|
| **A-MEM** (Feb 2025) | Agentic memory with Zettelkasten-style linking |
| **Chain of Draft** (Feb 2025) | 7.6% tokens for same accuracy |
| **VIGIL** (Dec 2025) | Reflective runtime for self-healing |
| **Adaptive Graph of Thoughts** (Feb 2025) | Unified reasoning topology |
| **Small Language Models are the Future of Agentic AI** (Jun 2025) | SLM-first architectures |
| **ACON** (2025) | Agent context optimization framework |
| **ToolCaching** (Jan 2026) | Caching for LLM tool-calling |

### Survey Papers

- "Memory in the Age of AI Agents" - Comprehensive taxonomy of agent memory
- "Agentic AI: Architectures, Applications, Future Directions" - Dual-paradigm framework
- "Large Language Model Agent: Methodology, Applications, Challenges" - Unified architectural perspective

---

## Ideas for smolagents-ruby

Based on this research, here are concrete features that could differentiate smolagents-ruby and help smaller models perform better:

### High-Impact, Lower Effort

1. **Chain of Draft Prompting Mode**
   - Add CoD-style prompts as an option
   - Huge token savings (80%+) with minimal accuracy loss
   - Simple prompt modification, no architecture changes

2. **Progressive Tool Disclosure**
   - Load tool metadata first (~100 tokens each)
   - Full schemas only when tool is selected
   - Critical for keeping small model context clean

3. **Structured Summarization for History**
   - Anchored iterative summarization pattern
   - Explicit sections: intent, decisions, next steps
   - Structure forces preservation of important context

4. **Extractive Context Compression**
   - Prefer extractive over abstractive
   - Research shows it actually improves accuracy by filtering noise

### Medium Effort, High Impact

5. **Tool Result Caching (Memoization)**
   - Cache results from INFORMATIONAL (read-only) tool calls
   - Time-based invalidation
   - Significant latency and cost reduction

6. **Explicit Failure Classification**
   - Distinguish transient vs. permanent errors
   - Different retry strategies for each
   - Exponential backoff with jitter

7. **Action Space Reduction**
   - Dynamic tool filtering based on task context
   - Route to specialized agents with ~5 tools each
   - "Less is More" research shows this improves accuracy

8. **Reflection Pattern with Separate Evaluator**
   - Use different model for critique (can be smaller/faster)
   - Avoid single-model self-reinforcing errors
   - Generate-Critique-Refine cycle

### Architectural Innovations

9. **State Machine Orchestration**
   - Explicit states, transitions, retries, timeouts
   - Human-in-the-loop pause points
   - Deterministic, observable, fault-tolerant

10. **Speculative Tool Execution**
    - Predict likely next actions
    - Execute speculatively while LLM reasons
    - Parallelize tool latency with generation

11. **A-MEM Style Memory**
    - Autonomous contextual descriptions for memories
    - Dynamic linking between related memories
    - Zettelkasten-inspired organization

12. **Guardrails as First-Class Concern**
    - Layered validation (fast -> expensive)
    - Tool allowlists per role
    - MCP-style preconditions/postconditions

### Ruby-Specific Opportunities

13. **Code-First Agent Pattern**
    - Like smolagents Python, but Ruby blocks
    - Leverage Ruby's expressiveness for tool composition
    - DSL for defining action sequences

14. **Ractor-Based Speculative Execution**
    - Use Ruby's Ractors for parallel speculation
    - Cancel speculative work if prediction wrong
    - True parallelism for tool calls

15. **Data.define for Structured Outputs**
    - Already using this pattern
    - Add constrained generation support
    - Type-safe tool inputs/outputs

---

## Summary: Key Themes

1. **Less is More** - Fewer tools, shorter reasoning, minimal context
2. **Structure Preserves Information** - Structured summaries > unstructured compression
3. **Progressive Disclosure** - Load what you need, when you need it
4. **Separation of Concerns** - Different models for different purposes
5. **Explicit State Management** - State machines > implicit flow
6. **Self-Healing > Retry** - Structured reflection, not just retries
7. **Speculative Parallelism** - Don't wait sequentially when you can predict

The overarching insight: **Help the model by giving it less to think about, not more.**
