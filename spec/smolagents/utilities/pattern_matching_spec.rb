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
      text = "Code: <code>x = 1 + 2</code>"
      code = described_class.extract_code(text)

      expect(code).to eq("x = 1 + 2")
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
      text = "```ruby\nruby_code\n```\n```\ngeneric\n```"
      code = described_class.extract_code(text)

      expect(code).to eq("ruby_code")
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
      response_text = "Here's the solution:\n```ruby\nfinal_answer(42)\n```"
      code = Smolagents::PatternMatching.extract_code(response_text)

      result = if code =~ /final_answer\((\d+)\)/
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
        category = Smolagents::PatternMatching.categorize_error(error)
        errors_by_category[category] << error
      end

      expect(errors_by_category.keys).to contain_exactly(:rate_limit, :timeout, :unknown)
    end
  end
end
