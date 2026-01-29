# Smolagents Model Evaluation Framework

Structured, persistent testing framework for evaluating local LLM capabilities.

## Overview

This framework enables:
- **Declarative test definitions** in YAML
- **Persistent result storage** for historical comparison
- **Automatic matrix testing** across all models
- **Comparison reports** showing model strengths/weaknesses

## Directory Structure

```
eval/
├── suites/                    # Test suite definitions (YAML)
│   ├── basic_reasoning.yml    # Tier 1: Basic reasoning without tools
│   ├── tool_calling.yml       # Tier 1: Single tool invocation
│   ├── tool_chaining.yml      # Tier 2: Multi-step tool chains
│   └── robustness.yml         # Tier 3: Error handling, edge cases
├── results/                   # Persistent result storage
│   └── {model_id}/
│       └── {suite_name}/
│           └── {timestamp}.json
├── reports/                   # Generated comparison reports
│   └── comparison_{date}.md
├── lib/
│   ├── runner.rb              # Test execution engine
│   ├── result_store.rb        # Result persistence
│   └── reporter.rb            # Report generation
└── run.rb                     # CLI entry point
```

## Test Tiers

| Tier | Focus | Pass Target | Priority |
|------|-------|-------------|----------|
| 1 | Core Capabilities | 95%+ | Must Pass |
| 2 | Reasoning & Tool Selection | 75%+ | Should Pass |
| 3 | Robustness & Error Handling | 70%+ | Important |
| 4 | Edge Cases & Hallucination | 60%+ | Nice-to-Have |
| 5 | Performance Metrics | N/A | Benchmarking |

## Usage

```bash
# Run a specific suite against a model
ruby eval/run.rb --suite tool_calling --model GLM-4.7-Flash

# Run all suites against all available models
ruby eval/run.rb --all

# Generate comparison report
ruby eval/run.rb --report

# Test a new model against all suites
ruby eval/run.rb --new-model "qwen3-coder-30b" --endpoint "http://localhost:1234/v1"
```

## Adding New Tests

Create or edit a YAML file in `suites/`:

```yaml
suite:
  name: my_new_suite
  description: Testing new capabilities
  tier: 2

tests:
  - name: my_test
    category: reasoning
    prompt: "Your prompt here"
    expect:
      contains: "expected output"
```

## Result Format

Results are stored as JSON with full metadata:

```json
{
  "model_id": "GLM-4.7-Flash",
  "suite_name": "tool_calling",
  "timestamp": "2026-01-28T18:45:00Z",
  "summary": {
    "total": 10,
    "passed": 9,
    "failed": 1,
    "pass_rate": 0.9
  },
  "results": [...]
}
```
