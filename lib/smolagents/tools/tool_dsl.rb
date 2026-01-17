module Smolagents
  # DSL methods for defining tools programmatically.
  #
  # The Tools module provides a factory method for creating tools from blocks,
  # enabling quick tool definitions without creating explicit subclasses.
  # This is useful for one-off tools, testing, or when you prefer a functional
  # style over class-based tool definitions.
  #
  # @see Tool Base class for tool definitions
  # @see ToolResult Return type for tool executions
  module Tools
    # Creates a new tool instance from a block definition.
    #
    # This factory method dynamically creates a Tool subclass and instantiates it,
    # allowing you to define tools inline without explicit class definitions.
    # The block becomes the tool's {Tool#execute} method.
    #
    # @param name [String, Symbol] Unique identifier for the tool
    # @param description [String] Human-readable description of what the tool does
    # @param inputs [Hash{String => Hash}] Input parameter specifications, each containing
    #   :type and :description keys
    # @param output_type [String] Expected return type ("string", "number", "boolean",
    #   "array", "object", "any", etc.)
    # @yield Block that implements the tool's logic; receives keyword arguments
    #   matching the input names
    # @yieldreturn [Object] The tool's result, automatically wrapped in ToolResult
    # @return [Tool] A new tool instance ready for use
    # @raise [ArgumentError] If no block is provided
    #
    # @see Tool#execute The method that the block implements
    # @see Tool#call How to invoke the created tool
    def self.define_tool(name, description:, inputs:, output_type:, &)
      raise ArgumentError, "Block required" unless block_given?

      tool_class = Class.new(Tool) do
        self.tool_name = name.to_s
        self.description = description
        self.inputs = inputs
        self.output_type = output_type
        define_method(:execute, &)
      end

      tool_class.new
    end
  end
end
