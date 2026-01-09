# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`smolagents` is HuggingFace's lightweight agent library (~1000 lines core). Agents write Python code to call tools or orchestrate other agents. The key differentiator is that `CodeAgent` writes actions as Python code snippets (rather than JSON tool calls), enabling loops, conditionals, and multi-tool calls in a single step.

## Commands

```bash
# Install dev dependencies
pip install -e ".[dev]"

# Code quality
make quality          # Check with ruff
make style            # Auto-fix with ruff

# Tests
make test             # Run all tests
pytest tests/test_agents.py -v              # Single file
pytest -k "test_code_agent" -v              # By pattern
pytest tests/test_agents.py::TestClassName  # Single class
```

## Architecture

### Core Components (src/smolagents/)

**agents.py** - Agent implementations
- `MultiStepAgent` - Abstract base class with ReAct loop
- `CodeAgent` - Writes actions as Python code, executes via `PythonExecutor`
- `ToolCallingAgent` - Uses JSON tool-calling format (standard LLM function calling)

**models.py** - LLM wrappers
- `Model` - Abstract base
- `InferenceClientModel` - HuggingFace Inference API (supports multiple providers)
- `LiteLLMModel` - 100+ LLM providers via LiteLLM
- `OpenAIModel` - OpenAI-compatible APIs
- `TransformersModel` - Local transformers models
- `VLLMModel`, `MLXModel` - Specialized local inference

**tools.py** - Tool system
- `Tool` - Base class; subclass and implement `forward()` method
- `ToolCollection` - Groups tools from MCP servers, LangChain, Hub, or Spaces
- `@tool` decorator - Convert functions to tools

**memory.py** - Conversation/step tracking
- `AgentMemory` - Stores all steps
- `ActionStep`, `TaskStep`, `PlanningStep`, `FinalAnswerStep` - Step types
- `ToolCall` - Represents a single tool invocation

**local_python_executor.py** - Sandboxed Python execution for CodeAgent

**remote_executors.py** - Sandboxed execution: `E2BExecutor`, `DockerExecutor`, `ModalExecutor`, `BlaxelExecutor`, `WasmExecutor`

### Prompts (src/smolagents/prompts/)

YAML templates define system prompts:
- `code_agent.yaml` - CodeAgent prompts
- `toolcalling_agent.yaml` - ToolCallingAgent prompts
- `structured_code_agent.yaml` - Structured output variant

### Agent Flow

1. Task added to `agent.memory`
2. ReAct loop: Memory → Model generates response → Parse code/tool calls → Execute → Observations back to memory
3. Loop until `final_answer()` called or `max_steps` reached
4. Returns output from `final_answer`

### Creating Tools

```python
from smolagents import Tool

class MyTool(Tool):
    name = "my_tool"
    description = "What this tool does"
    inputs = {
        "param": {"type": "string", "description": "Parameter description"}
    }
    output_type = "string"

    def forward(self, param: str) -> str:
        return result

# Or use decorator
from smolagents import tool

@tool
def my_tool(param: str) -> str:
    """What this tool does.

    Args:
        param: Parameter description
    """
    return result
```

### Input Types

Supported: `string`, `boolean`, `integer`, `number`, `image`, `audio`, `array`, `object`, `any`, `null`

### Test Fixtures

Common fixtures in `tests/fixtures/`:
- `test_tool` - Basic tool for testing
- `get_agent_dict` - Agent configuration dicts for deserialization tests

Tests auto-suppress agent logging via `conftest.py` fixture.

## CLI

```bash
smolagent "prompt"  # Run CodeAgent with prompt
smolagent           # Interactive setup wizard
webagent "prompt"   # Vision web browser agent (requires helium/selenium)
```

## Code Style

- Ruff for linting (line-length=119)
- Follow existing patterns: OOP, Pythonic idioms
- Type hints on public APIs
