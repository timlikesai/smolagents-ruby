module Smolagents
  module Tools
    class ToolResult
      # Status checking methods for ToolResult.
      #
      # Provides predicates to check result state (empty, error, success, inclusion).
      module Status
        # Returns true if the result contains no data.
        #
        # @return [Boolean] Whether the result is empty
        def empty? = @data.nil? || (@data.respond_to?(:empty?) && @data.empty?)

        # Returns true if the result contains a specific value.
        #
        # @param value [Object] The value to check for
        # @return [Boolean] Whether the value is present
        def include?(value)
          (@data.respond_to?(:include?) && @data.include?(value)) ||
            (error? && @metadata[:error].to_s.include?(value.to_s))
        end
        alias member? include?

        # Returns true if this result represents an error.
        #
        # @return [Boolean] Whether this is an error result
        def error? = @metadata[:success] == false || @metadata.key?(:error)

        # Returns true if this result represents a successful operation.
        #
        # @return [Boolean] Whether this is a success result
        def success? = !error?
      end
    end
  end
end
