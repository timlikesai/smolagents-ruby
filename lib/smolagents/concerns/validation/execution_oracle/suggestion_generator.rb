module Smolagents
  module Concerns
    module ExecutionOracle
      # Generates actionable fix suggestions for errors.
      module SuggestionGenerator
        # Generates a fix suggestion based on error category and details.
        STATIC_SUGGESTIONS = {
          timeout: "Simplify the code or break into smaller steps.",
          memory_limit: "Reduce data size or process in smaller batches.",
          operation_limit: "Reduce loop iterations or use more efficient algorithms."
        }.freeze

        def generate_suggestion(category, details, code)
          return STATIC_SUGGESTIONS[category] if STATIC_SUGGESTIONS.key?(category)

          dynamic_suggestion(category, details, code)
        end

        def dynamic_suggestion(category, details, code)
          case category
          in :syntax_error then syntax_suggestion(details)
          in :name_error then name_error_suggestion(details, code)
          in :no_method_error then no_method_suggestion(details)
          in :type_error then type_error_suggestion(details)
          in :argument_error then argument_error_suggestion(details)
          in :tool_error then tool_error_suggestion(details)
          else "Check the error message and try a different approach."
          end
        end

        private

        def syntax_suggestion(details)
          parts = []
          parts << "Remove or fix '#{details[:unexpected]}'" if details[:unexpected]
          parts << "Add '#{details[:expecting]}'" if details[:expecting]
          parts << "Check brackets, quotes, and keyword pairs (do/end, if/end)" if parts.empty?
          parts.join(". ")
        end

        def name_error_suggestion(details, code)
          name = details[:undefined_name]
          return "Check variable/method name spelling." unless name

          similar = find_similar_names(name, code)
          similar.any? ? "Did you mean: #{similar.join(", ")}?" : "Define '#{name}' before using it, or check spelling."
        end

        def no_method_suggestion(details)
          method = details[:undefined_method]
          receiver = details[:receiver_class]
          return "Method '#{method}' doesn't exist. Check spelling or use a different approach." unless receiver

          "#{receiver} doesn't have method '#{method}'. Check available methods."
        end

        def type_error_suggestion(details)
          from, to = details.values_at(:from_type, :to_type)
          return "Check types and add explicit conversions where needed." unless from && to

          "Convert #{from} to #{to} explicitly (e.g., .to_s, .to_i, .to_f)."
        end

        def argument_error_suggestion(details)
          given, expected = details.values_at(:given, :expected)
          return "Check the method signature and pass the correct number of arguments." unless given && expected

          "Pass #{expected} argument(s) instead of #{given}."
        end

        def tool_error_suggestion(details)
          tool = details[:tool_name]
          return "The requested tool is not available. List available tools and choose another." unless tool

          "Tool '#{tool}' is not available. Use a different tool or check the name."
        end

        def find_similar_names(target, code)
          return [] unless code

          code.scan(/\b([a-z_][a-z0-9_]*)\b/i).flatten.uniq.select { |id| similar?(target, id) }.first(3)
        end

        def similar?(first, second)
          return false if first == second
          return true if first.downcase == second.downcase

          first.start_with?(second[0, 3]) || second.start_with?(first[0, 3]) ||
            first.end_with?(second[-3..]) || second.end_with?(first[-3..])
        end
      end
    end
  end
end
