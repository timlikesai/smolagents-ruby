# Live Integration Test Findings

This document captures discoveries, failure modes, and lessons learned from testing against real local models.

## Failure Modes Catalog

### F01: No Endpoints Reachable

**Symptom:** DNS resolution fails or connection refused on all endpoints.

**Causes:**
- Tailscale not running/connected
- LM Studio not running locally
- Network configuration issues

**Handling:** Tests should skip gracefully with exit 0, providing clear instructions.

**Resolution:**
- Start LM Studio on localhost:1234, OR
- Connect Tailscale with access to configured endpoints

### F02: Endpoint Reachable but No Models Loaded

**Symptom:** `/v1/models` returns empty array or model not found.

**Causes:**
- LM Studio running but no model loaded
- Model name mismatch

**Handling:** Tests should skip gracefully.

### F03: Model Loaded but Generation Fails

**Symptom:** Model created successfully but `generate()` throws exception.

**Causes:** (to be documented as we encounter them)
- Request format incompatibility
- Model-specific parameter issues
- Memory/resource constraints

---

## Test Infrastructure

### Endpoint Discovery

Tests use a discovery phase that:
1. Checks localhost:1234 first (for local development)
2. Falls back to Tailscale endpoints
3. Reports status of each endpoint
4. Selects first available with loaded models

### Bootstrap

`experiments/live/lib/bootstrap.rb` loads the full smolagents library and infrastructure config.

`experiments/live/lib/infrastructure.rb` provides endpoint configuration with:
- Environment variable overrides
- Tailscale defaults for distributed testing
- Optional dotenv support

---

## Observations

### 2026-01-28: Initial Setup

- LM Studio 0.4.0 probing works against real endpoints
- Network connectivity is a prerequisite that must be validated before tests
- Tailscale endpoints require Tailscale to be connected on the test machine

### 2026-01-28: First Successful Tests

**Test 01: Basic Model Communication**
- llama.cpp Ultra with GLM-4.7-Flash responds correctly
- Response time: ~5400ms for simple question
- Server capabilities correctly detected

**Test 02: Tool Calling**
- Function calling works with llama.cpp + GLM-4.7-Flash
- Response time: ~660ms for tool call
- Tool schema accepted, arguments correctly parsed

**Test 03: Full Agent**
- Agent successfully completed a tool-using task
- 2 steps: tool call → final_answer
- Response time: ~1050ms total

**Critical Bug Fix: LM Studio Tool Calling**

LM Studio tool calling was failing because `supports_tools?` in `request_builder.rb`
only returned `true` for explicit `true`, not for `:model_dependent`.

**Before (broken):**
```ruby
def supports_tools?(capabilities) = capabilities.supports_tools == true
# Returns false for :model_dependent → tools NOT included in request
```

**After (fixed):**
```ruby
def supports_tools?(capabilities)
  [true, :model_dependent].include?(capabilities.supports_tools)
end
# Returns true for :model_dependent → tools ARE included (optimistic)
```

This fix enabled native function calling on all LM Studio endpoints.

**Key Discovery: Tool Interface**

Tools must use the class-level DSL, NOT instance methods:

```ruby
# WRONG - will fail with "execute must be implemented"
class MyTool < Smolagents::Tools::Tool
  def name = "my_tool"
  def description = "..."
  def inputs = { ... }
  def forward(...) = ...
end

# CORRECT
class MyTool < Smolagents::Tools::Tool
  self.tool_name = "my_tool"
  self.description = "..."
  self.inputs = { ... }
  self.output_type = "string"

  def execute(...)
    # implementation
  end
end
```

### 2026-01-28: Model Evaluation Framework

Built a structured evaluation framework (`experiments/live/eval/`) with:
- YAML-based test suite definitions
- Persistent JSON result storage
- Matrix runner for testing multiple models
- Comparison report generation

**Key Discovery: Agent Code Actions vs Native Tool Calls**

The smolagents agent uses "code actions" (Ruby code that calls tools) rather than native OpenAI tool calling in the response. Tool calls appear in `step.code_action`:

```ruby
# Agent generates code like:
result = calculator(expression: "15 * 7")
final_answer(answer: result)

# NOT native tool_calls in the response message
```

The evaluator extracts tool calls from `code_action` strings when `model_output_message.tool_calls` is empty.

**Model Capability Matrix (2026-01-28)**

| Model | Basic Reasoning | Tool Calling | Avg Speed |
|-------|-----------------|--------------|-----------|
| granite-4.0-h-small | **100%** | 75% | 3729ms |
| google/gemma-3n-e4b | 80% | **100%** | 2500ms |
| glm-4.7-flash-mlx | 70% | 38% | 9482ms |
| zai-org/glm-4.7-flash | 60% | 0% | 6270ms |
| nemotron-3-nano (both) | 0% | 0% | - |

**Key Observations:**

1. **granite-4.0-h-small** excels at basic reasoning (100%) but sometimes skips tool calls for simple math (computes directly)

2. **gemma-3n-e4b** is the best tool-calling model (100%) and fastest at 2500ms average

3. **GLM variants** show inconsistent performance:
   - MLX version: 70%/38%
   - zai-org version: 60%/0% (memory conflicts on MacBook)

4. **Nemotron models** fail all tests (0%) - possible compatibility issues

**Model-Specific Failure Patterns:**

- **granite**: Ignores explicit tool-use instructions for simple calculations
- **gemma-3n-e4b**: Fails word counting, negation understanding
- **glm-4.7-flash-mlx**: Fails simple arithmetic (!), pattern completion
- **nemotron**: Complete failures suggest format or output parsing issues
