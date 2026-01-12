module Smolagents
  class MCPTool < Tool
    attr_reader :mcp_tool, :client, :tool_name, :description, :inputs, :output_type, :output_schema

    alias name tool_name

    def initialize(mcp_tool, client:)
      @mcp_tool = mcp_tool
      @client = client
      @initialized = false

      define_tool_attributes
      validate_arguments!
    end

    def forward(**kwargs)
      response = client.call_tool(tool: mcp_tool, arguments: stringify_keys(kwargs))
      extract_result(response)
    end

    private

    def define_tool_attributes
      @tool_name = mcp_tool.name
      @description = mcp_tool.description || "MCP tool: #{mcp_tool.name}"
      @inputs = Concerns::Mcp.convert_input_schema(mcp_tool.input_schema)
      @output_type = determine_output_type
      @output_schema = mcp_tool.respond_to?(:output_schema) ? mcp_tool.output_schema : nil
    end

    def determine_output_type
      return "any" unless mcp_tool.respond_to?(:output_schema) && mcp_tool.output_schema

      schema = mcp_tool.output_schema
      Concerns::Mcp.normalize_type(schema["type"] || schema[:type] || "any")
    end

    def stringify_keys(hash)
      hash.transform_keys(&:to_s)
    end

    def extract_result(response)
      return response unless response.is_a?(Hash) || response.respond_to?(:content)

      content = response.respond_to?(:content) ? response.content : response["content"] || response[:content]
      return response unless content.is_a?(Array)

      texts = content.filter_map do |item|
        item = item.transform_keys(&:to_s) if item.is_a?(Hash)
        item["text"] || item[:text] if item.is_a?(Hash) && (item["type"] || item[:type]) == "text"
      end

      texts.size == 1 ? texts.first : texts.join("\n")
    end
  end
end
