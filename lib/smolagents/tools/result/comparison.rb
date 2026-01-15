module Smolagents
  module Tools
    class ToolResult
      # Comparison and equality methods for ToolResult.
      #
      # Provides ==, eql?, and hash for comparing results and using them as Hash keys.
      module Comparison
        # Compares two ToolResults or a ToolResult with raw data.
        #
        # @param other [ToolResult, Object] The object to compare
        # @return [Boolean] True if data and tool_name match (for ToolResult) or data matches
        def ==(other)
          other.is_a?(ToolResult) ? @data == other.data && @tool_name == other.tool_name : @data == other
        end
        alias eql? ==

        # Returns a hash code for use in Hash keys.
        #
        # @return [Integer] Hash code based on data and tool_name
        def hash = [@data, @tool_name].hash
      end
    end
  end
end
