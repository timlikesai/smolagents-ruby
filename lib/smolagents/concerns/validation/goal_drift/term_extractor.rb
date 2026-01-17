module Smolagents
  module Concerns
    module GoalDrift
      # Extracts key terms from text for drift comparison.
      #
      # Handles term extraction from both task descriptions and step content,
      # filtering stop words and extracting important entities.
      module TermExtractor
        # Common stop words to filter during term extraction.
        STOP_WORDS = %w[
          the a an is are was were be been being have has had do does did
          will would could should may might must shall can to of and in
          for on with at by from or but not this that these those it its
        ].freeze

        private

        # Extracts key terms from text for comparison.
        #
        # @param text [String] Text to extract from
        # @return [Set<String>] Set of key terms
        def extract_key_terms(text)
          return Set.new if text.nil? || text.empty?

          text.to_s.downcase
              .gsub(/[^a-z0-9\s]/, " ")
              .split(/\s+/)
              .reject { |w| w.length < 3 || STOP_WORDS.include?(w) }
              .to_set
        end

        # Builds text representation of a step for analysis.
        #
        # @param step [ActionStep] Step to convert
        # @return [String] Text representation
        def build_step_text(step)
          parts = extract_tool_call_parts(step)
          parts << step.code_action.to_s if step.code_action
          parts << step.observations.to_s if step.observations
          parts << step.action_output.to_s if step.action_output
          parts.join(" ")
        end

        def extract_tool_call_parts(step)
          return [] unless step.tool_calls&.any?

          step.tool_calls.flat_map do |tc|
            args_text = tc.arguments&.values&.map(&:to_s)
            [tc.name.to_s, args_text&.join(" ")].compact
          end
        end

        # Counts important keyword matches between task and step.
        #
        # @param task [String] Original task
        # @param step_text [String] Step text
        # @return [Integer] Number of important matches
        def count_important_matches(task, step_text)
          important = task.scan(/["']([^"']+)["']|\b([A-Z][a-z]+)\b/).flatten.compact
          return 0 if important.empty?

          step_lower = step_text.downcase
          important.count { |term| step_lower.include?(term.downcase) }
        end
      end
    end
  end
end
