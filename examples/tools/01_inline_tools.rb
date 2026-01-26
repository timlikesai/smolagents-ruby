# Example: Inline Tools
#
# Define tools directly in the agent builder using the `.tool()` DSL.
# This is the simplest way to add custom functionality without creating classes.
#
# Run: ruby examples/tools/01_inline_tools.rb
# Test: bundle exec rspec spec/examples/tools/01_inline_tools_spec.rb

require_relative "../../lib/smolagents"

# =============================================================================
# SIMPLE INLINE TOOL
# =============================================================================
#
# The `.tool()` method accepts:
#   - name (Symbol or String)
#   - description (String)
#   - **inputs (keyword arguments with types)
#   - &block (the implementation)

def create_agent_with_calculator(model)
  Smolagents.agent
            .model { model }
            .tool(:calculate, "Evaluate a mathematical expression",
                  expression: String) { |expression:| eval(expression).to_f } # rubocop:disable Security/Eval
            .build
end

# =============================================================================
# MULTIPLE INLINE TOOLS
# =============================================================================
#
# Chain multiple `.tool()` calls for agents with several custom tools.

def create_agent_with_string_tools(model)
  Smolagents.agent
            .model { model }
            .tool(:reverse, "Reverse a string",
                  text: String) { |text:| text.reverse }
            .tool(:uppercase, "Convert to uppercase",
                  text: String) { |text:| text.upcase }
            .tool(:word_count, "Count words in text",
                  text: String) { |text:| text.split.count }
            .build
end

# =============================================================================
# TOOL WITH OPTIONAL PARAMETERS
# =============================================================================
#
# Use Hash syntax for optional/nullable parameters.

def create_agent_with_greeting(model)
  Smolagents.agent
            .model { model }
            .tool(:greet, "Generate a greeting", name: String,
                                                 formal: { type: "boolean", nullable: true }) do |name:, formal: false|
              formal ? "Good day, #{name}." : "Hey #{name}!"
  end
            .build
end

# =============================================================================
# TOOL RETURNING STRUCTURED DATA
# =============================================================================
#
# Tools can return complex objects - they'll be serialized for the agent.

def create_agent_with_data_tool(model)
  Smolagents.agent
            .model { model }
            .tool(:analyze, "Analyze text and return statistics", text: String) do |text:|
              words = text.split
              { length: text.length, words: words.count, sentences: text.scan(/[.!?]/).count }
            end
            .build
end

# =============================================================================
# COMBINING INLINE AND NAMED TOOLS
# =============================================================================
#
# Mix inline tools with built-in or class-based tools.

def create_agent_with_mixed_tools(model)
  Smolagents.agent
            .model { model }
            .tools(:search) # Built-in search tool
            .tool(:summarize, "Create a one-line summary",
                  text: String) { |text:| "#{text.split.first(10).join(" ")}..." }
            .build
end

# =============================================================================
# RUNNING
# =============================================================================

if __FILE__ == $PROGRAM_NAME
  puts "This example requires a configured model."
  puts "See the test file for deterministic examples using MockModel."
  puts ""
  puts "Test: bundle exec rspec spec/examples/tools/01_inline_tools_spec.rb"
end
