require_relative "tools/registry"
require_relative "tools/schema"
require_relative "tools/mcp"

module Smolagents
  module Concerns
    # Tool behavior concerns for building custom tools.
    #
    # This module re-exports tool-specific concerns for easy access.
    # Each concern can be included independently or composed together.
    #
    # @!group Concern Dependency Graph
    #
    # == Dependency Matrix
    #
    #   | Concern    | Depends On | Depended By      | Auto-Includes |
    #   |------------|------------|------------------|---------------|
    #   | Registry   | -          | Agent, ReActLoop | -             |
    #   | ToolSchema | -          | Tool             | -             |
    #   | Mcp        | -          | McpTool          | -             |
    #
    # == Sub-concern Methods
    #
    #   Registry
    #       +-- find_tool(name) - Find a tool by name
    #       +-- tool_exists?(name) - Check if a tool exists
    #       +-- tool_count - Get the number of tools
    #       +-- tool_names - Get all tool names
    #       +-- tool_values - Get all tool instances
    #       +-- tool_descriptions - Generate tool descriptions for prompts
    #       +-- tool_list_brief - Brief tool list (name and first sentence)
    #       +-- format_tools_for(format) - Format tools for model consumption
    #       +-- select_tools(keys:, exclude:) - Filter tools
    #       +-- find_tools_by_pattern(pattern) - Find tools by name pattern
    #       +-- tools_summary - Get summary of available tools
    #       +-- tools_by_category - Group tools by category
    #
    #   ToolSchema
    #       +-- to_openai_schema - Convert tool to OpenAI function format
    #       +-- to_anthropic_schema - Convert tool to Anthropic format
    #       +-- to_json_schema - Convert inputs to JSON Schema
    #       +-- validate_inputs!(args) - Validate arguments against schema
    #
    #   Mcp (Model Context Protocol)
    #       +-- mcp_tool_definition - Get MCP-compatible tool definition
    #       +-- execute_mcp_call(params) - Execute via MCP protocol
    #
    # @!endgroup
    #
    # @see ToolSchema For schema conversion utilities
    # @see Mcp For Model Context Protocol support
    module Tools
    end
  end
end
