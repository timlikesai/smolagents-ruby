require_relative "../concerns/result_formatting"
require_relative "result/core"
require_relative "result/enumerable_support"
require_relative "result/chainable"
require_relative "result/aggregations"
require_relative "result/status"
require_relative "result/conversions"
require_relative "result/pattern_matching"
require_relative "result/comparison"
require_relative "result/factory"
require_relative "result/composition"

module Smolagents
  module Tools
    # A chainable, Enumerable wrapper for tool outputs that enables fluent data transformations.
    #
    # ToolResult wraps any data returned from a tool execution, providing a rich API for
    # filtering, transforming, and formatting the data. All transformation methods return
    # new ToolResult instances, enabling method chaining while preserving immutability.
    #
    # @example Creating results
    #   result = ToolResult.new([{name: "Alice"}, {name: "Bob"}], tool_name: "list_users")
    #   result = ToolResult.new("Hello, world!", tool_name: "greet")
    #   result = ToolResult.empty(tool_name: "search")
    #   result = ToolResult.error("Connection timeout", tool_name: "fetch_data")
    #
    # @example Chaining operations (fluent API)
    #   users.select { |u| u[:age] < 32 }.sort_by { |u| u[:age] }.take(2)
    #   users.pluck(:name)
    #   users.map { |u| "Hello, #{u[:name]}!" }
    #
    # @example Pattern matching (Ruby 3.0+)
    #   case result
    #   in ToolResult[data: Array, empty?: false]
    #     puts "Got #{result.size} items"
    #   in ToolResult[error?: true]
    #     puts "Error: #{result.metadata[:error]}"
    #   end
    #
    # @example Output formats
    #   items.as_markdown   # Markdown list
    #   items.as_table      # ASCII table
    #   items.to_json       # JSON
    #   items.as_list       # Bullet list
    #
    # @example Composition
    #   all_people = users + admins
    #
    # @see Tool The base class that produces ToolResult instances
    # @see Concerns::ResultFormatting Output formatting methods
    class ToolResult
      include Enumerable
      include Concerns::ResultFormatting
      include Core
      include EnumerableSupport
      include Chainable
      include Aggregations
      include Status
      include Conversions
      include PatternMatching
      include Comparison
      include Factory
      include Composition
    end
  end

  # Re-export ToolResult at the Smolagents level.
  ToolResult = Tools::ToolResult
end
