#!/usr/bin/env ruby
# Test different prompt formats with gpt-oss-20b

require "faraday"
require "json"

# Simple test runner for gpt-oss model prompt formats.
class GptOssTest
  MODEL = "gpt-oss-20b".freeze

  def run
    test("Simple instruction", simple_messages)
    test("Explicit format", explicit_messages)
    test("With stop sequence", stop_messages, stop: ["<|channel|>", "{"])
    test("Assistant priming", priming_messages, prefix: "```ruby\n")
    test("User instruction only", user_only_messages)
  end

  private

  def test(name, messages, stop: nil, prefix: nil)
    puts "=" * 60, name, "=" * 60
    content = call_model(messages, stop:)
    puts prefix ? "#{prefix}#{content}" : content
    puts
  end

  def call_model(messages, stop: nil)
    body = { model: MODEL, messages:, temperature: 0.7, max_tokens: 512 }
    body[:stop] = stop if stop
    conn.post("/v1/chat/completions") { |r| r.body = body }.body.dig("choices", 0, "message", "content")
  rescue StandardError => e
    "ERROR: #{e.message}"
  end

  def conn
    @conn ||= Faraday.new(url: "http://localhost:1234") do |f|
      f.request :json
      f.response :json
      f.options.timeout = 30
    end
  end

  def simple_messages = [{ role: "user", content: "Write Ruby code to print hello. Use ```ruby block." }]
  def explicit_messages = [sys("Always respond with Ruby code in ```ruby blocks."), user("Write code to calculate 2+2")]
  def stop_messages = [user("Write Ruby code: puts 'hello'. Use ```ruby block format.")]
  def priming_messages = [user("Calculate 5*5 in Ruby"), { role: "assistant", content: "```ruby\n" }]

  def user_only_messages
    [user(<<~PROMPT)]
      You write Ruby code. Format: Thought: <reasoning>
      ```ruby
      <code>
      ```
      Task: Search for "hello" using search(query: "hello")
    PROMPT
  end

  def sys(content) = { role: "system", content: }
  def user(content) = { role: "user", content: }
end

GptOssTest.new.run
