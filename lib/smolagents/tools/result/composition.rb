module Smolagents
  module Tools
    class ToolResult
      # Composition methods for combining ToolResults.
      #
      # Provides operators for merging multiple results.
      module Composition
        # Concatenates two ToolResults into a new combined result.
        #
        # @param other [ToolResult] The result to append
        # @return [ToolResult] New result with combined data
        def +(other)
          self.class.new(
            to_a + other.to_a,
            tool_name: "#{@tool_name}+#{other.tool_name}",
            metadata: { combined_from: [@tool_name, other.tool_name] }
          )
        end
      end
    end
  end
end
