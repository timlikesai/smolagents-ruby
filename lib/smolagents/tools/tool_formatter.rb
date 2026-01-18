module Smolagents
  module Tools
    # Tool formatting for agent prompts.
    #
    # All agents think in Ruby code, so tools are formatted as method signatures.
    #
    # @example Formatting a tool
    #   tool.format_for(:code)  # => "search(query: ...) - ..."
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

      # Default formatter - Ruby method signatures.
      #
      # Output: `name(arg1: desc1, arg2: desc2) - description`
      #
      # @example
      #   DefaultFormatter.new.format(search_tool)
      #   # => "search(query: Search query) - Search the web"
      class DefaultFormatter
        def format(tool)
          args_doc = tool.inputs.map { |n, s| "#{n}: #{s[:description]}" }.join(", ")
          "#{tool.name}(#{args_doc}) - #{tool.description}"
        end
      end

      # Formats managed agent tools with delegation context.
      class ManagedAgentFormatter
        def format(tool)
          [
            "#{tool.name}: #{tool.description}",
            "  Delegate tasks to the '#{tool.name}' agent.",
            "  Takes inputs: #{tool.inputs}",
            "  Returns: The agent's findings as a string."
          ].join("\n")
        end
      end

      # Register formatters
      register(:default, DefaultFormatter.new)
      register(:code, DefaultFormatter.new) # Alias for backwards compat
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
    end
  end
end
