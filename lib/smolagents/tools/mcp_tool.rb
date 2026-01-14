module Smolagents
  module Tools
    # Adapter that wraps a Model Context Protocol (MCP) tool for use with Smolagents.
    #
    # MCPTool bridges the MCP ecosystem with Smolagents by wrapping MCP tool
    # definitions and proxying calls through an MCP client. This enables agents
    # to use tools from any MCP-compatible server, including file systems,
    # databases, APIs, and other external services.
    #
    # Tool attributes (name, description, inputs, output_type) are extracted from
    # the MCP tool definition. When executed, arguments are forwarded to the MCP
    # server and responses are parsed to extract text content.
    #
    # @example Using tools from an MCP server
    #   # Fetch tools from an MCP HTTP server
    #   collection = MCPToolCollection.from_http(url: "http://localhost:3000/mcp")
    #
    #   # Each tool in the collection is an MCPTool
    #   file_tool = collection["read_file"]
    #   file_tool.name         # => "read_file"
    #   file_tool.description  # => "Reads contents of a file"
    #   file_tool.inputs       # => { path: { type: "string", ... } }
    #
    #   # Execute the tool (proxied to MCP server)
    #   result = file_tool.call(path: "/etc/hostname")
    #
    # @example Direct instantiation (advanced)
    #   # Create MCP client and fetch tool definition
    #   transport = MCP::Client::HTTP.new(url: server_url)
    #   client = MCP::Client.new(transport: transport)
    #   mcp_tool = client.tools.find { |t| t.name == "query_database" }
    #
    #   # Wrap as Smolagents tool
    #   tool = MCPTool.new(mcp_tool, client: client)
    #   agent = CodeAgent.new(model: model, tools: [tool])
    #
    # @example Inspecting MCP tool capabilities
    #   collection.each do |tool|
    #     puts "#{tool.name}: #{tool.description}"
    #     tool.inputs.each do |name, spec|
    #       puts "  - #{name} (#{spec[:type]}): #{spec[:description]}"
    #     end
    #   end
    #
    # @see MCPToolCollection For loading multiple tools from an MCP server
    # @see Concerns::Mcp MCP protocol utilities and client creation
    # @see Tool Base class for all tools
    class MCPTool < Tool
      # @return [Object] The underlying MCP tool definition
      attr_reader :mcp_tool

      # @return [Object] The MCP client used for tool execution
      attr_reader :client

      # @return [String] The tool name from MCP definition
      attr_reader :tool_name

      # @return [String] The tool description from MCP definition
      attr_reader :description

      # @return [Hash] Input specifications converted from MCP schema
      attr_reader :inputs

      # @return [String] The output type (derived from MCP schema or "any")
      attr_reader :output_type

      # @return [Hash, nil] The output schema from MCP definition, if available
      attr_reader :output_schema

      alias name tool_name

      # Creates a new MCP tool wrapper.
      #
      # @param mcp_tool [Object] MCP tool definition (from client.tools)
      # @param client [Object] MCP client for executing tool calls
      #
      # @raise [ArgumentError] If required tool attributes are missing
      #
      # @example
      #   tool = MCPTool.new(mcp_tool, client: mcp_client)
      def initialize(mcp_tool, client:)
        @mcp_tool = mcp_tool
        @client = client

        define_tool_attributes
        super() # Sets @initialized, calls validate_arguments!
      end

      # Executes the MCP tool with the given arguments.
      #
      # Arguments are forwarded to the MCP server via the client. The response
      # is parsed to extract text content from the MCP result format.
      #
      # @param kwargs [Hash] Named arguments matching the tool's input schema
      # @return [String, Array<String>] Extracted text content from the response
      #
      # @example Single text response
      #   result = tool.execute(query: "SELECT * FROM users")
      #   # => "id,name,email\n1,Alice,alice@example.com\n..."
      #
      # @example Multiple text items in response
      #   result = tool.execute(path: "/var/log")
      #   # => "file1.log\nfile2.log\n..." (joined with newlines)
      def execute(**kwargs)
        response = client.call_tool(tool: mcp_tool, arguments: stringify_keys(kwargs))
        extract_result(response)
      end

      private

      # Extracts tool attributes from the MCP tool definition.
      # @api private
      def define_tool_attributes
        @tool_name = mcp_tool.name
        @description = mcp_tool.description || "MCP tool: #{mcp_tool.name}"
        @inputs = Concerns::Mcp.convert_input_schema(mcp_tool.input_schema)
        @output_type = determine_output_type
        @output_schema = mcp_tool.respond_to?(:output_schema) ? mcp_tool.output_schema : nil
      end

      # Determines output type from MCP schema or defaults to "any".
      # @api private
      def determine_output_type
        return "any" unless mcp_tool.respond_to?(:output_schema) && mcp_tool.output_schema

        schema = mcp_tool.output_schema
        InputSchema.normalize_type(schema["type"] || schema[:type] || "any")
      end

      # Converts symbol keys to strings for MCP protocol.
      # @api private
      def stringify_keys(hash)
        hash.transform_keys(&:to_s)
      end

      # Extracts text content from MCP response format.
      # @api private
      def extract_result(response)
        content = extract_content(response)
        return response unless content

        texts = content.filter_map { |item| extract_text_item(symbolize(item)) }
        texts.size == 1 ? texts.first : texts.join("\n")
      end

      # Extracts content array from various response formats.
      # @api private
      def extract_content(response)
        case symbolize(response)
        in { content: Array => c } then c
        else
          response.content if response.respond_to?(:content) && response.content.is_a?(Array)
        end
      end

      # Extracts text from a content item.
      # @api private
      def extract_text_item(item)
        case item
        in { type: "text", text: String => t } then t
        else nil
        end
      end

      # Converts hash keys to symbols for pattern matching.
      # @api private
      def symbolize(obj)
        return obj unless obj.is_a?(Hash)

        obj.transform_keys(&:to_sym)
      end
    end
  end

  # Re-export MCPTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::MCPTool
  MCPTool = Tools::MCPTool
end
