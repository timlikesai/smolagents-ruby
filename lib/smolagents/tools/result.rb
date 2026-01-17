require_relative "../concerns/formatting/output"
require_relative "result/core"
require_relative "result/collection"
require_relative "result/utility"
require_relative "result/creation"
require_relative "result/arithmetic"

module Smolagents
  module Tools
    # Chainable, Enumerable wrapper for tool outputs with fluent data transformations.
    #
    # ToolResult wraps tool outputs and provides fluent, chainable operations for
    # data transformation. When wrapping numeric data, it also supports arithmetic
    # operations, allowing natural expressions like `result - 50`.
    #
    # @example Creating a ToolResult
    #   result = Smolagents::ToolResult.new(
    #     data: [{ name: "Alice", age: 30 }, { name: "Bob", age: 25 }],
    #     tool_name: "sample"
    #   )
    #   result.size  # => 2
    #
    # @example Chaining operations
    #   users.select { |u| u[:age] < 32 }.sort_by { |u| u[:age] }.take(2)
    #
    # @example Arithmetic with numeric results
    #   calc_result = ToolResult.new(100.0, tool_name: "calculate")
    #   calc_result - 50   # => 50.0
    #   calc_result * 2    # => 200.0
    #   50 + calc_result   # => 150.0 (via coerce)
    #
    # @example Pattern matching
    #   case result
    #   in ToolResult[data: Array, empty?: false]
    #     puts "Got #{result.size} items"
    #   end
    class ToolResult
      include Enumerable
      include Comparable
      include Concerns::ResultFormatting
      include Core
      include Collection
      include Utility
      include Creation
      include Arithmetic # Must come after Creation to override + for numerics
    end
  end

  ToolResult = Tools::ToolResult
end
