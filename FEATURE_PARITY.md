# smolagents-ruby Feature Parity with Python smolagents

**Last Updated:** 2026-01-11
**Overall Parity:** ~95% (for practical use cases)

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

### Executors 🟡 66%

| Executor | Python | Ruby | Notes |
|----------|--------|------|-------|
| Local (native) | ✅ | ✅ | Python/Ruby respectively |
| Docker | ✅ | ✅ | |
| E2B | ✅ | ❌ | Cloud sandbox |
| Modal | ✅ | ❌ | Serverless |
| Blaxel | ✅ | ❌ | Sandbox |
| WASM | ✅ | ❌ | WebAssembly |

*Note: Local + Docker covers 95%+ of practical use cases.*

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

### CLI ✅ 100%

| Feature | Python | Ruby |
|---------|--------|------|
| Interactive Mode | ✅ | ✅ |
| Model Loading | ✅ | ✅ |
| Tool Selection | ✅ | ✅ |
| Gradio UI | ✅ | N/A |

### Hub Integration ❌ 0%

| Feature | Python | Ruby |
|---------|--------|------|
| push_to_hub() | ✅ | ❌ |
| from_hub() | ✅ | ❌ |
| Tool Collections Hub | ✅ | ❌ |

*Requires HuggingFace Ruby SDK (doesn't exist).*

### Vision/Multimodal ✅ 95%

| Feature | Python | Ruby |
|---------|--------|------|
| Image Input | ✅ | ✅ |
| AgentImage | ✅ | ✅ |
| AgentAudio | ✅ | ✅ |
| AgentText | ✅ | ✅ |
| Vision Browser | ✅ | ❌ |
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

---

## What's Actually Missing

### Won't Implement (N/A)
- HuggingFace Transformers (PyTorch, Python-only)
- MLX native (Python/Apple Silicon, use mlx_lm.server instead)
- Gradio UI (no Ruby equivalent)
- Hub Integration (no HF Ruby SDK)

### Could Add (Low Priority)
- HuggingFace Inference API (HTTP client)
- Amazon Bedrock (HTTP client)
- E2B/Modal/Blaxel cloud executors
- Vision Web Browser (Selenium)

---

## Test Coverage

- **Total Tests:** 833
- **Pending:** 1 (requires API key)
