# Model Configuration Parameters: Research & Implementation Plan

## Executive Summary

This document presents research findings on LLM sampling parameters (temperature, top_p, top_k, frequency/presence penalties) and recommendations for implementing a comprehensive configuration system in smolagents-ruby that maximizes agent performance across different task types.

**Key Finding**: Different phases of agent execution benefit significantly from different parameter configurations. A well-designed system should support phase-specific parameter profiles while maintaining simplicity for common use cases.

---

## Part 1: Parameter Reference

### 1.1 Core Sampling Parameters

| Parameter | Purpose | Typical Range | Provider Support |
|-----------|---------|---------------|------------------|
| **temperature** | Controls randomness/creativity | 0.0-2.0 (varies) | All providers |
| **top_p** | Nucleus sampling threshold | 0.0-1.0 | All providers |
| **top_k** | Hard limit on token candidates | 1-100+ | Anthropic, Google, Cohere |
| **frequency_penalty** | Reduces repetition (proportional) | -2.0-2.0 | OpenAI, Google, Mistral |
| **presence_penalty** | Encourages new topics (flat) | -2.0-2.0 | OpenAI, Google, Mistral |

### 1.2 Provider-Specific Details

#### OpenAI
```
temperature:        0.0-2.0 (default: 1.0)
top_p:              0.0-1.0 (default: 1.0)
frequency_penalty:  -2.0-2.0 (default: 0)
presence_penalty:   -2.0-2.0 (default: 0)

⚠️ Reasoning models (o1, o3, GPT-5): Parameters are FIXED, cannot be changed
⚠️ Guidance: Alter temperature OR top_p, not both
```

#### Anthropic Claude
```
temperature:  0.0-1.0 (default: 1.0) — Note: narrower range than OpenAI
top_p:        0.0-1.0 (advanced use only)
top_k:        positive integer (advanced use only)

⚠️ Newer models (Claude 3.5+, Opus 4): Cannot specify BOTH temperature AND top_p
⚠️ Guidance: "You usually only need to use temperature"
```

#### Google Gemini
```
temperature:  0.0-2.0 (default: 1.0)
topP:         0.0-1.0 (default: 0.95)
topK:         0-100 (default: 40)

⚠️ Gemini 3: STRONGLY recommended to keep temperature at 1.0
   - Lower values may cause looping or degraded reasoning
```

#### Mistral
```
temperature:        0.0-2.0 (recommended: 0.0-0.7)
top_p:              0.0-1.0
frequency_penalty:  -2.0-2.0
presence_penalty:   -2.0-2.0

⚠️ Guidance: Tune temperature OR top_p, not both
```

---

## Part 2: Optimal Settings by Task Type

### 2.1 Quick Reference Matrix

| Task Type | Temperature | Top-P | Notes |
|-----------|-------------|-------|-------|
| **Tool/Function Calling** | 0.0-0.2 | default | Minimize schema errors |
| **Code Generation** | 0.1-0.3 | 0.9 | Deterministic, reliable |
| **Factual Q&A** | 0.0-0.3 | default | Reduce hallucinations |
| **Planning/Reasoning** | 0.3-0.5 | 0.85-0.95 | Balance focus & exploration |
| **Self-Evaluation** | 0.0-0.2 | default | Reproducible assessments |
| **General Conversation** | 0.5-0.7 | 0.95 | Natural, engaging |
| **Creative Writing** | 0.8-1.2 | 0.9-0.95 | Diversity, imagination |
| **Brainstorming** | 1.0-1.3 | 0.95 | Maximum exploration |

### 2.2 Agent Phase-Specific Recommendations

Based on multi-agent framework research (LangChain, CrewAI, smolagents-python, Anthropic's multi-agent systems):

```ruby
PHASE_PROFILES = {
  # Planning: Balanced between focus and exploring alternatives
  planning: {
    temperature: 0.3,
    top_p: 0.85,
    description: "Moderate creativity for strategy exploration"
  },

  # Tool Calling: Maximum reliability for structured output
  tool_calling: {
    temperature: 0.0,  # OpenAI explicitly recommends this
    top_p: 0.5,
    description: "Deterministic for valid function calls"
  },

  # Execution/Reasoning: Focused but allows some flexibility
  execution: {
    temperature: 0.3,
    top_p: 0.85,
    description: "Consistent reasoning with room for nuance"
  },

  # Final Answer: Depends on task, default to moderate
  final_answer: {
    temperature: 0.5,
    top_p: 0.9,
    description: "Natural, helpful responses"
  },

  # Self-Evaluation: Reproducible, consistent assessments
  evaluation: {
    temperature: 0.0,
    top_p: 0.7,
    description: "Consistent evaluation criteria"
  },

  # Code Generation: Precise, predictable
  code: {
    temperature: 0.2,
    top_p: 0.9,
    description: "Reliable code without hallucinated APIs"
  },

  # Creative Tasks: High diversity
  creative: {
    temperature: 1.0,
    top_p: 0.95,
    description: "Imaginative, diverse outputs"
  }
}
```

### 2.3 Research-Backed Insights

1. **Temperature Impact Study** (arXiv:2506.07295):
   - Larger models are more robust to temperature variations
   - Small models show sharp performance drops at temperature > 1.0
   - Task-finetuned models can safely use higher temperatures

2. **Multi-Agent Research** (Anthropic):
   - "Token usage explains 80% of performance variance"
   - Tool calls and model choice explain the remaining 15%
   - Extended thinking benefits from consistent (low) temperature

3. **Self-Reflection Research**:
   - Temperature 0.0 used universally for reproducibility
   - Significant performance improvements documented (p < 0.001)

---

## Part 3: Implementation Design for smolagents-ruby

### 3.1 Design Principles

1. **Simplicity First**: Defaults should work well without configuration
2. **Progressive Disclosure**: Simple API for common cases, power for advanced
3. **Phase-Aware**: Support different settings for different agent phases
4. **Provider-Agnostic**: Abstract away provider differences where possible
5. **Testable**: Easy to verify configuration in tests

### 3.2 Proposed API Design

#### Level 1: Simple Temperature Setting (Current + Enhanced)
```ruby
# Current API - works, simple
agent = Smolagents.agent
  .model { Smolagents.model(:openai).id("gpt-4").temperature(0.3).build }
  .tools(:search)
  .build
```

#### Level 2: Sampling Profile Presets
```ruby
# New: Named presets for common scenarios
agent = Smolagents.agent
  .model { Smolagents.model(:openai).id("gpt-4").sampling(:precise).build }
  .tools(:search)
  .build

# Available presets:
# :precise     → temperature: 0.0, for tool calling & code
# :balanced    → temperature: 0.5, general purpose (default)
# :creative    → temperature: 1.0, for brainstorming
# :reasoning   → temperature: 0.3, for analysis & planning
```

#### Level 3: Explicit Sampling Configuration
```ruby
# Full control with SamplingConfig
agent = Smolagents.agent
  .model {
    Smolagents.model(:openai)
      .id("gpt-4")
      .sampling(temperature: 0.2, top_p: 0.9, frequency_penalty: 0.1)
      .build
  }
  .build
```

#### Level 4: Phase-Specific Sampling (Advanced)
```ruby
# Different sampling for different agent phases
agent = Smolagents.agent
  .model(:execution) { fast_model.sampling(:precise) }
  .model(:planning) { big_model.sampling(:reasoning) }
  .model(:evaluation) { fast_model.sampling(:precise) }
  .planning(interval: 5)
  .evaluation(enabled: true)
  .build

# Or with explicit phase configs at agent level:
agent = Smolagents.agent
  .model { model }
  .sampling_for(:tool_calling, temperature: 0.0)
  .sampling_for(:final_answer, temperature: 0.5)
  .build
```

### 3.3 Type Definitions

```ruby
# lib/smolagents/types/sampling_config.rb
module Smolagents
  module Types
    SamplingConfig = Data.define(
      :temperature,        # Float, 0.0-2.0
      :top_p,              # Float, 0.0-1.0, optional
      :top_k,              # Integer, optional (Anthropic/Google)
      :frequency_penalty,  # Float, -2.0-2.0, optional (OpenAI/Mistral)
      :presence_penalty    # Float, -2.0-2.0, optional (OpenAI/Mistral)
    ) do
      def self.preset(name)
        PRESETS.fetch(name) { raise ArgumentError, "Unknown preset: #{name}" }
      end

      PRESETS = {
        precise: new(temperature: 0.0, top_p: nil, top_k: nil,
                     frequency_penalty: nil, presence_penalty: nil),
        balanced: new(temperature: 0.5, top_p: nil, top_k: nil,
                      frequency_penalty: nil, presence_penalty: nil),
        creative: new(temperature: 1.0, top_p: 0.95, top_k: nil,
                      frequency_penalty: nil, presence_penalty: nil),
        reasoning: new(temperature: 0.3, top_p: 0.85, top_k: nil,
                       frequency_penalty: nil, presence_penalty: nil)
      }.freeze

      def to_provider_params(provider)
        case provider
        when :openai
          to_openai_params
        when :anthropic
          to_anthropic_params
        when :google
          to_google_params
        else
          to_generic_params
        end
      end

      private

      def to_openai_params
        {
          temperature: temperature,
          top_p: top_p,
          frequency_penalty: frequency_penalty,
          presence_penalty: presence_penalty
        }.compact
      end

      def to_anthropic_params
        # Anthropic: can't use both temperature and top_p on newer models
        params = { temperature: temperature }
        params[:top_k] = top_k if top_k
        # Only add top_p if temperature not set (for older models)
        params
      end

      def to_google_params
        {
          temperature: temperature,
          topP: top_p,
          topK: top_k
        }.compact
      end

      def to_generic_params
        { temperature: temperature, top_p: top_p }.compact
      end
    end
  end
end
```

### 3.4 Files to Modify

| File | Changes |
|------|---------|
| `lib/smolagents/types/sampling_config.rb` | **NEW**: SamplingConfig type with presets |
| `lib/smolagents/types/model_config.rb` | Add `sampling` field |
| `lib/smolagents/builders/model_builder.rb` | Register `.sampling()` method |
| `lib/smolagents/builders/model_builder/setters.rb` | Add `.sampling()` implementation |
| `lib/smolagents/models/model.rb` | Accept sampling in initialize |
| `lib/smolagents/models/openai/request_builder.rb` | Apply sampling params |
| `lib/smolagents/models/anthropic/request_builder.rb` | Apply with provider rules |

---

## Part 4: Testing Strategy

### 4.1 Unit Tests (Mocked)

#### Configuration Tests
```ruby
# spec/smolagents/types/sampling_config_spec.rb
RSpec.describe Smolagents::Types::SamplingConfig do
  describe ".preset" do
    it "returns precise preset with temperature 0.0" do
      config = described_class.preset(:precise)
      expect(config.temperature).to eq(0.0)
    end

    it "returns creative preset with temperature 1.0" do
      config = described_class.preset(:creative)
      expect(config.temperature).to eq(1.0)
      expect(config.top_p).to eq(0.95)
    end

    it "raises for unknown preset" do
      expect { described_class.preset(:unknown) }
        .to raise_error(ArgumentError, /Unknown preset/)
    end
  end

  describe "#to_provider_params" do
    let(:config) { described_class.new(temperature: 0.5, top_p: 0.9, top_k: nil,
                                       frequency_penalty: 0.1, presence_penalty: nil) }

    it "formats for OpenAI" do
      params = config.to_provider_params(:openai)
      expect(params).to eq(temperature: 0.5, top_p: 0.9, frequency_penalty: 0.1)
    end

    it "formats for Anthropic (excludes unsupported params)" do
      params = config.to_provider_params(:anthropic)
      expect(params).to eq(temperature: 0.5)
      expect(params).not_to have_key(:frequency_penalty)
    end

    it "formats for Google with camelCase" do
      params = config.to_provider_params(:google)
      expect(params).to eq(temperature: 0.5, topP: 0.9)
    end
  end
end
```

#### Builder Tests
```ruby
# spec/smolagents/builders/model_builder_spec.rb
RSpec.describe Smolagents::Builders::ModelBuilder do
  describe "#sampling" do
    it "accepts preset symbol" do
      builder = Smolagents.model(:openai).id("gpt-4").sampling(:precise)
      expect(builder.config[:sampling].temperature).to eq(0.0)
    end

    it "accepts explicit parameters" do
      builder = Smolagents.model(:openai)
        .id("gpt-4")
        .sampling(temperature: 0.3, top_p: 0.8)

      expect(builder.config[:sampling].temperature).to eq(0.3)
      expect(builder.config[:sampling].top_p).to eq(0.8)
    end

    it "validates temperature range" do
      expect {
        Smolagents.model(:openai).id("gpt-4").sampling(temperature: 3.0)
      }.to raise_error(ArgumentError, /temperature must be between/)
    end
  end
end
```

#### Request Builder Tests
```ruby
# spec/smolagents/models/openai/request_builder_spec.rb
RSpec.describe Smolagents::Models::OpenAI::RequestBuilder do
  describe "#build_params" do
    it "includes sampling parameters in request" do
      builder = described_class.new(
        model_id: "gpt-4",
        temperature: 0.3,
        sampling: SamplingConfig.new(temperature: 0.3, top_p: 0.9, ...)
      )

      params = builder.build_params(messages: [...])

      expect(params[:temperature]).to eq(0.3)
      expect(params[:top_p]).to eq(0.9)
    end
  end
end
```

### 4.2 Integration Tests (MockModel)

```ruby
# spec/integration/sampling_config_spec.rb
RSpec.describe "Sampling configuration integration" do
  let(:mock_model) do
    Smolagents::Testing::MockModel.new(
      responses: ['final_answer(answer: "test")']
    )
  end

  it "passes sampling config through to model calls" do
    # Build agent with sampling config
    agent = Smolagents.agent
      .model { mock_model }
      .tools(:final_answer)
      .build

    agent.run("Test task")

    # Verify the call included expected parameters
    call = mock_model.calls.first
    expect(call[:temperature]).to eq(expected_temperature)
  end
end
```

### 4.3 Real Model Testing Strategy

For validating configurations work correctly with real models, create a dedicated test suite that can be run on-demand:

```ruby
# spec/real_models/sampling_validation_spec.rb
RSpec.describe "Real model sampling validation", :real_model do
  # These tests are tagged :real_model and skipped by default
  # Run with: REAL_MODEL_TESTS=1 bundle exec rspec --tag real_model

  before(:all) do
    skip "Real model tests disabled" unless ENV["REAL_MODEL_TESTS"]
  end

  describe "temperature effects" do
    let(:model) { Smolagents::OpenAIModel.new(model_id: "gpt-4o-mini", api_key: ENV["OPENAI_API_KEY"]) }

    it "produces more varied outputs at higher temperature" do
      low_temp_responses = 5.times.map do
        model.generate(
          messages: [{ role: "user", content: "Write a one-sentence joke" }],
          temperature: 0.0
        )
      end

      high_temp_responses = 5.times.map do
        model.generate(
          messages: [{ role: "user", content: "Write a one-sentence joke" }],
          temperature: 1.2
        )
      end

      # Low temperature should produce identical or very similar outputs
      low_temp_unique = low_temp_responses.uniq.count
      high_temp_unique = high_temp_responses.uniq.count

      expect(high_temp_unique).to be > low_temp_unique
    end

    it "produces valid tool calls at temperature 0" do
      tool_schema = { name: "get_weather", parameters: { location: "string" } }

      10.times do
        response = model.generate(
          messages: [{ role: "user", content: "What's the weather in Paris?" }],
          tools: [tool_schema],
          temperature: 0.0
        )

        # All responses should be valid tool calls
        expect(response).to include_valid_tool_call
      end
    end
  end

  describe "provider compatibility" do
    it "OpenAI accepts frequency_penalty" do
      model = Smolagents::OpenAIModel.new(...)
      response = model.generate(
        messages: [...],
        temperature: 0.5,
        frequency_penalty: 0.5
      )
      expect(response).to be_successful
    end

    it "Anthropic rejects frequency_penalty gracefully" do
      model = Smolagents::AnthropicModel.new(...)
      # Should either ignore or handle gracefully, not crash
      expect {
        model.generate(messages: [...], frequency_penalty: 0.5)
      }.not_to raise_error
    end
  end
end
```

### 4.4 Benchmark Testing

```ruby
# spec/benchmarks/sampling_benchmark_spec.rb
RSpec.describe "Sampling configuration benchmarks", :benchmark do
  # Compare performance across different sampling settings

  TASK_CONFIGS = {
    tool_calling: { prompt: "Calculate 15% tip on $45.50", expected: /calculate|tip/ },
    reasoning: { prompt: "Explain why the sky is blue in one paragraph", expected: /scatter|light/ },
    creative: { prompt: "Write a haiku about coding", expected: /\n.*\n/ }
  }

  SAMPLING_PRESETS = [:precise, :balanced, :creative, :reasoning]

  it "measures success rate by task type and sampling preset" do
    results = {}

    TASK_CONFIGS.each do |task_type, config|
      results[task_type] = {}

      SAMPLING_PRESETS.each do |preset|
        successes = 0
        10.times do
          response = model.generate(
            messages: [{ role: "user", content: config[:prompt] }],
            **SamplingConfig.preset(preset).to_provider_params(:openai)
          )
          successes += 1 if response.match?(config[:expected])
        end
        results[task_type][preset] = successes / 10.0
      end
    end

    # Log results for analysis
    puts "Sampling Benchmark Results:"
    puts results.to_yaml

    # Assert expected patterns
    expect(results[:tool_calling][:precise]).to be >= results[:tool_calling][:creative]
  end
end
```

### 4.5 Test Infrastructure Additions

```ruby
# lib/smolagents/testing/sampling_matchers.rb
module Smolagents
  module Testing
    module SamplingMatchers
      # Matcher for verifying sampling config was applied
      RSpec::Matchers.define :have_sampling_config do |expected|
        match do |model_call|
          expected.all? do |key, value|
            model_call[key] == value
          end
        end
      end

      # Matcher for valid tool call structure
      RSpec::Matchers.define :include_valid_tool_call do
        match do |response|
          response.tool_calls&.any? { |tc| tc[:name].present? }
        end
      end
    end
  end
end
```

### 4.6 CI Configuration

```yaml
# .github/workflows/real_model_tests.yml
name: Real Model Tests

on:
  schedule:
    - cron: '0 6 * * 1'  # Weekly on Monday
  workflow_dispatch:      # Manual trigger

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Run real model tests
        env:
          REAL_MODEL_TESTS: "1"
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          bundle exec rspec --tag real_model --format documentation
```

---

## Part 5: Implementation Roadmap

### Phase 1: Core Infrastructure
1. Create `Types::SamplingConfig` with presets
2. Add `sampling` field to `ModelConfig`
3. Implement `.sampling()` method in `ModelBuilder`

### Phase 2: Provider Integration
4. Update `OpenAI::RequestBuilder` to apply sampling params
5. Update `Anthropic::RequestBuilder` with provider-specific rules
6. Add support for any additional providers

### Phase 3: Testing
7. Unit tests for SamplingConfig
8. Builder integration tests
9. Request builder tests
10. MockModel integration tests

### Phase 4: Advanced Features
11. Phase-specific sampling at agent level
12. Runtime sampling override capability
13. Real model validation tests

### Phase 5: Documentation
14. Update CLAUDE.md with sampling examples
15. Add sampling guide to docs
16. Include benchmark results

---

## Part 6: Open Questions

1. **Default Behavior**: Should the default be `:balanced` or provider default?
   - Recommendation: Use `:balanced` (temperature: 0.5) for predictable behavior

2. **Provider Warnings**: Should we warn when using unsupported params for a provider?
   - Recommendation: Yes, emit warning event but don't fail

3. **Phase Detection**: How do we know which "phase" the agent is in?
   - Recommendation: Leverage existing multi-model purpose system (`:execution`, `:planning`, etc.)

4. **Gemini 3 Handling**: Should we auto-detect Gemini 3 and force temperature: 1.0?
   - Recommendation: Yes, with override option for advanced users

---

## Sources

### Research Papers
- arXiv:2506.07295 - "Exploring the Impact of Temperature on LLMs"
- arXiv:2502.05234 - "TURN: Automated Temperature Optimization"
- arXiv:2407.1082 - "Min-P Sampling for High Temperature Coherence"
- arXiv:2510.04678 - "Multi-Agent Tool-Integrated Research"

### Provider Documentation
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference/chat)
- [Anthropic Claude API](https://docs.anthropic.com/claude/reference/messages)
- [Google Gemini API](https://ai.google.dev/gemini-api/docs)
- [Mistral API Documentation](https://docs.mistral.ai/api)

### Framework Research
- [LangChain Agents](https://docs.langchain.com/oss/python/langchain/agents)
- [CrewAI Documentation](https://docs.crewai.com)
- [Anthropic Multi-Agent Research](https://www.anthropic.com/engineering/multi-agent-research-system)
- [smolagents (HuggingFace)](https://huggingface.co/docs/smolagents)

### Best Practices Guides
- [Prompt Engineering Guide](https://www.promptingguide.ai/introduction/settings)
- [Muxup LLM Parameter Quick Reference](https://muxup.com/2025q2/recommended-llm-parameter-quick-reference)
- [PromptHub Anthropic Best Practices](https://www.prompthub.us/blog/using-anthropic-best-practices-parameters-and-large-context-windows)
