# Agent Failure Modes Analysis

Analysis from systematic testing of the smolagents-ruby agent system.

## Summary

| Category | Tests | Passed | Issues |
|----------|-------|--------|--------|
| Fact Retrieval | 4 | 3 | 1 false negative (test too strict) |
| Ambiguous | 3 | 1 | 2 questionable answers |
| Multi-step | 3 | 2 | 1 no output |
| Temporal | 3 | 2 | 1 rate limited |
| Edge Cases | 4 | 2 | 2 hallucinations |
| Tool-specific | 2 | 1 | 1 rate limited |

## Failure Modes Identified

### 1. HALLUCINATION - Confident Wrong Answers

**"The Office" Test:**
- Query: "Who plays the main character in The Office?"
- Answer: "Ryan Howard"
- Problem: Ryan Howard is a CHARACTER (played by B.J. Novak), not the main character's actor
- Correct: Steve Carell (Michael Scott) or Ricky Gervais (David Brent)
- Root cause: Model mixed up character names with actors, confident despite being wrong

**"Glorpzorbian Empire" Test:**
- Query: "Tell me about the Glorpzorbian Empire"
- Answer: "fictional empire from Iain M. Banks' Culture universe"
- Problem: Completely made up. This term doesn't exist anywhere.
- Root cause: Model confabulated rather than admitting ignorance

**Pattern:** Model generates plausible-sounding but incorrect answers when:
- Query involves entities that could be confused (characters vs actors)
- Query is about something that doesn't exist (invents connection to real things)
- Search results are partial or ambiguous

### 2. SEARCH LOOP - No Final Answer

**"Chain of Facts" Test:**
- Query: "What country is the birthplace of the creator of Ruby located in?"
- Expected: "Japan" (Matz → Osaka → Japan)
- Result: `no_output`
- Tool calls: `wikipedia, duckduckgo_search, wikipedia, duckduckgo_search, wikipedia, duckduckgo_search`
- Root cause: Model kept searching but never synthesized answer

**Pattern:** Multi-step reasoning queries can cause:
- Endless search loops without synthesis
- Model failing to recognize it has enough information
- No final_answer call despite having the data

### 3. RATE LIMITING - Tool Degradation

**Observed:** DuckDuckGo consistently rate-limits (202 status)
- Many queries fell back to Wikipedia only
- "Bitcoin price" query explicitly mentioned rate limiting in answer

**Impact:**
- Reduces tool diversity (Wikipedia-only answers)
- Model sometimes mentions rate limits in output (leaking internals)
- May cause incomplete answers when web search would help

### 4. OUTDATED INFORMATION

**"Apple Market Cap" in Long Query:**
- Answer included: "market cap was estimated to be $1 trillion" (2018 data)
- Current reality: Apple is worth ~$3 trillion
- Root cause: Wikipedia data lags, web search rate limited

**Pattern:** Temporal information from Wikipedia may be years old

### 5. AMBIGUITY HANDLING

**"Capital City" Test:**
- Query: "What is the capital?"
- Answer: "Washington, D.C."
- Observation: Model assumed US context without clarifying

**Pattern:** Model makes assumptions rather than asking for clarification
- Could be appropriate (US context reasonable)
- Could be wrong (user might mean different country)

## Successful Patterns

### What Works Well

1. **Simple fact lookup** - "Who founded Amazon?" → "Jeff Bezos" ✓
2. **Wikipedia strengths** - Scientific classification, historical dates ✓
3. **Current CEO** - "Tim Cook" found correctly ✓
4. **Comparative queries** - "Eiffel Tower vs Statue of Liberty" ✓
5. **Derived facts** - "Bill Gates age when Windows 1.0 released" → "30" ✓
6. **Admitting ignorance** - "Xyzzyville population" → "unable to find" ✓

### Tool Selection

- Wikipedia excels at: encyclopedic facts, history, science
- DuckDuckGo needed for: current events, prices, recent releases
- When DDG fails, Wikipedia provides acceptable fallback for most queries

### 6. QUESTION MISINTERPRETATION

**"The Office" Test (Run 2):**
- Query: "Who plays the main character in The Office?"
- Answer: "Michael Scott"
- Problem: Michael Scott is the CHARACTER, not the ACTOR (Steve Carell)
- Model confused "plays" (acts as) with the character name
- Root cause: Semantic parsing failure

**"Chain of Facts" Test:**
- Query: "What country is the birthplace..."
- Answer: "Yukihiro Matsumoto is Japanese"
- Problem: Question asked for COUNTRY, got NATIONALITY adjective
- Root cause: Incomplete answer extraction

### 7. SEARCH RESULT CONFUSION

**"Comparison" Test (Run 2):**
- Query: "Which is taller, Eiffel Tower or Statue of Liberty?"
- Answer: "Eiffel Tower is shorter than Statue of Unity"
- Problem: Answered wrong comparison! (Unity vs Liberty)
- Root cause: Wikipedia results for "Statue of Liberty height" returned page about statue replicas mentioning Statue of Unity
- Model got distracted by irrelevant but similar-sounding information

**Pattern:** When search results contain related but different entities:
- Statue of Liberty → search returns page mentioning Statue of Unity
- Model confuses the two entities
- Answers question about wrong entity entirely

### 8. DUCKDUCKGO BOT BLOCKING (ROOT CAUSE IDENTIFIED)

**Finding:** DuckDuckGo's lite interface blocks requests with "bot" in User-Agent.

Our User-Agent: `Smolagents/X.X Ruby/X.X (+url; bot)`

When DDG detects this:
- Returns 202 status with a challenge page (no results)
- The page has ~14KB of HTML but no actual search results
- This is NOT traditional rate limiting - it's bot blocking

**Evidence:**
- Raw Faraday requests without "bot" UA → 200 with results
- Requests with smolagents UA → 202 with challenge page

**Solutions:**
1. Use different search provider (Brave API, Google Custom Search)
2. Remove "bot" from User-Agent (less transparent)
3. Accept Wikipedia-only search (current workaround)

**Recommendation:** For production, use Brave Search API with an API key.
DDG lite is not viable for transparent bot use cases.

**Update (2026-01):** Even with browser User-Agent and headers, DDG detects
bots via sophisticated means:
- TLS fingerprinting (detecting Ruby's OpenSSL vs browser TLS stack)
- JavaScript challenge execution (anomaly.js with `cc=botnet`)
- Request timing patterns
- Cookie/session behavior

Simple HTTP requests cannot pass DDG's bot detection. Options:
1. Use Brave Search API (recommended, requires API key)
2. Use a headless browser (Ferrum/Puppeteer)
3. Accept Wikipedia-only search for no-API-key setups

## Root Cause Analysis

### Why Hallucination Happens

1. **Partial information** - Model has some context but fills gaps incorrectly
2. **Training data bleed** - Model's pre-training knowledge conflicts with search results
3. **Confidence calibration** - Model doesn't distinguish "pretty sure" from "certain"
4. **No self-verification** - Model doesn't check its answer against sources

### Why Search Loops Happen

1. **No planning step** - Model searches reactively, not strategically
2. **Missing synthesis trigger** - Model doesn't recognize "I have enough"
3. **Unclear stopping conditions** - When is searching done?

### Why Rate Limiting Hurts

1. **DuckDuckGo's 202 response** - Non-standard rate limit indicator
2. **No backoff/retry** - System doesn't wait and retry
3. **Falls back to Wikipedia** - But Wikipedia can't answer everything

## Recommendations

### Short-term Fixes

1. **Improve error messages** - ✅ Already done (encourage using other tools)
2. **Add rate limit backoff** - Wait and retry DDG after rate limit
3. **Test detection improvements** - "wrong_answer" false positive on Matz name

### Medium-term Improvements

1. **Planning step** - Before searching, plan what info is needed
2. **Synthesis prompting** - Encourage combining multiple sources
3. **Self-verification** - Have model check answer against sources
4. **Confidence indicators** - Distinguish certain vs uncertain answers

### Long-term Architecture

1. **Search strategy** - Different tools for different query types
2. **Query decomposition** - Break complex queries into sub-queries
3. **Answer validation** - Cross-reference multiple sources
4. **Graceful degradation** - Clear fallback hierarchy when tools fail

## Test Infrastructure Issues

### Bugs Found

1. **Error event handler** - `undefined method 'error'` suggests ErrorOccurred event uses different attribute name
2. **Step counter** - Always shows 0, callback not incrementing correctly
3. **String matching** - "Yukihiro 'Matz' Matsumoto" marked wrong vs "Yukihiro Matsumoto"

### Fixes Needed

- Check ErrorOccurred event structure
- Fix step counting in exploration script
- Use fuzzy matching for expected answers

## Critical Finding: Search Strategy Patterns

### The Pattern Recognition Problem

The model uses literal search terms instead of strategic queries:

| User Question | Model Searches | Should Search | Result |
|--------------|----------------|---------------|--------|
| "Address of NYT" | "NYT street address" | "New York Times Building" | ✗ Wrong |
| "Who plays X in The Office" | "The Office main character" | "The Office cast Steve Carell" | ✗ Character name |
| "What country is Matz from" | "Matz nationality" | "Yukihiro Matsumoto birthplace Japan" | ✗ "Japanese" |

### Why This Happens

1. **Literal translation** - Model converts question words to search terms literally
2. **Missing domain knowledge** - Doesn't know "address" → "Building" pattern
3. **No query reformulation** - Doesn't try alternative queries when results lack info

### Wikipedia-Specific Patterns

Wikipedia article structure affects what information is available:

- **Main article** (e.g., "The New York Times") → Overview, no detailed address
- **Building article** (e.g., "The New York Times Building") → Has street address
- **Cast article** (e.g., "List of The Office characters") → Has actor names
- **Person article** (e.g., "Yukihiro Matsumoto") → Has birthplace

### Proposed Solutions

**Option 1: Search Strategy Prompting**
Add to system prompt:
```
SEARCH STRATEGIES:
- For addresses: search "[Company] Building" or "[Company] headquarters building"
- For actors: search "[Show] cast" or "[Character name] actor"
- For locations: search "[Person] birthplace" not "[Person] nationality"
```

**Option 2: Smart Query Suggestion**
When results don't contain expected info type:
```
Results found but may not have address info.
TRY: wikipedia(query: "New York Times Building") for building details
```

**Option 3: Entity-Following Hints**
When results mention a named entity that could be searched:
```
Note: Results mention "The New York Times Building" - search this for more details
```

### Recommended Implementation Order

1. **Immediate**: Add search strategies to system prompt
2. **Next**: Smart query suggestions based on question type
3. **Later**: Entity-following hints in results

### 9. UTF-8 ENCODING ERRORS IN TOOL RESPONSES

**Observed (2026-01-15):**
```
ERROR -- : Step error | error=source sequence is illegal/malformed utf-8
Switching openai_api from green to red because JSON::GeneratorError source sequence is illegal/malformed utf-8
```

**Root Cause:**
- ArXiv API returns some papers with non-UTF-8 characters in abstracts/titles
- When serializing tool output to JSON for model context, `JSON::GeneratorError` raised
- The error propagates up and triggers circuit breaker

**Impact:**
- Circuit breaker incorrectly treats encoding errors as service failures
- After 3 encoding errors, circuit opens and blocks ALL requests for cool-off period
- Agent cannot recover even though the underlying API is healthy

**Pattern:**
1. Tool fetches external data with malformed encoding
2. JSON serialization fails during message construction
3. Circuit breaker counts as failure
4. Circuit opens → "Service unavailable (circuit open): openai_api"
5. All subsequent tool calls fail until circuit cools off

**Solutions:**
1. **UTF-8 sanitization** - Clean/replace malformed bytes before JSON serialization
   ```ruby
   text.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
   ```
2. **Circuit breaker categorization** - Don't count encoding errors as service failures
3. **Graceful degradation** - Return sanitized content instead of failing

### 10. CIRCUIT BREAKER MISCATEGORIZATION

**Problem:** Circuit breaker opens for the wrong reasons.

**Observed Categories that SHOULD trigger circuit:**
- HTTP 500, 502, 503, 504 (service errors)
- Connection timeout
- DNS resolution failure
- TCP connection refused

**Observed Categories that SHOULD NOT trigger circuit:**
- UTF-8 encoding errors (local serialization issue)
- JSON parsing errors (response format issue)
- Rate limit 429 (should use backoff, not circuit break)
- HTTP 400 Bad Request (client error, not service issue)

**Current Behavior:**
Any exception in the tool call path increments failure count → circuit opens.

**Recommended Behavior:**
```ruby
CIRCUIT_BREAKING_ERRORS = [
  Faraday::ConnectionFailed,
  Faraday::TimeoutError,
  ServiceUnavailableError,  # 503
  BadGatewayError,          # 502
].freeze

NON_CIRCUIT_ERRORS = [
  JSON::GeneratorError,     # Encoding issues
  JSON::ParserError,        # Response parsing
  RateLimitError,           # Use retry with backoff
  BadRequestError,          # Client error
].freeze
```

---

## Implementation Status

### Completed
- ✅ Actionable error messages with NEXT STEPS
- ✅ Rate limit feedback with alternative tool suggestions
- ✅ Success/failure status indicators (✓/✗/⚠)
- ✅ Documented failure modes and patterns

### Next Steps
- [ ] Add search strategies to system prompt
- [ ] Implement entity-following hints
- [ ] Test with prompt improvements
- [ ] UTF-8 sanitization in tool response handling
- [ ] Circuit breaker error categorization refactor
- [ ] Separate rate limit handling from circuit breaker
