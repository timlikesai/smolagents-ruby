module Smolagents
  module Tools
    class ToolResult
      # Factory methods for creating ToolResult instances.
      #
      # Provides class methods for common result creation patterns.
      module Factory
        def self.included(base)
          base.extend(ClassMethods)
        end

        # Class methods for ToolResult factory patterns.
        module ClassMethods
          # Creates an empty ToolResult.
          #
          # @param tool_name [String] Name of the tool
          # @return [ToolResult] Empty result with no data
          def empty(tool_name: "unknown") = new([], tool_name:)

          # Creates an error ToolResult.
          #
          # @param error [Exception, String] The error or error message
          # @param tool_name [String] Name of the tool that failed
          # @param metadata [Hash] Additional metadata
          # @return [ToolResult] Error result with :error and :success metadata
          def error(error, tool_name: "unknown", metadata: {})
            message = error.is_a?(Exception) ? "#{error.class}: #{error.message}" : error.to_s
            new(nil, tool_name:, metadata: metadata.merge(error: message, success: false))
          end
        end
      end
    end
  end
end
