RSpec.describe Smolagents::PatternMatching do
  describe ".extract_code" do
    it "extracts code from ruby code blocks" do
      text = "Here's some code:\n```ruby\ndefine_tool(:search) do\n  puts 'hello'\nend\n```"
      code = described_class.extract_code(text)

      expect(code).to eq("define_tool(:search) do\n  puts 'hello'\nend")
    end

    it "extracts code from generic code blocks" do
      text = "Example:\n```\ndef hello\n  puts 'world'\nend\n```"
      code = described_class.extract_code(text)

      expect(code).to eq("def hello\n  puts 'world'\nend")
    end

    it "extracts code from HTML-style code tags" do
      text = "Code: <code>x = calculate(expression: \"1 + 2\")</code>"
      code = described_class.extract_code(text)

      expect(code).to eq("x = calculate(expression: \"1 + 2\")")
    end

    it "handles multiline HTML code tags" do
      text = "<code>def greet\n  puts 'hi'\nend</code>"
      code = described_class.extract_code(text)

      expect(code).to eq("def greet\n  puts 'hi'\nend")
    end

    it "returns nil when no code blocks found" do
      text = "Just plain text with no code"
      code = described_class.extract_code(text)

      expect(code).to be_nil
    end

    it "prefers ruby code blocks over generic ones" do
      text = "```ruby\nresult = calculate(expression: \"1+2\")\n```\n```\ngeneric\n```"
      code = described_class.extract_code(text)

      expect(code).to eq("result = calculate(expression: \"1+2\")")
    end

    # Small model variations
    context "with small model formatting variations" do
      it "handles missing newline after triple backticks" do
        text = "```rubyresult = calculate(expression: \"5 * 3\")\n```"
        code = described_class.extract_code(text)

        expect(code).to eq("result = calculate(expression: \"5 * 3\")")
      end

      it "handles extra whitespace after language" do
        text = "```ruby   \nfinal_answer(answer: 42)\n```"
        code = described_class.extract_code(text)

        expect(code).to eq("final_answer(answer: 42)")
      end

      it "handles uppercase Code tags" do
        text = "<Code>puts calculate(expression: \"10 / 2\")</Code>"
        code = described_class.extract_code(text)

        expect(code).to eq("puts calculate(expression: \"10 / 2\")")
      end

      it "handles rb shorthand" do
        text = "```rb\nresult = search(query: \"test\")\n```"
        code = described_class.extract_code(text)

        expect(code).to eq("result = search(query: \"test\")")
      end

      it "handles code blocks without language tag" do
        text = "Thought: I'll calculate.\n```\nfinal_answer(answer: 100)\n```"
        code = described_class.extract_code(text)

        expect(code).to eq("final_answer(answer: 100)")
      end

      it "handles xml-style ruby tags" do
        text = "<ruby>x = calculate(expression: \"2**8\")</ruby>"
        code = described_class.extract_code(text)

        expect(code).to eq("x = calculate(expression: \"2**8\")")
      end
    end

    # Validation
    context "when validating code" do
      it "rejects prose that looks like text" do
        prose = "The answer to this question is that we need to understand the " \
                "fundamental principles of mathematics before we can calculate anything properly."
        text = "```\n#{prose}\n```"
        code = described_class.extract_code(text)

        expect(code).to be_nil
      end

      it "accepts code with method calls" do
        text = "```\nresult = calculate(expression: \"1+1\")\nputs result\n```"
        code = described_class.extract_code(text)

        expect(code).to include("calculate")
      end

      it "accepts code with final_answer" do
        text = "```\nfinal_answer(answer: \"Paris\")\n```"
        code = described_class.extract_code(text)

        expect(code).to eq("final_answer(answer: \"Paris\")")
      end

      it "accepts code with assignments" do
        text = "```\nx = 42\ny = x * 2\n```"
        code = described_class.extract_code(text)

        expect(code).to eq("x = 42\ny = x * 2")
      end
    end

    # OpenAI Harmony format (gpt-oss models)
    context "with OpenAI Harmony format (gpt-oss models)" do
      it "extracts tool calls from harmony format" do
        text = '<|channel|>commentary to=search<|message|>{"query": "hello world"}'
        code = described_class.extract_code(text)

        expect(code).to eq('result = search(query: "hello world")')
      end

      it "handles gpt-oss-20b actual output format" do
        text = '<|channel|>commentary to=searxng_search code<|message|>{"query":"trending programming languages 2026"}'
        code = described_class.extract_code(text)

        expect(code).to eq('result = searxng_search(query: "trending programming languages 2026")')
      end

      it "handles complex harmony output with multiple markers" do
        text = '<|start|>assistant<|channel|>commentary to=searxng_search code<|message|>{"query":"Ruby 4.0 features"}'
        code = described_class.extract_code(text)

        expect(code).to eq('result = searxng_search(query: "Ruby 4.0 features")')
      end

      it "handles tool calls with multiple arguments" do
        text = '<|channel|>commentary to=weather<|message|>{"city": "Tokyo", "units": "celsius"}'
        code = described_class.extract_code(text)

        expect(code).to include("weather(")
        expect(code).to include('city: "Tokyo"')
        expect(code).to include('units: "celsius"')
      end

      it "prefers harmony format over embedded code blocks" do
        # If harmony format is detected, use that even if there might be code blocks
        text = '<|channel|>commentary to=search<|message|>{"query": "test"}'
        code = described_class.extract_code(text)

        expect(code).to eq('result = search(query: "test")')
      end

      it "converts harmony final answer to code" do
        # Harmony final answer takes precedence - converts to final_answer call
        text = "<|channel|>final<|message|>The answer is 42\n```ruby\nputs 'hello'\n```"
        code = described_class.extract_code(text)

        expect(code).to eq('final_answer(answer: "The answer is 42")')
      end
    end

    # Special token handling
    context "with model-specific special tokens" do
      it "handles medgemma unused tokens" do
        text = "<unused94>thought\nSome reasoning\n<unused95>```ruby\nresult = search(query: \"test\")\n```"
        code = described_class.extract_code(text)

        expect(code).to eq('result = search(query: "test")')
      end

      it "strips generic special tokens before extraction" do
        text = "<|im_start|>assistant\n```ruby\nfinal_answer(answer: 42)\n```<|im_end|>"
        code = described_class.extract_code(text)

        expect(code).to eq("final_answer(answer: 42)")
      end
    end

    # Thinking tag handling (Qwen, Phi, Mistral models)
    context "with thinking tags" do
      it "strips <think> tags and extracts code" do
        text = "<think>Let me reason about this...</think>\n```ruby\nresult = search(query: \"test\")\n```"
        code = described_class.extract_code(text)

        expect(code).to eq('result = search(query: "test")')
      end

      it "strips <reasoning> tags and extracts code" do
        text = "<reasoning>Working through this problem...</reasoning>```ruby\nfinal_answer(answer: 42)\n```"
        code = described_class.extract_code(text)

        expect(code).to eq("final_answer(answer: 42)")
      end
    end

    # [TOOL_CALLS] suffix stripping (granite-tiny models)
    context "with [TOOL_CALLS] suffix" do
      it "strips TOOL_CALLS suffix and extracts code from ruby block" do
        text = <<~TEXT
          Thought: Search for trending languages.
          ```ruby
          data = duckduckgo_search(query: "trending languages")
          final_answer(answer: data)
          ```
          [TOOL_CALLS]duckduckgo_search{"query": "trending languages"}[TOOL_CALLS]final_answer{"answer": "Python"}
        TEXT
        code = described_class.extract_code(text)

        expect(code).to eq(%(data = duckduckgo_search(query: "trending languages")\nfinal_answer(answer: data)))
        expect(code).not_to include("[TOOL_CALLS]")
      end
    end

    # XML tool call format (Qwen with tools)
    context "with XML tool_call format" do
      it "extracts tool_call XML and converts to Ruby" do
        text = '<tool_call>{"name": "search", "arguments": {"query": "hello world"}}</tool_call>'
        code = described_class.extract_code(text)

        expect(code).to eq('result = search(query: "hello world")')
      end

      it "handles tool_call with multiple arguments" do
        text = '<tool_call>{"name": "weather", "arguments": {"city": "Tokyo", "units": "celsius"}}</tool_call>'
        code = described_class.extract_code(text)

        expect(code).to include("weather(")
        expect(code).to include('city: "Tokyo"')
        expect(code).to include('units: "celsius"')
      end
    end

    # Markdown tool_request format
    context "with tool_request markdown format" do
      it "extracts tool_request and converts to Ruby" do
        text = "```tool_request\n{\"name\": \"get_data\", \"arguments\": {\"id\": 123}}\n```"
        code = described_class.extract_code(text)

        expect(code).to eq("result = get_data(id: 123)")
      end
    end
  end

  describe ".looks_like_ruby?" do
    it "returns true for method definitions" do
      expect(described_class.looks_like_ruby?("def foo\n  bar\nend")).to be true
    end

    it "returns true for puts statements" do
      expect(described_class.looks_like_ruby?("puts 'hello'")).to be true
    end

    it "returns true for method calls with keyword args" do
      expect(described_class.looks_like_ruby?("calculate(expression: \"1+1\")")).to be true
    end

    it "returns true for assignments" do
      expect(described_class.looks_like_ruby?("x = 42")).to be true
    end

    it "returns true for blocks" do
      expect(described_class.looks_like_ruby?("[1,2,3].each do |x| puts x end")).to be true
    end

    it "returns true for final_answer calls" do
      expect(described_class.looks_like_ruby?("final_answer(answer: result)")).to be true
    end

    it "returns false for empty strings" do
      expect(described_class.looks_like_ruby?("")).to be false
    end

    it "returns false for nil" do
      expect(described_class.looks_like_ruby?(nil)).to be false
    end

    it "returns false for short strings" do
      expect(described_class.looks_like_ruby?("x")).to be false
    end

    it "returns false for prose-like text" do
      prose = "This is a long sentence that describes what we should do next in order to solve the problem at hand."
      expect(described_class.looks_like_ruby?(prose)).to be false
    end
  end

  describe ".extract_json" do
    it "extracts JSON from json code blocks" do
      text = "Response:\n```json\n{\"key\": \"value\", \"number\": 42}\n```"
      data = described_class.extract_json(text)

      expect(data).to eq({ "key" => "value", "number" => 42 })
    end

    it "extracts JSON from plain text" do
      text = "The result is {\"success\": true, \"count\": 3}"
      data = described_class.extract_json(text)

      expect(data).to eq({ "success" => true, "count" => 3 })
    end

    it "extracts complex nested JSON" do
      text = '{
        "user": {
          "name": "Alice",
          "roles": ["admin", "user"]
        },
        "active": true
      }'
      data = described_class.extract_json(text)

      expect(data).to eq({
                           "user" => {
                             "name" => "Alice",
                             "roles" => %w[admin user]
                           },
                           "active" => true
                         })
    end

    it "returns nil for invalid JSON" do
      text = "Not valid: {broken json"
      data = described_class.extract_json(text)

      expect(data).to be_nil
    end

    it "returns nil when no JSON found" do
      text = "Plain text with no JSON structure"
      data = described_class.extract_json(text)

      expect(data).to be_nil
    end

    it "handles JSON with special characters" do
      text = '```json\n{"message": "Hello, \\"world\\"!"}\n```'
      data = described_class.extract_json(text)

      expect(data).to eq({ "message" => "Hello, \"world\"!" })
    end
  end

  describe ".categorize_error" do
    it "categorizes rate limit errors" do
      error = Faraday::TooManyRequestsError.new("Too many requests")
      category = described_class.categorize_error(error)

      expect(category).to eq(:rate_limit)
    end

    it "categorizes errors by message pattern for rate limits" do
      error = StandardError.new("Rate limit exceeded")
      category = described_class.categorize_error(error)

      expect(category).to eq(:rate_limit)
    end

    it "categorizes timeout errors" do
      error = Faraday::TimeoutError.new("Request timeout")
      category = described_class.categorize_error(error)

      expect(category).to eq(:timeout)
    end

    it "categorizes timeout by message pattern" do
      error = StandardError.new("Connection timeout after 30s")
      category = described_class.categorize_error(error)

      expect(category).to eq(:timeout)
    end

    it "categorizes authentication errors" do
      error = Faraday::UnauthorizedError.new("Unauthorized")
      category = described_class.categorize_error(error)

      expect(category).to eq(:authentication)
    end

    it "categorizes auth errors by message pattern" do
      error = StandardError.new("Invalid API key provided")
      category = described_class.categorize_error(error)

      expect(category).to eq(:authentication)
    end

    it "returns :unknown for uncategorized errors" do
      error = StandardError.new("Something weird happened")
      category = described_class.categorize_error(error)

      expect(category).to eq(:unknown)
    end
  end

  describe "ChatMessage pattern matching" do
    it "supports pattern matching via Data.define" do
      message = Smolagents::ChatMessage.assistant("Hello", tool_calls: nil)

      matched = case message
                in Smolagents::ChatMessage[role: :assistant, content: String]
                  :matched
                else
                  :not_matched
                end

      expect(matched).to eq(:matched)
    end
  end

  # Malformed model outputs - models that add text after final_answer
  describe "malformed model outputs" do
    context "with text after final_answer" do
      it "extracts final_answer with trailing explanation" do
        text = "final_answer(answer: 50) And here is my reasoning for this answer."
        code = described_class.extract_code(text)

        expect(code).to eq("final_answer(answer: 50)")
      end

      it "extracts final_answer with trailing newline and text" do
        text = "final_answer(answer: 50)\nThe calculation shows that 25*4-50=50"
        code = described_class.extract_code(text)

        expect(code).to eq("final_answer(answer: 50)")
      end

      it "extracts final_answer with comment" do
        text = "final_answer(answer: 50) # This is the result"
        code = described_class.extract_code(text)

        expect(code).to eq("final_answer(answer: 50)")
      end

      it "extracts string answer with trailing text" do
        text = 'final_answer(answer: "Paris") because Paris is the capital of France'
        code = described_class.extract_code(text)

        expect(code).to eq('final_answer(answer: "Paris")')
      end

      it "extracts variable answer with trailing text" do
        text = "final_answer(answer: result) and that completes the task"
        code = described_class.extract_code(text)

        expect(code).to eq("final_answer(answer: result)")
      end

      it "handles nested parens in answer with trailing text" do
        text = "final_answer(answer: calculate(1+2)) The answer is 3"
        code = described_class.extract_code(text)

        expect(code).to eq("final_answer(answer: calculate(1+2))")
      end
    end

    context "with text after code block" do
      it "extracts code from block with trailing explanation" do
        text = <<~TEXT
          ```ruby
          final_answer(answer: 50)
          ```
          This answer is correct because 25 * 4 = 100, and 100 - 50 = 50.
        TEXT
        code = described_class.extract_code(text)

        expect(code).to eq("final_answer(answer: 50)")
      end

      it "extracts code from block with trailing code-like text" do
        text = <<~TEXT
          ```ruby
          result = calculate(expression: "25 * 4")
          final_answer(answer: result - 50)
          ```
          Note: You could also write this as calculate(expression: "25 * 4 - 50")
        TEXT
        code = described_class.extract_code(text)

        expect(code).to include("calculate")
        expect(code).to include("final_answer")
      end
    end

    context "with malformed code blocks" do
      it "handles missing closing backticks" do
        text = "```ruby\nfinal_answer(answer: 42)\n"
        # This should still try to extract something useful
        code = described_class.extract_code(text)

        # May or may not extract - but should not crash
        expect { code }.not_to raise_error
      end

      it "handles extra whitespace everywhere" do
        text = "```ruby  \n  final_answer( answer:   50  )  \n```"
        code = described_class.extract_code(text)

        expect(code).to include("final_answer")
        expect(code).to include("50")
      end
    end

    context "with multiple final_answer calls" do
      it "extracts the first final_answer" do
        text = <<~TEXT
          final_answer(answer: 50) This is wrong
          Actually, final_answer(answer: 100) This is right
        TEXT
        code = described_class.extract_code(text)

        expect(code).to eq("final_answer(answer: 50)")
      end
    end

    context "with model-specific malformed outputs" do
      it "handles granite model output with calculation and explanation" do
        # Real granite model output pattern
        text = <<~TEXT
          Thought: Calculate 25 times 4 and then subtract 50 from the result.
          ```ruby
          intermediate_result = calculate(expression: '25 * 4')
          final_result = calculate(expression: "\#{intermediate_result} - 50")
          final_answer(answer: final_result)
          ```
          The intermediate result is 100, and after subtracting 50, we get 50.
        TEXT
        code = described_class.extract_code(text)

        expect(code).to include("calculate")
        expect(code).to include("final_answer")
      end

      it "handles LFM model verbose output" do
        text = <<~TEXT
          I'll solve this step by step.

          First, I calculate 25 * 4:
          ```ruby
          step1 = calculate(expression: "25 * 4")
          ```

          Then subtract 50:
          ```ruby
          step2 = calculate(expression: "100 - 50")
          final_answer(answer: step2)
          ```

          The final answer is 50.
        TEXT
        code = described_class.extract_code(text)

        # Should get code from one of the blocks
        expect(code).not_to be_nil
      end

      it "combines multiple separate code blocks into one" do
        # Real granite-4.0-h-small output pattern - multiple separate blocks
        text = <<~TEXT
          Thought: Calculate 25 * 4 using the calculate tool.
          ```ruby
          result1 = calculate(expression: '25 * 4')
          ```

          Thought: Subtract 50 from the previous result using the calculate tool.
          ```ruby
          result2 = calculate(expression: "\#{result1} - 50")
          ```

          Thought: Return the final result with final_answer.
          ```ruby
          final_answer(answer: result2)
          ```
        TEXT
        code = described_class.extract_code(text)

        # Should combine all three blocks
        expect(code).to include("result1 = calculate")
        expect(code).to include("result2 = calculate")
        expect(code).to include("final_answer(answer: result2)")
      end
    end
  end

  describe ".extract_balanced_value" do
    it "extracts simple value" do
      expect(described_class.extract_balanced_value("50)")).to eq("50")
    end

    it "extracts string value" do
      expect(described_class.extract_balanced_value('"hello"))')).to eq('"hello"')
    end

    it "extracts value with nested parens" do
      expect(described_class.extract_balanced_value("foo(bar)) extra")).to eq("foo(bar)")
    end

    it "handles escaped quotes in strings" do
      expect(described_class.extract_balanced_value('"say \\"hi\\"") more')).to eq('"say \\"hi\\""')
    end

    it "returns nil for empty input" do
      expect(described_class.extract_balanced_value("")).to be_nil
      expect(described_class.extract_balanced_value(nil)).to be_nil
    end
  end

  describe ".clean_answer_value" do
    it "removes trailing comments" do
      expect(described_class.clean_answer_value("50 # result")).to eq("50")
    end

    it "removes trailing explanatory text" do
      expect(described_class.clean_answer_value("50 and that is the answer")).to eq("50")
    end

    it "preserves the core value" do
      expect(described_class.clean_answer_value('"Paris"')).to eq('"Paris"')
    end
  end

  describe "integration examples" do
    it "combines extraction and pattern matching" do
      response_text = "Here's the solution:\n```ruby\nfinal_answer(answer: 42)\n```"
      code = described_class.extract_code(response_text)

      result = if code =~ /final_answer\(.*?(\d+)/
                 { type: :final, value: Regexp.last_match(1).to_i }
               elsif code.include?("search(")
                 { type: :search }
               else
                 { type: :unknown }
               end

      expect(result).to eq({ type: :final, value: 42 })
    end

    it "handles error categorization in retry logic" do
      errors_by_category = Hash.new { |h, k| h[k] = [] }

      [
        Faraday::TooManyRequestsError.new("Rate limited"),
        Faraday::TimeoutError.new("Timeout"),
        StandardError.new("Unknown error")
      ].each do |error|
        category = described_class.categorize_error(error)
        errors_by_category[category] << error
      end

      expect(errors_by_category.keys).to contain_exactly(:rate_limit, :timeout, :unknown)
    end
  end
end
