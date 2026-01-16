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

      it "falls back to code blocks when harmony has no tool calls" do
        # Harmony format detected but no tool calls, should fall back
        text = "<|channel|>final<|message|>The answer is 42\n```ruby\nputs 'hello'\n```"
        code = described_class.extract_code(text)

        expect(code).to eq("puts 'hello'")
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
