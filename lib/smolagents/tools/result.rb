require_relative "../concerns/formatting/output"
require_relative "result/core"
require_relative "result/collection"
require_relative "result/utility"
require_relative "result/creation"

module Smolagents
  module Tools
    # Chainable, Enumerable wrapper for tool outputs with fluent data transformations.
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
    # @example Pattern matching
    #   case result
    #   in ToolResult[data: Array, empty?: false]
    #     puts "Got #{result.size} items"
    #   end
    class ToolResult
      include Enumerable
      include Concerns::ResultFormatting
      include Core
      include Collection
      include Utility
      include Creation
    end
  end

  ToolResult = Tools::ToolResult
end
