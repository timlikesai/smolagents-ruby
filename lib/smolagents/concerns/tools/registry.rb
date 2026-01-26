module Smolagents
  module Concerns
    module Tools
      # Centralized tool access registry.
      #
      # This concern is the ONLY place that should access @tools directly.
      # All other code should use registry methods for tool operations.
      #
      # @example Accessing tools
      #   find_tool("search")        # => Tool or nil
      #   tool_exists?("search")     # => true/false
      #   tool_names                 # => ["search", "final_answer"]
      #
      # @example Formatting tools
      #   tool_descriptions          # => "- search: Find web results\n..."
      #   format_tools_for            # => ["search(query: ...) - ...", ...]
      #
      # @see Tool For tool interface
      module Registry
        def self.included(base)
          base.attr_reader :tools
          base.extend ClassMethods
        end

        # === Tool Access ===

        # Find a tool by name.
        # @param name [String, Symbol] Tool name
        # @return [Tool, nil] The tool or nil if not found
        def find_tool(name) = @tools[name.to_s]

        # Check if a tool exists.
        # @param name [String, Symbol] Tool name
        # @return [Boolean] True if tool exists
        def tool_exists?(name) = @tools.key?(name.to_s)

        # Get the number of tools.
        # @return [Integer] Tool count
        def tool_count = @tools.size

        # Get all tool names.
        # @return [Array<String>] Tool names
        def tool_names = @tools.keys

        # Get all tool instances.
        # @return [Array<Tool>] Tool instances
        def tool_values = @tools.values

        # === Tool Formatting ===

        # Generate tool descriptions for prompts.
        # @return [String] Formatted descriptions (one per line)
        def tool_descriptions
          @tools.values.map { "- #{it.name}: #{it.description}" }.join("\n")
        end

        # Generate brief tool list (name and first sentence only).
        # @return [String] Brief tool list
        def tool_list_brief
          @tools.map { |name, tool| "#{name}: #{tool.description.split(".").first}" }.join("\n")
        end

        # Format tools for prompts.
        # @param format [Symbol] Format type (default: :default)
        # @return [Array<String>] Formatted tool definitions
        def format_tools_for(format = :default)
          @tools.values.map { it.format_for(format) }
        end

        # === Tool Filtering ===

        # Find tools matching a filter.
        # @param keys [Array<String>, nil] Specific keys to include (nil = all)
        # @param exclude [Array<String>] Keys to exclude
        # @return [Array<Tool>] Matching tools
        def select_tools(keys: nil, exclude: [])
          result = keys ? @tools.slice(*keys.map(&:to_s)).values : @tools.values
          exclude_set = exclude.to_set(&:to_s)
          result.reject { exclude_set.include?(it.name) }
        end

        # Find tools by name pattern.
        # @param pattern [String, Regexp] Name pattern to match
        # @return [Array<String>] Matching tool names
        def find_tools_by_pattern(pattern)
          regex = pattern.is_a?(Regexp) ? pattern : /#{Regexp.escape(pattern)}/
          @tools.keys.grep(regex)
        end

        # === Self-Documentation ===

        # Get a summary of available tools.
        # @return [Hash] Summary with count, names, and categories
        def tools_summary
          {
            count: tool_count,
            names: tool_names,
            by_category: tools_by_category
          }
        end

        # Group tools by category.
        # @return [Hash<Symbol, Array<String>>] Tools grouped by category
        def tools_by_category
          @tools.values.group_by { |t| t.respond_to?(:category) ? (t.category || :uncategorized) : :uncategorized }
                .transform_values { |tools| tools.map(&:name) }
        end

        # Module for class-level introspection
        module ClassMethods
          # Get registry method documentation.
          # @return [Hash<Symbol, Array<Symbol>>] Methods by category
          def registry_methods
            {
              access: %i[find_tool tool_exists? tool_count tool_names tool_values],
              formatting: %i[tool_descriptions tool_list_brief format_tools_for],
              filtering: %i[select_tools find_tools_by_pattern],
              introspection: %i[tools_summary tools_by_category]
            }
          end
        end
      end
    end
  end
end
