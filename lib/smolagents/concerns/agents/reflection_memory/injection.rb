module Smolagents
  module Concerns
    module ReflectionMemory
      # Prompt integration for reflection memory.
      #
      # Handles formatting and injecting reflections into task prompts.
      module Injection
        private

        # Formats reflections for injection into agent context.
        #
        # @param reflections [Array<Types::Reflection>] Reflections to format
        # @return [String] Formatted reflection context
        def format_reflections_for_context(reflections)
          return "" if reflections.empty?

          header = "## Lessons from Previous Attempts\n\n"
          body = reflections.map.with_index(1) do |r, i|
            "#{i}. #{r.to_context}"
          end.join("\n\n")

          "#{header}#{body}\n"
        end

        # Injects reflections into task prompt if available.
        #
        # @param task [String] The original task
        # @return [String] Task with reflections prepended
        def inject_reflections(task)
          reflections = get_relevant_reflections(task)
          return task if reflections.empty?

          context = format_reflections_for_context(reflections)
          "#{context}\n## Current Task\n\n#{task}"
        end
      end
    end
  end
end
