module Smolagents
  module Concerns
    # Error feedback formatting for tool execution.
    #
    # Categorizes errors (syntax, tool not found, wrong arguments) and
    # provides actionable recovery messages with specific next steps.
    module ErrorFeedback
      private

      # Formats error messages with actionable suggestions for recovery.
      def format_error_feedback(error, tool_call)
        alternatives = suggest_alternatives(tool_call.name, extract_query(tool_call))
        call_echo = format_call_echo(tool_call)

        case error
        when RateLimitError then rate_limit_feedback(tool_call.name, alternatives, call_echo)
        when ServiceUnavailableError then unavailable_feedback(tool_call.name, alternatives, call_echo)
        else categorized_feedback(tool_call, error, call_echo)
        end
      end

      def extract_query(tool_call) = tool_call.arguments["query"] || tool_call.arguments[:query]

      def rate_limit_feedback(tool_name, alternatives, call_echo)
        "✗ #{tool_name} is rate limited\n#{call_echo}\n\nNEXT STEPS:\n#{alternatives}"
      end

      def unavailable_feedback(tool_name, alternatives, call_echo)
        "✗ #{tool_name} is temporarily unavailable\n#{call_echo}\n\nNEXT STEPS:\n#{alternatives}"
      end

      def categorized_feedback(tool_call, error, call_echo)
        header = "✗ #{tool_call.name} failed: #{error.message}\n#{call_echo}"
        "#{header}\n\nNEXT STEPS:\n#{categorize_error_steps(tool_call, error.message)}"
      end

      def categorize_error_steps(tool_call, message)
        case message
        when /syntax error/i then syntax_error_steps(tool_call.name)
        when /not found|unknown tool/i then tool_not_found_steps
        when /missing required input|unexpected input|wrong number of arg/i
          wrong_arguments_steps(tool_call.name)
        else generic_error_steps
        end
      end

      def syntax_error_steps(tool_name)
        "- Check brackets, quotes, and keyword pairs (do/end, if/end)\n" \
          "- Correct format: result = #{tool_name}(key: \"value\")\n" \
          "- Use help(:#{tool_name}) to see the expected signature"
      end

      def tool_not_found_steps
        names = respond_to?(:tool_names) ? tool_names.join(", ") : "unknown"
        "- Available tools: #{names}\n- Use help(:tool_name) to see usage for any tool"
      end

      def wrong_arguments_steps(tool_name)
        "- Expected: #{tool_signature_for(tool_name)}\n" \
          "- Use help(:#{tool_name}) to see full usage details"
      end

      def generic_error_steps
        "- Check arguments and try again\n" \
          "- Use help(:tool_name) to see expected inputs\n" \
          "- Try a different tool or approach"
      end

      def tool_signature_for(name)
        tool = respond_to?(:find_tool) && find_tool(name)
        return "#{name}(...)" unless tool.respond_to?(:inputs)

        args = tool.inputs.map { |k, s| "#{k}: #{s[:type] || s["type"]}" }.join(", ")
        "#{name}(#{args})"
      end

      def format_call_echo(tool_call)
        args = tool_call.arguments
        return "" if args.nil? || args.empty?

        formatted = args.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
        "Called: #{tool_call.name}(#{formatted})"
      end

      def suggest_alternatives(failed_tool, query) = build_suggestions(find_alternative_tools(failed_tool), query)

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
