# frozen_string_literal: true

module Smolagents
  module Tools
    # Define a tool using a DSL.
    # This creates an anonymous Tool subclass and returns an instance.
    #
    # @param name [Symbol, String] tool name
    # @param description [String] tool description
    # @param inputs [Hash] input schema
    # @param output_type [String] output type
    # @param block [Proc] the tool implementation (becomes the forward method)
    # @return [Tool] tool instance
    #
    # @example
    #   search_tool = Smolagents::Tools.define_tool(
    #     :web_search,
    #     description: "Search the web",
    #     inputs: { "query" => { "type" => "string", "description" => "Search query" } },
    #     output_type: "string"
    #   ) do |query:|
    #     "Results for: #{query}"
    #   end
    def self.define_tool(name, description:, inputs:, output_type:, &)
      raise ArgumentError, "Block required" unless block_given?

      # Create an anonymous Tool subclass
      tool_class = Class.new(Tool) do
        self.tool_name = name.to_s
        self.description = description
        self.inputs = inputs
        self.output_type = output_type

        # Define the forward method using the block
        define_method(:forward, &)
      end

      # Return an instance
      tool_class.new
    end
  end
end
