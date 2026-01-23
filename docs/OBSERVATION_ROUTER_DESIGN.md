# Observation Router Design Analysis

## Revised Understanding

The observation router serves **two complementary purposes**:

1. **Semantic Understanding** - Help the LLM reason about what the tool returned and its relevance to the task
2. **Code Enablement** - Provide the data structure info needed to write correct access code

The current design fails because it provides #1 (summary) while destroying #2 (structure).
The solution isn't to remove summaries - it's to provide **both**.

## Problem Statement

For **code agents**, the current ObservationRouter design has a fundamental flaw:

1. Agent code stores results in variables: `@results = search(query: "...")`
2. Results are actual data: `[{title: "...", link: "..."}]`
3. ObservationRouter summarizes: `"[SUMMARY_ONLY] Found 2 results about Ruby..."`
4. LLM sees only the summary, not the data structure
5. LLM writes code assuming wrong structure → runtime errors

The router was designed for ReAct-style agents where the LLM reasons about text,
not code agents where the LLM needs to know data shapes to write correct code.

## Options

### Option A: Disable for Code Agents (Quick Fix)

```ruby
# Current workaround
agent.route_observations(enabled: false)
```

**Pros**: Works immediately, simple
**Cons**: Large outputs bloat context, no intelligent truncation

### Option B: Smart Truncation (No LLM)

Replace LLM routing with deterministic truncation that preserves structure:

```ruby
module SmartTruncation
  def truncate_observation(output, max_chars: 2000)
    case output
    when Array
      "Array[#{output.size}]: #{truncate_array(output, max_chars)}"
    when Hash
      "Hash{#{output.keys.join(', ')}}: #{truncate_hash(output, max_chars)}"
    else
      output.to_s.slice(0, max_chars)
    end
  end

  def truncate_array(arr, max)
    return "[]" if arr.empty?
    first = arr.first.inspect.slice(0, max / 2)
    "[\n  #{first},\n  ... #{arr.size - 1} more\n]"
  end
end
```

**Pros**: Fast, preserves data structure, predictable
**Cons**: Not "intelligent", may miss what's relevant

### Option C: Structured Observation for Code Agents (Recommended)

Create observations that describe **what was stored and its shape**:

```ruby
module CodeAgentObservation
  def build_code_observation(variable_name, value)
    <<~OBS
      Stored in #{variable_name}:
        Type: #{value.class}
        #{describe_structure(value)}
        Sample: #{sample_value(value)}

      Access with: #{variable_name}[0]["key"] or #{variable_name}.first
    OBS
  end

  def describe_structure(value)
    case value
    when Array
      return "Empty array" if value.empty?
      "Array of #{value.size} #{value.first.class}s"
    when Hash
      "Hash with keys: #{value.keys.map(&:inspect).join(', ')}"
    else
      value.class.to_s
    end
  end

  def sample_value(value, max: 500)
    JSON.pretty_generate(value).slice(0, max)
  rescue
    value.inspect.slice(0, max)
  end
end
```

Example output:
```
Stored in @search_results:
  Type: Array
  Array of 2 Hashes
  Sample: [
    {"title": "Ruby 4.0 Released - New Features", "link": "https://..."},
    {"title": "What's New in Ruby 4.0", ...}
  ]

Access with: @search_results[0]["title"] or @search_results.first
```

**Pros**:
- LLM knows exact data structure
- Can write correct code immediately
- No extra LLM calls
- Preserves the "helpful summary" intent

**Cons**:
- More complex implementation
- Need to track what variables were assigned

### Option D: Keep Router, Change Default Decision

Change default from `:summary_only` to `:full_output` for code agents:

```ruby
def code_agent_router
  lambda do |tool_name, output, task|
    # For code agents, always include full output but add structure hints
    RoutingResult.new(
      decision: :full_output,
      summary: describe_structure(output),
      relevance: 1.0,
      next_action: nil,
      full_output: output
    )
  end
end
```

**Pros**: Minimal change, uses existing infrastructure
**Cons**: Still have the extra complexity without the benefit

### Option E: Remove ObservationRouter Entirely

Delete the feature. It's premature optimization that hurts code agents.

```ruby
# Delete:
# - lib/smolagents/concerns/agents/observation_router.rb
# - lib/smolagents/concerns/agents/observation_router/
# - Related builder methods
```

**Pros**: Simpler codebase, one less thing to configure wrong
**Cons**: Loses potential for future smart routing

## Recommendation

**For immediate fix**: Option A (disable routing) - already works

**For proper solution**: Option C (Structured Observation)

The key insight is that for code agents, we don't need to "summarize" - we need to
**describe the data structure** so the LLM can write correct access code.

This is fundamentally different from ReAct agents where you might actually want
to summarize long text passages.

## Implementation Plan

1. Add `CodeAgentObservation` module with structure-aware formatting
2. Change `build_observations` to use it for code agents
3. Remove or deprecate the LLM-based router (or keep for future ReAct support)
4. Default to structure-preserving observations

## When Would LLM Routing Make Sense?

- ReAct text agents reasoning about long documents
- Multi-modal agents processing images/audio descriptions
- Agents with very limited context windows
- When tool outputs are truly unstructured prose

For code agents with structured tool outputs, LLM routing alone is counterproductive.

---

## Revised Design: Hybrid Observations

### The Ideal Observation Format

An observation should provide **both** semantic understanding AND structural access:

```
┌─────────────────────────────────────────────────────────────────┐
│ OBSERVATION                                                      │
├─────────────────────────────────────────────────────────────────┤
│ ## Data Structure                                                │
│ @search_results: Array[2] of Hash                               │
│   Keys: "title", "link", "description"                          │
│   Access: @search_results[0]["title"]                           │
│                                                                  │
│ ## Summary                                                       │
│ Found 2 results about Ruby 4.0:                                 │
│ 1. Official release notes highlighting pattern matching          │
│ 2. Community guide to new features                              │
│                                                                  │
│ ## Relevance: High                                              │
│ Directly answers the question about Ruby 4.0.                   │
│                                                                  │
│ ## Suggested Next Step                                          │
│ Extract first result title: @search_results.first["title"]      │
└─────────────────────────────────────────────────────────────────┘
```

### Architecture: Separation of Concerns

```
Tool Execution
      │
      ▼
┌─────────────────┐
│ Data Structure  │◄── Deterministic (no LLM needed)
│ Formatter       │    - Type, keys, shape
│                 │    - Sample values
│                 │    - Access patterns
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Semantic        │◄── LLM-powered (optional, oneshot)
│ Summarizer      │    - What was found
│                 │    - Relevance to task
│                 │    - Suggested next action
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Combined        │
│ Observation     │──► Agent's context
└─────────────────┘
```

### Implementation

```ruby
module Smolagents
  module Concerns
    module ObservationRouter
      # Hybrid observation builder for code agents.
      # Combines deterministic structure info with optional LLM summary.
      class HybridObservation
        def initialize(summarizer_model: nil)
          @summarizer = summarizer_model
        end

        def build(variable_assignments, task_context)
          parts = []

          # Part 1: Deterministic data structure (always included)
          parts << build_structure_section(variable_assignments)

          # Part 2: LLM summary (if summarizer configured)
          if @summarizer
            parts << build_summary_section(variable_assignments, task_context)
          end

          parts.compact.join("\n\n")
        end

        private

        # Deterministic - no LLM needed
        def build_structure_section(assignments)
          return nil if assignments.empty?

          lines = ["## Data Stored"]
          assignments.each do |var_name, value|
            lines << format_variable(var_name, value)
          end
          lines.join("\n")
        end

        def format_variable(name, value)
          case value
          when Array
            format_array(name, value)
          when Hash
            format_hash(name, value)
          else
            "#{name}: #{value.class} = #{value.inspect.slice(0, 200)}"
          end
        end

        def format_array(name, arr)
          return "#{name}: [] (empty array)" if arr.empty?

          element_type = arr.first.class.name
          keys = arr.first.is_a?(Hash) ? arr.first.keys.map(&:inspect).join(", ") : nil
          sample = arr.first.inspect.slice(0, 300)

          lines = ["#{name}: Array[#{arr.size}] of #{element_type}"]
          lines << "  Keys: #{keys}" if keys
          lines << "  Sample: #{sample}"
          lines << "  Access: #{name}[0] or #{name}.first"
          lines.join("\n")
        end

        def format_hash(name, hash)
          keys = hash.keys.map(&:inspect).join(", ")
          sample = hash.inspect.slice(0, 300)

          lines = ["#{name}: Hash"]
          lines << "  Keys: #{keys}"
          lines << "  Sample: #{sample}"
          lines << "  Access: #{name}[\"key\"] or #{name}[:key]"
          lines.join("\n")
        end

        # LLM-powered summary (oneshot, focused prompt)
        def build_summary_section(assignments, task_context)
          return nil unless @summarizer

          prompt = build_summary_prompt(assignments, task_context)
          response = @summarizer.generate([ChatMessage.user(prompt)])

          # Parse structured response
          parse_summary_response(response.content)
        rescue => e
          "## Summary\n[Summarizer error: #{e.message}]"
        end

        def build_summary_prompt(assignments, task)
          data_description = assignments.map { |k, v|
            "#{k}: #{v.inspect.slice(0, 500)}"
          }.join("\n")

          <<~PROMPT
            Summarize this tool output for an AI agent working on a task.
            Be concise (2-3 sentences). Focus on relevance to the task.

            TASK: #{task}

            DATA RETURNED:
            #{data_description}

            Respond in this exact format:
            SUMMARY: [What was found, 1-2 sentences]
            RELEVANCE: [High/Medium/Low] - [Why]
            NEXT_STEP: [What the agent should do next]
          PROMPT
        end

        def parse_summary_response(content)
          lines = []

          if content =~ /SUMMARY:\s*(.+?)(?=RELEVANCE:|$)/mi
            lines << "## Summary\n#{$1.strip}"
          end

          if content =~ /RELEVANCE:\s*(.+?)(?=NEXT_STEP:|$)/mi
            lines << "## Relevance\n#{$1.strip}"
          end

          if content =~ /NEXT_STEP:\s*(.+?)$/mi
            lines << "## Suggested Next Step\n#{$1.strip}"
          end

          lines.empty? ? "## Summary\n#{content}" : lines.join("\n\n")
        end
      end
    end
  end
end
```

### Configuration

```ruby
# Option 1: Structure only (fast, no extra LLM calls)
agent = Smolagents.agent
  .model { main_model }
  .observe(:structure_only)  # Just data structure, no summary
  .build

# Option 2: Structure + summary using same model
agent = Smolagents.agent
  .model { main_model }
  .observe(:with_summary)  # Uses main model for summary
  .build

# Option 3: Structure + summary using fast model
agent = Smolagents.agent
  .model { main_model }
  .observe(:with_summary) { OpenAIModel.lm_studio("gemma-3n") }
  .build

# Option 4: Disable entirely (raw output)
agent = Smolagents.agent
  .model { main_model }
  .observe(false)
  .build
```

### Benefits of Hybrid Approach

1. **Structure is always deterministic** - no LLM variability for data access
2. **Summary is optional** - can disable for speed or enable for better reasoning
3. **Summary uses focused prompt** - oneshot, not a "routing decision"
4. **Separation of concerns** - structure formatter vs semantic summarizer
5. **Graceful degradation** - if summarizer fails, structure still works

### Migration Path

1. **Phase 1**: Add `HybridObservation` alongside existing router
2. **Phase 2**: Make hybrid the default for code agents
3. **Phase 3**: Deprecate old `ModelRouter` (keep for backward compat)
4. **Phase 4**: Remove old router in next major version

### When to Use Each Mode

| Mode | Use Case | Latency | Token Cost |
|------|----------|---------|------------|
| `:structure_only` | Fast iteration, simple tools | Lowest | None |
| `:with_summary` (same model) | Complex tasks, needs reasoning help | Medium | +1 call/tool |
| `:with_summary` (fast model) | Best of both worlds | Low | +1 cheap call |
| `false` (disabled) | Debugging, very large outputs | Lowest | None |
