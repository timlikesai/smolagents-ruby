# frozen_string_literal: true

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
          "roles" => ["admin", "user"]
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

    it "categorizes client errors" do
      error = Faraday::ClientError.new("Bad request")
      category = described_class.categorize_error(error)

      expect(category).to eq(:client_error)
    end

    it "categorizes server errors" do
      error = Faraday::ServerError.new("Internal server error")
      category = described_class.categorize_error(error)

      expect(category).to eq(:server_error)
    end

    it "returns :unknown for uncategorized errors" do
      error = StandardError.new("Something weird happened")
      category = described_class.categorize_error(error)

      expect(category).to eq(:unknown)
    end
  end

  describe ".match_tool_result" do
    it "matches simple hash patterns" do
      result = { success: true, output: "Done" }
      matched = nil

      described_class.match_tool_result(result) do |pattern|
        pattern.on(success: true) { matched = :success }
        pattern.on(success: false) { matched = :failure }
      end

      expect(matched).to eq(:success)
    end

    it "executes otherwise block when no patterns match" do
      result = { status: :pending }
      matched = nil

      described_class.match_tool_result(result) do |pattern|
        pattern.on(status: :complete) { matched = :done }
        pattern.otherwise { matched = :other }
      end

      expect(matched).to eq(:other)
    end

    it "passes result to handler block" do
      result = { output: "test output" }
      captured = nil

      described_class.match_tool_result(result) do |pattern|
        pattern.on(output: String) { |r| captured = r[:output] }
      end

      expect(captured).to eq("test output")
    end

    it "stops at first matching pattern" do
      result = { value: 42 }
      matches = []

      described_class.match_tool_result(result) do |pattern|
        pattern.on(value: Integer) { matches << :first }
        pattern.on(value: 42) { matches << :second }
      end

      expect(matches).to eq([:first])
    end
  end

  describe "ChatMessage refinements" do
    using Smolagents::ChatMessagePatterns

    it "enables pattern matching on ChatMessage" do
      message = Smolagents::ChatMessage.assistant("Hello", tool_calls: nil)

      matched = case message
                in Smolagents::ChatMessage[role: :assistant, content: String]
                  :matched
                else
                  :not_matched
                end

      expect(matched).to eq(:matched)
    end

    it "matches tool_calls in ChatMessage" do
      tool_call = Smolagents::ToolCall.new(name: "search", arguments: { "q" => "test" }, id: "123")
      message = Smolagents::ChatMessage.assistant("Searching", tool_calls: [tool_call])

      matched = case message
                in Smolagents::ChatMessage[role: :assistant, tool_calls: Array]
                  :has_tool_calls
                else
                  :no_tool_calls
                end

      expect(matched).to eq(:has_tool_calls)
    end

    it "provides deconstruct_keys for all message attributes" do
      message = Smolagents::ChatMessage.user("Test")
      keys = message.deconstruct_keys(nil)

      expect(keys).to include(
        role: :user,
        content: "Test",
        tool_calls: nil,
        raw: nil,
        token_usage: nil
      )
    end
  end

  describe "ActionStep refinements" do
    using Smolagents::ActionStepPatterns

    it "enables pattern matching on ActionStep" do
      step = Smolagents::ActionStep.new(step_number: 1)
      step.is_final_answer = true
      step.action_output = "Final result"

      matched = case step
                in Smolagents::ActionStep[is_final_answer: true, action_output: String]
                  :final
                else
                  :not_final
                end

      expect(matched).to eq(:final)
    end

    it "matches error states" do
      step = Smolagents::ActionStep.new(step_number: 1)
      step.error = StandardError.new("Test error")

      matched = case step
                in Smolagents::ActionStep[error: StandardError]
                  :has_error
                else
                  :no_error
                end

      expect(matched).to eq(:has_error)
    end

    it "provides deconstruct_keys for all step attributes" do
      step = Smolagents::ActionStep.new(step_number: 5)
      keys = step.deconstruct_keys(nil)

      expect(keys).to include(
        step_number: 5,
        is_final_answer: false
      )
      expect(keys[:timing]).to be_a(Smolagents::Timing) # Timing is auto-created
      expect(keys.keys).to include(
        :model_input_messages,
        :tool_calls,
        :error,
        :observations
      )
    end
  end

  describe "integration examples" do
    it "combines extraction and pattern matching" do
      response_text = "Here's the solution:\n```ruby\nfinal_answer(42)\n```"
      code = Smolagents::PatternMatching.extract_code(response_text)

      result = if code =~ /final_answer\((\d+)\)/
                 { type: :final, value: Regexp.last_match(1).to_i }
               elsif code =~ /search\(/
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
      expect(errors_by_category[:rate_limit].size).to eq(1)
      expect(errors_by_category[:timeout].size).to eq(1)
      expect(errors_by_category[:unknown].size).to eq(1)
    end
  end
end
