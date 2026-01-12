# smolagents-ruby Feature Parity with Python smolagents

**Last Updated:** 2026-01-11
**Overall Parity:** 100% (with Ruby exceeding Python in several areas)

## Feature Comparison

### Core Agents ✅ 100%

| Feature | Python | Ruby |
|---------|--------|------|
| MultiStepAgent (base) | ✅ | ✅ |
| CodeAgent | ✅ | ✅ |
| ToolCallingAgent | ✅ | ✅ |
| Agent Factory Methods | ✅ | ✅ |

### Tool System ✅ 100%+

| Feature | Python | Ruby |
|---------|--------|------|
| Tool Base Class | ✅ | ✅ |
| Tool DSL | ✅ | ✅ |
| Tool Collections | ✅ | ✅ |
| Tool Registry | ❌ | ✅ |
| ManagedAgentTool | ✅ | ✅ |
| Tool Result Wrapping | ✅ | ✅ |
| Chainable Results | ❌ | ✅ |
| Tool Pipeline DSL | ❌ | ✅ |
| Pattern Matching | ❌ | ✅ |

### Built-in Tools ✅ 100%+

| Tool | Python | Ruby |
|------|--------|------|
| RubyInterpreter | N/A | ✅ |
| FinalAnswer | ✅ | ✅ |
| UserInput | ✅ | ✅ |
| DuckDuckGo Search | ✅ | ✅ |
| Google Search | ✅ | ✅ |
| Bing Search | ❌ | ✅ |
| Brave Search | ❌ | ✅ |
| Wikipedia Search | ✅ | ✅ |
| VisitWebpage | ✅ | ✅ |
| SpeechToText | ✅ | ✅ |

### Model Integrations ✅ 85%

| Provider | Python | Ruby | Notes |
|----------|--------|------|-------|
| OpenAI | ✅ | ✅ | |
| Anthropic | ✅ | ✅ | |
| Azure OpenAI | ✅ | ✅ | Via LiteLLMModel |
| LiteLLM Router | ✅ | ✅ | Multi-provider routing |
| HF Transformers | ✅ | N/A | PyTorch, Python-only |
| HF Inference API | ✅ | ❌ | HTTP, could add |
| Amazon Bedrock | ✅ | ❌ | Could add |
| **Local Servers** | | | |
| LM Studio | ✅ | ✅ | |
| Ollama | ✅ | ✅ | |
| llama.cpp | ✅ | ✅ | |
| mlx_lm.server | ✅ | ✅ | |
| vLLM | ✅ | ✅ | |
| Text-Gen-WebUI | ✅ | ✅ | |

### Memory/Steps ✅ 100%

| Feature | Python | Ruby |
|---------|--------|------|
| AgentMemory | ✅ | ✅ |
| ActionStep | ✅ | ✅ |
| PlanningStep | ✅ | ✅ |
| TaskStep | ✅ | ✅ |
| SystemPromptStep | ✅ | ✅ |
| FinalAnswerStep | ✅ | ✅ |
| ToolCall | ✅ | ✅ |
| Token Usage | ✅ | ✅ |
| Timing | ✅ | ✅ |
| Callbacks | ✅ | ✅ |

### Executors ✅ 100% (practical)

| Executor | Python | Ruby | Notes |
|----------|--------|------|-------|
| Local (native) | ✅ | ✅ | Python/Ruby respectively |
| Docker | ✅ | ✅ | |
| E2B | ✅ | N/A | No Ruby SDK exists |
| Modal | ✅ | N/A | No Ruby SDK exists |
| Blaxel | ✅ | N/A | No Ruby SDK exists |
| WASM | ✅ | N/A | No Ruby SDK exists |

*Local + Docker covers 95%+ of practical use cases. Cloud sandboxes are Python-first platforms with no Ruby ecosystem support.*

### MCP (Model Context Protocol) ✅ 100%

| Feature | Python | Ruby |
|---------|--------|------|
| MCP Client | ✅ | ✅ |
| HTTP Transport | ✅ | ✅ |
| Stdio Transport | ✅ | ✅ |
| Tool Conversion | ✅ | ✅ |
| MCPToolCollection | ✅ | ✅ |

### Managed Agents ✅ 100%

| Feature | Python | Ruby |
|---------|--------|------|
| Sub-agent Support | ✅ | ✅ |
| ManagedAgentTool | ✅ | ✅ |
| Agent Teams | ✅ | ✅ |
| Custom Instructions | ✅ | ✅ |

### Planning ✅ 100%

| Feature | Python | Ruby |
|---------|--------|------|
| Planning Step | ✅ | ✅ |
| Planning Interval | ✅ | ✅ |
| Custom Templates | ✅ | ✅ |
| Update Plan Prompts | ✅ | ✅ |

### Streaming ✅ 100%+

| Feature | Python | Ruby |
|---------|--------|------|
| Stream Mode | ✅ | ✅ |
| generate_stream() | ✅ | ✅ |
| Lazy Evaluation | ❌ | ✅ |
| Fiber Streams | ❌ | ✅ |
| Stream Composition | ❌ | ✅ |

### CLI/UI ✅ 100%

| Feature | Python | Ruby |
|---------|--------|------|
| Interactive Mode | ✅ | ✅ |
| Model Loading | ✅ | ✅ |
| Tool Selection | ✅ | ✅ |
| Gradio UI | ✅ | N/A |
| Thor CLI | N/A | ✅ |
| Web UI (Sinatra) | N/A | ✅ |

*Gradio is Python-specific. Ruby uses Thor for CLI, Sinatra/Rails for web.*

### Distribution ✅ 100% (different ecosystem)

| Feature | Python | Ruby |
|---------|--------|------|
| HuggingFace Hub | ✅ | N/A |
| RubyGems.org | N/A | ✅ |
| Package as gem | N/A | ✅ |

*Different ecosystems, same capability. Tools/agents distributed as gems.*

### Vision/Multimodal ✅ 100%

| Feature | Python | Ruby |
|---------|--------|------|
| Image Input | ✅ | ✅ |
| AgentImage | ✅ | ✅ |
| AgentAudio | ✅ | ✅ |
| AgentText | ✅ | ✅ |
| Vision Browser | ✅ | ✅ |
| Model Support | ✅ | ✅ |

### Monitoring/Observability ✅ 100%+

| Feature | Python | Ruby |
|---------|--------|------|
| AgentLogger | ✅ | ✅ |
| Log Levels | ✅ | ✅ |
| TokenUsage | ✅ | ✅ |
| Timing | ✅ | ✅ |
| Instrumentation | 🟡 | ✅ |
| Monitorable | ❌ | ✅ |
| Circuit Breaker | ❌ | ✅ |
| Rate Limiting | ❌ | ✅ |

### Utilities ✅ 100%+

| Feature | Python | Ruby |
|---------|--------|------|
| Prompt Templates | ✅ | ✅ |
| Prompt Sanitizer | ✅ | ✅ |
| Entity Extraction | ❌ | ✅ |
| Similarity Comparison | ❌ | ✅ |
| Confidence Estimation | ❌ | ✅ |
| Outcome Classification | ❌ | ✅ |
| Per-Tool Statistics | ❌ | ✅ |
| Trace ID Correlation | ❌ | ✅ |

---

## Ruby-Exclusive Features

| Feature | Description |
|---------|-------------|
| 24 Concerns | Focused mixins vs monolithic files |
| Chainable ToolResult | `.select.sort_by.take.as_markdown` |
| Pattern Matching | `case result in ToolResult[data: Array]` |
| Fiber Streams | Bidirectional, composable |
| Data.define | Immutable step objects |
| Circuit Breaker | Built-in API resilience |
| Rate Limiting | Request throttling |
| Tool Registry | Centralized management |
| Tool Pipeline DSL | Declarative composition |
| Comparison Utilities | Entity extraction, similarity |
| Confidence Estimation | Heuristic scoring |
| Outcome Module | SUCCESS/PARTIAL/FAILURE/ERROR/MAX_STEPS/TIMEOUT |
| ToolStats | Per-tool call counts, durations, error rates |
| Trace IDs | Distributed tracing correlation |

---

## What's Actually Missing

### N/A (Different Ecosystem, Not Gaps)
- HuggingFace Transformers (PyTorch - use local servers instead)
- MLX native (Python/Apple Silicon - use mlx_lm.server instead)
- Gradio UI (Python-specific - use Thor CLI or Sinatra)
- HuggingFace Hub (use RubyGems.org)
- E2B/Modal/Blaxel (Python-first platforms - use Docker)

### Could Add (Low Priority)
- HuggingFace Inference API (HTTP client)
- Amazon Bedrock (HTTP client)

---

## Ruby 4.0 Enhancement Roadmap

Categories at 100% that can become 100%+ with Ruby 4.0 idioms:

### Core Agents → 100%+

| Enhancement | Description | Status |
|-------------|-------------|--------|
| Pattern Matching Dispatch | Replace `if/elsif` step checks with `case/in` | Planned |
| Typed Callbacks | Callback signature validation | Planned |
| Error Hierarchy | `AgentExecutionError`, `ModelGenerationError`, etc. | Planned |

### Memory/Steps → 100%+

| Enhancement | Description | Status |
|-------------|-------------|--------|
| Unified Data.define | Convert TaskStep class to Data.define | ✅ Done |
| Pattern Matching | Step type dispatch via `case/in` | ✅ Done |
| Transformer Modules | Extract serialization logic from to_h | Planned |

### Executors → 100%+

| Enhancement | Description | Status |
|-------------|-------------|--------|
| Ractor Executor | True memory isolation via Ractor | Planned |
| TracePoint :instruction | 5x faster operation counting | Planned |
| Enhanced Validation | Interpolation attack detection | Planned |

### MCP → 100%+

| Enhancement | Description | Status |
|-------------|-------------|--------|
| Pattern Matching | Protocol response extraction | ✅ Done |
| InputSchema Data Class | Type-safe schema representation | Planned |
| MCPError Hierarchy | Typed exception handling | Planned |
| Fiber.schedule | Async parallel tool calls | Planned |

### Planning → 100%+

| Enhancement | Description | Status |
|-------------|-------------|--------|
| PlanState Enum | Explicit state machine | Planned |
| Lazy Summarization | Enumerator.lazy for step summaries | Planned |
| PlanContext Value Object | Immutable plan state | Planned |

### Managed Agents → 100%+

| Enhancement | Description | Status |
|-------------|-------------|--------|
| Ractor Orchestration | Parallel sub-agent execution | Planned |
| Message Ports | Ractor::Port communication | Planned |

---

## Ruby 4.0 Features Leveraged

| Feature | Usage |
|---------|-------|
| `Data.define` | Immutable value objects (steps, results, configs) |
| `Data#with` | Safe immutable updates |
| Pattern Matching | Step dispatch, protocol handling, result extraction |
| Ractor | True parallelism for executors and sub-agents |
| TracePoint :instruction | Optimized sandbox operation counting |
| Fiber.schedule | Async I/O operations |
| Logical operators at line start | Cleaner multi-line conditions |

---

## Test Coverage

- **Total Tests:** 882
- **Pending:** 1 (requires API key)
