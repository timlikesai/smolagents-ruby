#!/usr/bin/env ruby
# frozen_string_literal: true

# Custom Tools: Creating tools with the DSL
#
# This example demonstrates the various ways to define custom tools
# using smolagents-ruby's expressive DSL.

require "smolagents"

# =============================================================================
# Block-Based Tool Definition
# =============================================================================
#
# The simplest way to create a tool is with define_tool:

calculator = Smolagents::Tools.define_tool(
  "calculator",
  description: "Evaluate mathematical expressions safely",
  inputs: {
    expression: { type: "string", description: "Math expression (e.g., '2 + 2 * 3')" }
  },
  output_type: "number"
) do |expression:|
  # Simple safe evaluation for basic math
  allowed = /\A[\d\s+\-*\/().]+\z/
  raise "Invalid expression" unless expression.match?(allowed)

  eval(expression).to_f
end

puts "Created tool: #{calculator.name}"
puts "Result of '2 + 3 * 4': #{calculator.call(expression: '2 + 3 * 4').data}"

# =============================================================================
# Class-Based Tool Definition
# =============================================================================
#
# For more complex tools, subclass Smolagents::Tool:

class WeatherTool < Smolagents::Tool
  self.tool_name = "weather"
  self.description = "Get current weather for a location"
  self.inputs = {
    city: { type: "string", description: "City name" },
    units: { type: "string", description: "Temperature units: celsius or fahrenheit", nullable: true }
  }
  self.output_type = "string"

  def execute(city:, units: "celsius")
    # In a real tool, this would call a weather API
    temp = rand(15..30)
    temp = (temp * 9 / 5) + 32 if units == "fahrenheit"
    unit_symbol = units == "fahrenheit" ? "F" : "C"

    "#{city}: #{temp}#{unit_symbol}, partly cloudy"
  end
end

weather = WeatherTool.new
puts "\n#{weather.call(city: 'Paris').data}"
puts weather.call(city: 'New York', units: 'fahrenheit').data

# =============================================================================
# Tool Configuration DSL
# =============================================================================
#
# Tools can use configure blocks for settings:

class ConfigurableSearchTool < Smolagents::Tool
  self.tool_name = "configured_search"
  self.description = "Search with configurable settings"
  self.inputs = { query: { type: "string", description: "Search query" } }
  self.output_type = "array"

  # DSL configuration block
  class Config
    attr_accessor :max_results, :timeout_seconds, :safe_search

    def initialize
      @max_results = 10
      @timeout_seconds = 30
      @safe_search = true
    end

    def max_results(n) = @max_results = n
    def timeout(s) = @timeout_seconds = s
    def safe_search(enabled) = @safe_search = enabled
    def to_h = { max_results: @max_results, timeout: @timeout_seconds, safe_search: @safe_search }
  end

  class << self
    def configure(&block)
      @config ||= Config.new
      @config.instance_eval(&block) if block
      @config
    end

    def config
      @config || (superclass.config if superclass.respond_to?(:config)) || Config.new
    end
  end

  def initialize
    @config = self.class.config.to_h
    super()
  end

  def execute(query:)
    # Use configuration in the search
    puts "  Searching '#{query}' with max_results=#{@config[:max_results]}, timeout=#{@config[:timeout]}s"
    [{ title: "Result 1", url: "https://example.com/1" }]
  end
end

# Create a customized subclass:
class FastSearch < ConfigurableSearchTool
  configure do
    max_results 5
    timeout 10
  end
end

puts "\nFast search configuration:"
fast = FastSearch.new
fast.call(query: "Ruby programming")

# =============================================================================
# Tools with Setup
# =============================================================================
#
# Use setup for expensive initialization (called once on first use):

class DatabaseTool < Smolagents::Tool
  self.tool_name = "database"
  self.description = "Query a database"
  self.inputs = { sql: { type: "string", description: "SQL query" } }
  self.output_type = "array"

  def setup
    puts "  [DatabaseTool] Establishing connection..."
    @connection = "Connected to database"  # Would be real DB connection
    puts "  [DatabaseTool] Ready!"
  end

  def execute(sql:)
    puts "  [DatabaseTool] Executing: #{sql}"
    [{ id: 1, name: "Example" }]
  end
end

puts "\nDatabase tool (setup called on first use):"
db = DatabaseTool.new
db.call(sql: "SELECT * FROM users LIMIT 1")
db.call(sql: "SELECT * FROM orders LIMIT 1")  # Setup not called again

# =============================================================================
# Tools with Structured Output
# =============================================================================
#
# Define output schemas for structured responses:

class AnalysisTool < Smolagents::Tool
  self.tool_name = "analyze"
  self.description = "Analyze text and return structured metrics"
  self.inputs = { text: { type: "string", description: "Text to analyze" } }
  self.output_type = "object"
  self.output_schema = {
    word_count: { type: "integer", description: "Number of words" },
    char_count: { type: "integer", description: "Number of characters" },
    sentences: { type: "integer", description: "Number of sentences" },
    avg_word_length: { type: "number", description: "Average word length" }
  }

  def execute(text:)
    words = text.split
    {
      word_count: words.count,
      char_count: text.length,
      sentences: text.scan(/[.!?]/).count,
      avg_word_length: words.sum(&:length).to_f / words.count
    }
  end
end

puts "\nAnalysis tool with structured output:"
analyzer = AnalysisTool.new
result = analyzer.call(text: "Hello world. This is a test. How are you?")
puts "  #{result.data}"

# =============================================================================
# Chainable ToolResult
# =============================================================================
#
# Tool results support fluent chaining:

class SearchResultsTool < Smolagents::Tool
  self.tool_name = "search_results"
  self.description = "Return sample search results"
  self.inputs = { query: { type: "string", description: "Query" } }
  self.output_type = "array"

  def execute(query:)
    [
      { title: "Ruby Guide", score: 0.9, url: "https://ruby-lang.org" },
      { title: "Python Docs", score: 0.3, url: "https://python.org" },
      { title: "Ruby Gems", score: 0.8, url: "https://rubygems.org" },
      { title: "Rails Guide", score: 0.7, url: "https://rubyonrails.org" }
    ]
  end
end

puts "\nChainable results:"
search = SearchResultsTool.new
results = search.call(query: "Ruby")

# Filter, sort, and transform
ruby_results = results
  .select { |r| r[:title].include?("Ruby") }
  .sort_by(:score, descending: true)
  .pluck(:title)

puts "  Top Ruby results: #{ruby_results}"

# Output formats
puts "\n  As markdown:"
puts results.take(2).as_markdown

# =============================================================================
# Using Tools with Agents
# =============================================================================

puts "\n" + "=" * 60
puts "Combining tools with agents:"
puts "=" * 60

agent = Smolagents.agent(:tool)
  .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
  .tools(calculator, weather, analyzer)  # Custom tool instances
  .tools(:web_search)                     # Built-in tool by name
  .build

puts "Agent created with tools:"
agent.tools.each_key { |name| puts "  - #{name}" }

# Uncomment to run:
# result = agent.run("What's the weather in Tokyo, and what's 15 * 23?")
# puts result.output
