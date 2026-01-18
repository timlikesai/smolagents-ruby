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
    # @example Creating a ToolResult with array data
    #   result = Smolagents::ToolResult.new(
    #     [{ name: "Alice", age: 30 }, { name: "Bob", age: 25 }],
    #     tool_name: "sample"
    #   )
    #   result.size
    #   # => 2
    #
    # @example Arithmetic with numeric results
    #   calc_result = Smolagents::ToolResult.new(100.0, tool_name: "calculate")
    #   calc_result - 50
    #   # => 50.0
    #
    # @example Pattern matching (Ruby 3.0+)
    #   result = Smolagents::ToolResult.new([1, 2, 3], tool_name: "test")
    #   case result
    #   in Smolagents::ToolResult => r if !r.empty?
    #     r.size
    #   end
    #   # => 3
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
