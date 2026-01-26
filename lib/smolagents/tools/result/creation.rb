module Smolagents
  module Tools
    class ToolResult
      # Creation and composition: factory methods and result combining.
      module Creation
        def self.included(base)
          base.extend(ClassMethods)
        end

        # Class methods for creating results.
        module ClassMethods
          def empty(tool_name: "unknown") = new([], tool_name:)

          def error(error, tool_name: "unknown", metadata: {})
            message = error.is_a?(Exception) ? "#{error.class}: #{error.message}" : error.to_s
            new(nil, tool_name:, metadata: metadata.merge(error: message, success: false))
          end
        end

        # Concatenates two results.
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
