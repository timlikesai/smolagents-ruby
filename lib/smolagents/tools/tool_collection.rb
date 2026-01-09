# frozen_string_literal: true

module Smolagents
  # A collection of tools that can be managed together.
  class ToolCollection
    attr_reader :tools

    # @param tools [Array<Tool>] tools in this collection
    def initialize(tools = [])
      @tools = tools
    end

    # Add a tool to the collection.
    # @param tool [Tool] the tool to add
    def add(tool)
      @tools << tool
    end

    alias << add

    # Get a tool by name.
    # @param name [String, Symbol] tool name
    # @return [Tool, nil] the tool, or nil if not found
    def [](name)
      @tools.find { |t| t.name == name.to_s }
    end

    # Get all tool names.
    # @return [Array<String>]
    def names
      @tools.map(&:name)
    end

    # Convert all tools to hash representations.
    # @return [Array<Hash>]
    def to_a
      @tools.map(&:to_h)
    end

    # Iterate over tools.
    def each(&block)
      @tools.each(&block)
    end

    # Number of tools in collection.
    # @return [Integer]
    def size
      @tools.size
    end

    alias length size
    alias count size

    # Check if collection is empty.
    # @return [Boolean]
    def empty?
      @tools.empty?
    end

    # Check if a tool exists by name.
    # @param name [String, Symbol] tool name
    # @return [Boolean]
    def include?(name)
      @tools.any? { |t| t.name == name.to_s }
    end

    # Remove a tool by name.
    # @param name [String, Symbol] tool name
    # @return [Tool, nil] the removed tool, or nil
    def remove(name)
      tool = self[name.to_s]
      @tools.delete(tool) if tool
      tool
    end

    # Create a collection from an array of tools.
    # @param tools [Array<Tool>] the tools
    # @return [ToolCollection]
    def self.from_tools(tools)
      new(tools)
    end

    # Create a collection from a hash of name => tool.
    # @param hash [Hash{String => Tool}] tools by name
    # @return [ToolCollection]
    def self.from_hash(hash)
      new(hash.values)
    end
  end
end
