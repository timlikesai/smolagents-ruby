# smolagents-ruby Feature Parity with Python smolagents

**Last Updated:** 2026-01-11
**Overall Parity:** ~85-90%

## Feature Comparison

### Core Agents ✅ 100%

| Feature | Python | Ruby | Notes |
|---------|--------|------|-------|
| MultiStepAgent (base) | ✅ | ✅ | Abstract base with ReAct loop |
| CodeAgent | ✅ | ✅ | Writes code to call tools |
| ToolCallingAgent | ✅ | ✅ | JSON tool-calling format |
| Agent Factory Methods | ✅ | ✅ | `Agent.code()`, `Agent.tool_calling()` |

### Tool System ✅ 95%

| Feature | Python | Ruby | Notes |
|---------|--------|------|-------|
| Tool Base Class | ✅ | ✅ | Subclass with `forward()` method |
| Tool DSL | ✅ | ✅ | `Tools.define_tool` block syntax |
| Tool Collections | ✅ | ✅ | Group multiple tools |
| Tool Registry | ❌ | ✅ | Ruby-specific centralized lookup |
| ManagedAgentTool | ✅ | ✅ | Wrap agents as tools |
| Tool Result Wrapping | ✅ | ✅ | Auto-wrap, chainable in Ruby |
| Tool Pipeline DSL | ❌ | ✅ | Ruby-specific composition |

### Built-in Tools ✅ 100%

Ruby uses composable concerns instead of inheritance. Tools are in `lib/smolagents/tools/`.

| Tool | Python | Ruby | Notes |
|------|--------|------|-------|
| PythonInterpreter / RubyInterpreter | ✅ | ✅ | |
| FinalAnswer | ✅ | ✅ | |
| UserInput | ✅ | ✅ | |
| DuckDuckGo Search | ✅ | ✅ | |
| Google Search | ✅ | ✅ | |
| Bing Search | ❌ | ✅ | Ruby-only |
| Brave Search | ❌ | ✅ | Ruby-only |
| Wikipedia Search | ✅ | ✅ | |
| VisitWebpage | ✅ | ✅ | |
| SpeechToText | ✅ | ✅ | |

### Model Integrations 🟡 40%

| Provider | Python | Ruby | Notes |
|----------|--------|------|-------|
| OpenAI | ✅ | ✅ | GPT-4, etc. |
| Anthropic Claude | ❌ | ✅ | Claude models |
| Azure OpenAI | ✅ | ❌ | TODO |
| LiteLLM (100+ providers) | ✅ | ❌ | TODO: proxy support |
| HuggingFace Transformers | ✅ | ❌ | Local models |
| HuggingFace Inference | ✅ | ❌ | HF API |
| Amazon Bedrock | ✅ | ❌ | AWS models |
| VLLM | ✅ | ❌ | Optimized inference |
| MLX | ✅ | ❌ | Apple Silicon |
| **Local Servers** | | | |
| LM Studio | ✅ | ✅ | Port 1234 |
| Ollama | ✅ | ✅ | Port 11434 |
| llama.cpp | ✅ | ✅ | Port 8080 |
| mlx_lm.server | ✅ | ✅ | Port 8080 |
| vLLM | ✅ | ✅ | Port 8000 |
| Text-Generation-WebUI | ✅ | ✅ | Port 5000 |

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
| Token Usage Tracking | ✅ | ✅ |
| Timing Tracking | ✅ | ✅ |
| Callbacks | ✅ | ✅ |

### Executors 🟡 50%

| Executor | Python | Ruby | Notes |
|----------|--------|------|-------|
| Local Python | ✅ | ❌ | N/A for Ruby |
| Local Ruby | ❌ | ✅ | With sandbox |
| Docker | ✅ | ✅ | Container execution |
| E2B | ✅ | ❌ | Cloud sandbox |
| Modal | ✅ | ❌ | Serverless |
| Blaxel | ✅ | ❌ | Sandbox |
| WASM | ✅ | ❌ | WebAssembly |

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

| Feature | Python | Ruby | Notes |
|---------|--------|------|-------|
| Planning Step | ✅ | ✅ | |
| Planning Interval | ✅ | ✅ | |
| Custom Templates | ✅ | ✅ | Configurable per-agent |
| Update Plan Prompts | ✅ | ✅ | initial_plan + update_plan_pre/post |

### Streaming ✅ 100%

| Feature | Python | Ruby | Notes |
|---------|--------|------|-------|
| Stream Mode | ✅ | ✅ | |
| generate_stream() | ✅ | ✅ | |
| Lazy Evaluation | ❌ | ✅ | Ruby Enumerators |
| Fiber Streams | ❌ | ✅ | Bidirectional |
| Stream Composition | ❌ | ✅ | Merge/transform |

### CLI ✅ 100%

| Feature | Python | Ruby | Notes |
|---------|--------|------|-------|
| Interactive Mode | ✅ | ✅ | |
| Model Loading | ✅ | ✅ | |
| Tool Selection | ✅ | ✅ | |
| Gradio UI Export | ✅ | N/A | No Gradio.rb exists |

### Hub Integration ❌ 0%

| Feature | Python | Ruby | Notes |
|---------|--------|------|-------|
| push_to_hub() | ✅ | ❌ | HuggingFace Hub |
| from_hub() | ✅ | ❌ | |
| Tool Collections Hub | ✅ | ❌ | |

### Vision/Multimodal ✅ 90%

| Feature | Python | Ruby | Notes |
|---------|--------|------|-------|
| Image Input | ✅ | ✅ | |
| AgentImage Type | ✅ | ✅ | File/bytes/base64 support |
| AgentAudio Type | ✅ | ✅ | File/bytes support |
| AgentText Type | ✅ | ✅ | String wrapper |
| Vision Web Browser | ✅ | ❌ | Selenium (future) |
| Model Image Support | ✅ | ✅ | OpenAI & Anthropic |

### Monitoring/Logging ✅ 100%

| Feature | Python | Ruby | Notes |
|---------|--------|------|-------|
| AgentLogger | ✅ | ✅ | |
| Log Levels | ✅ | ✅ | |
| TokenUsage | ✅ | ✅ | Data.define struct |
| Timing | ✅ | ✅ | Per-step and total |
| Instrumentation | 🟡 | ✅ | Better in Ruby |
| Monitorable Concern | ❌ | ✅ | Callbacks, step tracking |
| Cost Estimation | ❌ | ❌ | Neither has it |
| Agent Tree Viz | ✅ | ❌ | Rich output |

---

## Ruby-Specific Advantages

Features Ruby does **better** or has exclusively:

| Feature | Description |
|---------|-------------|
| Concerns Architecture | 24 focused mixins vs monolithic Python files |
| Chainable ToolResult | `.select.sort_by.take.as_markdown` |
| Pattern Matching | `case result in ToolResult[data: Array]` |
| Fiber Streams | Bidirectional, composable |
| Immutable Data.define | Type-safe step objects |
| Circuit Breaker | Built-in API resilience |
| Rate Limiting | Request throttling |
| Tool Registry | Centralized tool management |
| Tool Pipeline DSL | Declarative composition |

---

## Action Items

### Completed

- [x] Add mlx_lm.server support (port 8080)
- [x] Add customizable planning templates
- [x] Add AgentImage/AgentAudio/AgentText output types

### Medium Effort

- [ ] Add LiteLLMModel (proxy to LiteLLM server)
- [ ] Add Azure OpenAI support

### Larger Efforts

- [ ] Hub integration (requires HF Ruby SDK)
- [ ] E2B/Modal remote executors
- [ ] Vision Web Browser (Selenium-Ruby)

---

## Test Coverage

- **Total Tests:** 773
- **MCP Tests:** 52
- **Agent Types Tests:** 30
- **Planning Tests:** 21
- **Pending:** 1 (requires API key)
