# Actionable Feedback Design

## The Problem

The model needs clear guidance on what to do next. Current feedback is passive:
- "Rate limited" → OK, but then what?
- "No results found" → Should I try again? How?
- Long search results → What's important? Did I find what I need?

## Design Principle

Every tool observation should answer THREE questions:
1. **WHAT happened?** - Status of the tool call
2. **WHAT do you have?** - The actual result/data
3. **WHAT should you do next?** - Explicit suggested actions

## Feedback Templates

### SUCCESS - Got Good Results

```
✓ wikipedia found 2 results for "Ruby creator"

## Yukihiro Matsumoto
Yukihiro Matsumoto is a Japanese computer scientist... born April 14, 1965 in Osaka, Japan...

NEXT STEPS:
- If this answers your question → final_answer(answer: "extracted answer")
- If you need more detail → search for specific aspect like "Yukihiro Matsumoto birthplace"
```

### SUCCESS - Partial/Ambiguous Results

```
⚠ wikipedia found results but they may not directly answer your question

## The New York Times
The New York Times is headquartered at The New York Times Building in Midtown Manhattan...
(Note: No street address in this article)

NEXT STEPS:
- Try more specific search → wikipedia(query: "New York Times Building address")
- If you have enough info → final_answer(answer: "summarize what you found")
```

### ERROR - Rate Limited

```
✗ duckduckgo_search is rate limited

ALTERNATIVES:
- Try wikipedia instead → wikipedia(query: "your search terms")
- If you have results from other tools → final_answer with that info
- Wait and retry → duckduckgo_search(query: "...")
```

### ERROR - No Results

```
⚠ wikipedia found no results for "Xyzzyville population"

This topic may not exist or have a Wikipedia article.

NEXT STEPS:
- Try web search → duckduckgo_search(query: "Xyzzyville")
- Try alternate terms → wikipedia(query: "related term")
- If topic doesn't exist → final_answer(answer: "No information found about X")
```

### ERROR - Service Unavailable

```
✗ duckduckgo_search is temporarily unavailable

ALTERNATIVES:
- Use wikipedia for encyclopedic facts → wikipedia(query: "...")
- If you have results from other tools → final_answer with that info
```

## Implementation Strategy

### 1. Tool Result Wrapper

Create a `ToolFeedback` class that wraps results with context:

```ruby
class ToolFeedback
  def initialize(tool_name:, status:, result:, suggestions:)
    @tool_name = tool_name
    @status = status  # :success, :partial, :error
    @result = result
    @suggestions = suggestions
  end

  def to_observation
    [status_line, result_section, suggestions_section].compact.join("\n\n")
  end

  def status_line
    case @status
    when :success then "✓ #{@tool_name} succeeded"
    when :partial then "⚠ #{@tool_name} returned partial results"
    when :error then "✗ #{@tool_name} failed"
    end
  end

  def suggestions_section
    return nil if @suggestions.empty?
    "NEXT STEPS:\n" + @suggestions.map { |s| "- #{s}" }.join("\n")
  end
end
```

### 2. Smart Suggestions

Each tool can provide context-aware suggestions:

```ruby
class WikipediaSearchTool < SearchTool
  def suggest_next_steps(query:, results:, original_question:)
    if results.empty?
      ["Try duckduckgo_search(query: \"#{query}\")",
       "Try different search terms"]
    elsif results_seem_incomplete?(results, original_question)
      ["Search more specifically: wikipedia(query: \"#{suggest_refinement(query)}\")",
       "If this is enough, call final_answer"]
    else
      ["Extract the answer and call final_answer(answer: \"...\")",
       "If you need more detail, search for specific aspect"]
    end
  end
end
```

### 3. Error Feedback Enhancement

```ruby
def handle_tool_error(error, tool_call)
  suggestions = case error
                when RateLimitError
                  alternative_tools = @tools.keys - [tool_call.name]
                  [
                    *alternative_tools.map { |t| "Try #{t}(query: \"#{tool_call.arguments['query']}\")" },
                    "If you have results from other tools, call final_answer"
                  ]
                when ServiceUnavailableError
                  ["Try again in a moment", "Use other available tools"]
                else
                  ["Check your arguments", "Try a different approach"]
                end

  build_feedback(
    tool_name: tool_call.name,
    status: :error,
    result: error.message,
    suggestions: suggestions
  )
end
```

## Key Insight: Context Awareness

The feedback system should be aware of:
1. **What tools are available** - Suggest alternatives that exist
2. **What has been tried** - Don't suggest repeating failed attempts
3. **The original question** - Help verify if answer is complete
4. **What results exist** - Suggest using available data

## Measuring Success

After implementing actionable feedback:
1. Re-run the failure mode tests
2. Count how often model takes suggested action
3. Measure improvement in correct answers
4. Track reduction in search loops

## Priority Order

1. **Rate limit feedback** - Most common error, easy win
2. **No results feedback** - Help model recover
3. **Partial results detection** - Harder but high value
4. **Success verification prompts** - Prevent premature final_answer

## Open Questions

1. Should suggestions include the actual arguments? (More helpful but longer)
2. How verbose should success feedback be? (Don't want to overwhelm)
3. Should we track conversation state to avoid repeated suggestions?
