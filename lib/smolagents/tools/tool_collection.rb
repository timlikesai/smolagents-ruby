module Smolagents
  class ToolCollection
    attr_reader :tools

    def initialize(tools = [])
      @tools = tools
    end

    def add(tool)
      @tools << tool
    end

    alias << add

    def [](name)
      @tools.find { |tool| tool.name == name.to_s }
    end

    def names
      @tools.map(&:name)
    end

    def to_a
      @tools.map(&:to_h)
    end

    def each(&)
      @tools.each(&)
    end

    def size
      @tools.size
    end

    alias length size
    alias count size

    def empty?
      @tools.empty?
    end

    def include?(name)
      @tools.any? { |tool| tool.name == name.to_s }
    end

    def remove(name)
      tool = self[name.to_s]
      @tools.delete(tool) if tool
      tool
    end

    def self.from_tools(tools)
      new(tools)
    end

    def self.from_hash(hash)
      new(hash.values)
    end
  end
end
