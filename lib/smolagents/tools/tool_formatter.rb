module Smolagents
  module Tools
    # Abstract tool formatting interface.
    #
    # Decouples tool prompt generation from agent type assumptions.
    # Instead of tools knowing about different agent types, formatters
    # encapsulate the formatting logic for each context.
    #
    # == Design
    #
    # Tools implement {Formattable} which provides a single {#format_for}
    # method. Formatters implement {Formatter} and know how to render
    # tool metadata for their specific context.
    #
    # == Available Formatters
    #
    # - {CodeFormatter} - Ruby method signature style for CodeAgent
    # - {ToolCallingFormatter} - Natural language style for ToolCallingAgent
    # - {JsonSchemaFormatter} - OpenAPI-style JSON schema
    #
    # @example Formatting a tool
    #   tool.format_for(:code)          # => "search(query: ...) - ..."
    #   tool.format_for(:tool_calling)  # => "search: ...\n  Takes inputs: ..."
    #
    # @example Custom formatter
    #   class MyFormatter
    #     def format(tool)
    #       "TOOL: #{tool.name}"
    #     end
    #   end
    #   ToolFormatter.register(:custom, MyFormatter.new)
    #   tool.format_for(:custom)  # => "TOOL: search"
    #
    # @see Tool For the base tool class
    # @see Formattable For the mixin that tools include
    module ToolFormatter
      # Registry of formatters by name.
      @formatters = {}

      class << self
        # Register a formatter for a given format type.
        #
        # @param name [Symbol] Format name (e.g., :code, :tool_calling)
        # @param formatter [#format] Formatter instance with #format(tool) method
        # @return [void]
        def register(name, formatter)
          @formatters[name.to_sym] = formatter
        end

        # Get a formatter by name.
        #
        # @param name [Symbol] Format name
        # @return [#format, nil] Formatter or nil if not found
        def [](name)
          @formatters[name.to_sym]
        end

        # Format a tool using the named formatter.
        #
        # @param tool [Tool] Tool to format
        # @param format [Symbol] Format name
        # @return [String] Formatted tool description
        # @raise [ArgumentError] If format is not registered
        def format(tool, format:)
          formatter = self[format]
          unless formatter
            raise ArgumentError,
                  "Unknown tool format: #{format}. Available: #{@formatters.keys.join(", ")}"
          end

          formatter.format(tool)
        end

        # List registered format names.
        #
        # @return [Array<Symbol>] Available format names
        def formats
          @formatters.keys
        end
      end

      # Formats tools as Ruby method signatures for CodeAgent.
      #
      # Output looks like: `name(arg1: desc1, arg2: desc2) - description`
      #
      # @example
      #   CodeFormatter.new.format(search_tool)
      #   # => "search(query: Search query) - Search the web"
      class CodeFormatter
        def format(tool)
          args_doc = tool.inputs.map { |n, s| "#{n}: #{s[:description]}" }.join(", ")
          "#{tool.name}(#{args_doc}) - #{tool.description}"
        end
      end

      # Formats tools as natural language for ToolCallingAgent.
      #
      # Output includes name, description, inputs schema, and return type.
      #
      # @example
      #   ToolCallingFormatter.new.format(search_tool)
      #   # => "search: Search the web\n  Takes inputs: {...}\n  Returns: array"
      class ToolCallingFormatter
        def format(tool)
          "#{tool.name}: #{tool.description}\n  Takes inputs: #{tool.inputs}\n  Returns: #{tool.output_type}\n"
        end
      end

      # Formats managed agent tools with delegation context.
      #
      # Extends ToolCallingFormatter with agent delegation guidance.
      class ManagedAgentFormatter
        def format(tool)
          [
            "#{tool.name}: #{tool.description}",
            "  Use this tool to delegate tasks to the '#{tool.name}' agent.",
            "  Takes inputs: #{tool.inputs}",
            "  Returns: The agent's findings as a string."
          ].join("\n")
        end
      end

      # Register default formatters
      register(:code, CodeFormatter.new)
      register(:tool_calling, ToolCallingFormatter.new)
      register(:managed_agent, ManagedAgentFormatter.new)
    end

    # Mixin for tools to support formatting.
    #
    # Include this in any class that needs to be formatted for agent prompts.
    # Provides a unified {#format_for} method that delegates to formatters.
    #
    # @example Including in a tool
    #   class MyTool < Tool
    #     include Tools::Formattable
    #   end
    #
    #   tool = MyTool.new
    #   tool.format_for(:code)
    module Formattable
      # Format this tool for the given context.
      #
      # @param format [Symbol] Format type (:code, :tool_calling, etc.)
      # @return [String] Formatted tool description
      def format_for(format)
        ToolFormatter.format(self, format:)
      end

      # Legacy method - formats as code prompt.
      # @deprecated Use {#format_for}(:code) instead
      def to_code_prompt
        format_for(:code)
      end

      # Legacy method - formats as tool calling prompt.
      # @deprecated Use {#format_for}(:tool_calling) instead
      def to_tool_calling_prompt
        format_for(:tool_calling)
      end
    end
  end
end
