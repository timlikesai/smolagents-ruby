module Smolagents
  # A container for managing a collection of tools.
  #
  # ToolCollection provides an enumerable, hash-like interface for storing
  # and accessing tools. It supports adding, removing, and looking up tools
  # by name, making it suitable for organizing tools before passing them
  # to agents.
  #
  # Collections can be created empty and populated incrementally, or initialized
  # from existing arrays or hashes of tools.
  #
  # @example Building a collection incrementally
  #   collection = ToolCollection.new
  #
  #   # Add tools using add() or <<
  #   collection.add(SearchTool.new)
  #   collection << CalculatorTool.new
  #   collection << VisitWebpageTool.new
  #
  #   # Check contents
  #   collection.size     # => 3
  #   collection.names    # => ["search", "calculator", "visit_webpage"]
  #   collection.empty?   # => false
  #
  # @example Accessing tools by name
  #   collection = ToolCollection.from_tools([
  #     SearchTool.new,
  #     CalculatorTool.new
  #   ])
  #
  #   # Lookup by name (string or symbol)
  #   search = collection["search"]
  #   calc = collection[:calculator]
  #
  #   # Check if a tool exists
  #   collection.include?("search")  # => true
  #   collection.include?("unknown") # => false
  #
  # @example Iterating over tools
  #   collection.each do |tool|
  #     puts "#{tool.name}: #{tool.description}"
  #   end
  #
  #   # Convert to array of hashes for serialization
  #   json_data = collection.to_a
  #   # => [{ name: "search", description: "...", ... }, ...]
  #
  # @see Tool Base class for all tools
  # @see MCPToolCollection Subclass for MCP server tools
  # @see CodeAgent#tools How agents use tool collections
  class ToolCollection
    # @return [Array<Tool>] The tools in this collection
    attr_reader :tools

    # Creates a new tool collection.
    #
    # @param tools [Array<Tool>] Initial tools for the collection (default: empty)
    #
    # @example Empty collection
    #   collection = ToolCollection.new
    #
    # @example Pre-populated collection
    #   collection = ToolCollection.new([tool1, tool2, tool3])
    def initialize(tools = [])
      @tools = tools
    end

    # Adds a tool to the collection.
    #
    # @param tool [Tool] The tool to add
    # @return [Array<Tool>] The updated tools array
    #
    # @example
    #   collection.add(SearchTool.new)
    def add(tool)
      @tools << tool
    end

    alias << add

    # Retrieves a tool by name.
    #
    # @param name [String, Symbol] The tool name to look up
    # @return [Tool, nil] The matching tool or nil if not found
    #
    # @example
    #   tool = collection["search"]
    #   tool = collection[:calculator]
    def [](name)
      @tools.find { |tool| tool.name == name.to_s }
    end

    # Returns all tool names in the collection.
    #
    # @return [Array<String>] List of tool names
    #
    # @example
    #   collection.names  # => ["search", "calculator", "visit_webpage"]
    def names
      @tools.map(&:name)
    end

    # Converts the collection to an array of tool hashes.
    #
    # @return [Array<Hash>] Array of tool specifications
    #
    # @example
    #   collection.to_a
    #   # => [{ name: "search", description: "...", inputs: {...}, output_type: "string" }, ...]
    def to_a
      @tools.map(&:to_h)
    end

    # Iterates over each tool in the collection.
    #
    # @yield [tool] Block called for each tool
    # @yieldparam tool [Tool] A tool in the collection
    # @return [Enumerator, self] Enumerator if no block, self otherwise
    #
    # @example
    #   collection.each { |tool| puts tool.name }
    def each(&)
      @tools.each(&)
    end

    # Returns the number of tools in the collection.
    #
    # @return [Integer] Number of tools
    def size
      @tools.size
    end

    alias length size
    alias count size

    # Checks if the collection is empty.
    #
    # @return [Boolean] true if no tools, false otherwise
    def empty?
      @tools.empty?
    end

    # Checks if a tool with the given name exists.
    #
    # @param name [String, Symbol] The tool name to check
    # @return [Boolean] true if tool exists, false otherwise
    #
    # @example
    #   collection.include?("search")   # => true
    #   collection.include?(:unknown)   # => false
    def include?(name)
      @tools.any? { |tool| tool.name == name.to_s }
    end

    # Removes a tool by name.
    #
    # @param name [String, Symbol] The tool name to remove
    # @return [Tool, nil] The removed tool or nil if not found
    #
    # @example
    #   removed = collection.remove("search")
    #   removed.name  # => "search"
    def remove(name)
      tool = self[name.to_s]
      @tools.delete(tool) if tool
      tool
    end

    # Creates a collection from an array of tools.
    #
    # @param tools [Array<Tool>] Tools to include
    # @return [ToolCollection] New collection containing the tools
    #
    # @example
    #   collection = ToolCollection.from_tools([SearchTool.new, CalculatorTool.new])
    def self.from_tools(tools)
      new(tools)
    end

    # Creates a collection from a hash of tools (keyed by name).
    #
    # @param hash [Hash{String => Tool}] Hash mapping names to tools
    # @return [ToolCollection] New collection containing the hash values
    #
    # @example
    #   tools_hash = { "search" => SearchTool.new, "calc" => CalculatorTool.new }
    #   collection = ToolCollection.from_hash(tools_hash)
    def self.from_hash(hash)
      new(hash.values)
    end
  end
end
