require_relative "sandbox"

module Smolagents
  module Executors
    # Sandbox for Ractor execution without tools.
    #
    # A minimal execution environment for code running in a Ractor.
    # Only variables are accessible - no tool support.
    #
    # @see ToolSandbox For tool-supporting version
    # @see Sandbox Base class with shared behavior
    # @api private
    class CodeSandbox < Sandbox
      # Routes unknown methods to variables or raises NoMethodError.
      #
      # @param name [Symbol] Method name
      # @param _args [Array] Arguments (ignored for variables)
      # @param _kwargs [Hash] Keyword arguments (ignored for variables)
      # @return [Object] Variable value
      # @raise [NoMethodError] If method not found
      # @api private
      def method_missing(name, *_args, **_kwargs)
        name_str = name.to_s
        return @variables[name_str] if @variables.key?(name_str)

        handle_unknown_method(name)
      end

      # @api private
      def respond_to_missing?(name, _ = false) = @variables.key?(name.to_s)
    end
  end
end
