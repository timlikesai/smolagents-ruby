module Smolagents
  module Tools
    def self.define_tool(name, description:, inputs:, output_type:, &)
      raise ArgumentError, "Block required" unless block_given?

      tool_class = Class.new(Tool) do
        self.tool_name = name.to_s
        self.description = description
        self.inputs = inputs
        self.output_type = output_type
        define_method(:forward, &)
      end

      tool_class.new
    end
  end
end
