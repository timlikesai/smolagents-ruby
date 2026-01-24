# Example: Class-Based Tools
#
# For complex tools that need state, configuration, or lifecycle management,
# inherit from Smolagents::Tool. This provides setup hooks, structured output,
# and better organization for larger tools.
#
# Run: ruby examples_new/tools/02_class_tools.rb
# Test: bundle exec rspec spec/examples/tools/02_class_tools_spec.rb

require_relative "../../lib/smolagents"

# =============================================================================
# BASIC CLASS TOOL
# =============================================================================
#
# Define tool metadata as class attributes, implement execute method.

class TemperatureConverter < Smolagents::Tool
  self.tool_name = "convert_temp"
  self.description = "Convert temperature between Celsius and Fahrenheit"
  self.inputs = {
    value: { type: "number", description: "Temperature value" },
    from_unit: { type: "string", description: "Source unit (C or F)" }
  }
  self.output_type = "object"

  def execute(value:, from_unit:)
    case from_unit.upcase
    when "C"
      { value: (value * 9.0 / 5.0) + 32, unit: "F" }
    when "F"
      { value: (value - 32) * 5.0 / 9.0, unit: "C" }
    else
      raise ArgumentError, "Unknown unit: #{from_unit}"
    end
  end
end

# =============================================================================
# TOOL WITH SETUP (STATEFUL)
# =============================================================================
#
# Use setup for expensive initialization that should happen once.

class CounterTool < Smolagents::Tool
  self.tool_name = "counter"
  self.description = "Increment and return a counter"
  self.inputs = {}
  self.output_type = "integer"

  def setup
    @count = 0
    super
  end

  def execute
    @count += 1
  end
end

# =============================================================================
# TOOL WITH CONFIGURATION
# =============================================================================
#
# Create configurable tools that can be customized per-instance.

class SearchTool < Smolagents::Tool
  self.tool_name = "search"
  self.description = "Search with configurable max results"
  self.inputs = {
    query: { type: "string", description: "Search query" }
  }
  self.output_type = "array"

  def initialize(max_results: 5)
    @max_results = max_results
    super()
  end

  def execute(query:)
    # Simulated search results
    (1..@max_results).map { |i| "Result #{i} for: #{query}" }
  end
end

# =============================================================================
# TOOL WITH STRUCTURED OUTPUT
# =============================================================================
#
# Define output_schema for complex return types.

class AnalysisTool < Smolagents::Tool
  self.tool_name = "analyze_text"
  self.description = "Analyze text and return statistics"
  self.inputs = {
    text: { type: "string", description: "Text to analyze" }
  }
  self.output_type = "object"
  self.output_schema = {
    word_count: { type: "integer", description: "Number of words" },
    char_count: { type: "integer", description: "Number of characters" },
    sentence_count: { type: "integer", description: "Number of sentences" }
  }

  def execute(text:)
    {
      word_count: text.split.count,
      char_count: text.length,
      sentence_count: text.scan(/[.!?]/).count
    }
  end
end

# =============================================================================
# USING CLASS TOOLS WITH AGENTS
# =============================================================================
#
# Instantiate and pass to .tools()

def create_agent_with_class_tools(model)
  converter = TemperatureConverter.new
  counter = CounterTool.new
  search = SearchTool.new(max_results: 3)

  Smolagents.agent
            .model { model }
            .tools(converter, counter, search)
            .build
end

# =============================================================================
# RUNNING
# =============================================================================

if __FILE__ == $PROGRAM_NAME
  puts "Class-Based Tools Example"
  puts ""
  puts "See the test file for deterministic examples:"
  puts "  bundle exec rspec spec/examples/tools/02_class_tools_spec.rb"
end
