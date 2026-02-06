# Execution, parsing, tools, and formatting concern registrations.
module Smolagents
  module Concerns
    Registry.tap do |r| # rubocop:disable Metrics/BlockLength -- registration data
      # === Tools ===
      r.register :tool_schema,
                 Smolagents::Concerns::ToolSchema,
                 category: :tools,
                 provides: %i[tool_properties tool_required_fields json_schema_type],
                 description: "Tool schema conversion utilities"

      r.register :mcp,
                 Smolagents::Concerns::Mcp,
                 category: :tools,
                 provides: %i[mcp_tool_definition execute_mcp_call],
                 description: "Model Context Protocol support"

      # === Execution ===
      r.register :code_execution,
                 Smolagents::Concerns::CodeExecution,
                 category: :execution,
                 provides: %i[execute_code build_execution_context],
                 description: "Sandboxed Ruby code execution"

      r.register :step_execution,
                 Smolagents::Concerns::StepExecution,
                 category: :execution,
                 provides: %i[execute_step step_duration],
                 description: "Step timing and execution wrapper"

      r.register :native_tool_execution,
                 Smolagents::Concerns::NativeToolExecution,
                 category: :execution,
                 provides: %i[execute_native_step run_tool],
                 description: "Native tool calling execution (OpenAI function calling)"

      r.register :code_generation,
                 Smolagents::Concerns::CodeGeneration,
                 category: :execution,
                 provides: %i[generate_code extract_code],
                 description: "Code generation from model output"

      r.register :code_parsing,
                 Smolagents::Concerns::CodeParsing,
                 category: :execution,
                 provides: %i[parse_action extract_tool_calls],
                 description: "Parse actions from model output"

      # === Parsing ===
      r.register :json_parsing,
                 Smolagents::Concerns::Json,
                 category: :parsing,
                 provides: %i[extract_json parse_json_safely extract_code_block],
                 description: "JSON extraction from LLM responses"

      r.register :xml_parsing,
                 Smolagents::Concerns::Xml,
                 category: :parsing,
                 provides: %i[extract_xml parse_xml_safely],
                 description: "XML extraction and parsing"

      r.register :html_parsing,
                 Smolagents::Concerns::Html,
                 category: :parsing,
                 provides: %i[extract_text extract_links simplify_html],
                 description: "HTML content extraction"

      # === Formatting ===
      r.register :result_formatting,
                 Smolagents::Concerns::ResultFormatting,
                 category: :formatting,
                 provides: %i[format_result format_tool_output],
                 description: "Tool result formatting"

      r.register :message_formatting,
                 Smolagents::Concerns::MessageFormatting,
                 category: :formatting,
                 provides: %i[format_messages format_chat_message],
                 description: "Chat message formatting"
    end
  end
end
