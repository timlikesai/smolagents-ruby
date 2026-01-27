module Smolagents
  module Concerns
    # Error feedback formatting for tool execution.
    #
    # Provides actionable error messages with alternative suggestions
    # when tool calls fail.
    module ErrorFeedback
      GENERIC_NEXT_STEPS = <<~MSG.freeze
        NEXT STEPS:
        - Check arguments and try again
        - Try a different approach
      MSG

      private

      # Formats error messages with actionable suggestions for recovery.
      def format_error_feedback(error, tool_call)
        alternatives = suggest_alternatives(tool_call.name, extract_query(tool_call))

        call_echo = format_call_echo(tool_call)

        case error
        when RateLimitError then rate_limit_feedback(tool_call.name, alternatives, call_echo)
        when ServiceUnavailableError then unavailable_feedback(tool_call.name, alternatives, call_echo)
        else generic_feedback(tool_call.name, error, call_echo)
        end
      end

      def extract_query(tool_call) = tool_call.arguments["query"] || tool_call.arguments[:query]

      def rate_limit_feedback(tool_name, alternatives, call_echo)
        "✗ #{tool_name} is rate limited\n#{call_echo}\n\nNEXT STEPS:\n#{alternatives}"
      end

      def unavailable_feedback(tool_name, alternatives, call_echo)
        "✗ #{tool_name} is temporarily unavailable\n#{call_echo}\n\nNEXT STEPS:\n#{alternatives}"
      end

      def generic_feedback(tool_name, error, call_echo)
        "✗ #{tool_name} failed: #{error.message}\n#{call_echo}\n\n#{GENERIC_NEXT_STEPS}"
      end

      # Formats a tool call echo showing what was called for debugging.
      # Helps models understand what arguments were actually sent.
      def format_call_echo(tool_call)
        args = tool_call.arguments
        return "" if args.nil? || args.empty?

        formatted = args.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
        "Called: #{tool_call.name}(#{formatted})"
      end

      # Suggests alternative actions when a tool fails.
      def suggest_alternatives(failed_tool, query)
        other_search_tools = find_alternative_tools(failed_tool)
        build_suggestions(other_search_tools, query)
      end

      def find_alternative_tools(failed_tool)
        find_tools_by_pattern(/search/) + (tool_exists?("wikipedia") ? ["wikipedia"] : []) - [failed_tool]
      end

      def build_suggestions(tools, query)
        suggestions = tools.filter_map { |tool| "- Try #{tool}(query: \"#{query}\")" if query }
        suggestions << "- If you have results from other tools, call final_answer with that info"
        suggestions << "- If no info available, call final_answer explaining what you couldn't find"
        suggestions.join("\n")
      end
    end
  end
end
