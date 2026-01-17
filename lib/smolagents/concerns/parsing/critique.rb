module Smolagents
  module Concerns
    # Critique parsing for self-refine and mixed-refinement loops.
    #
    # Provides shared parsing logic for model feedback in the format:
    # - APPROVED / LGTM / LOOKS GOOD (no action needed)
    # - ISSUE: <description> | FIX: <specific fix> (actionable)
    #
    # @example Parse model critique
    #   class MyAgent
    #     include Concerns::CritiqueParsing
    #
    #     def get_feedback(output, task, iteration)
    #       response = model.generate(critique_messages(output, task))
    #       parse_critique_response(response.content, iteration)
    #     end
    #   end
    #
    # @see SelfRefine Uses this for self-critique
    # @see MixedRefinement Uses this for cross-model critique
    module CritiqueParsing
      # Pattern for structured ISSUE/FIX format.
      ISSUE_FIX_PATTERN = /ISSUE:\s*(.+?)\s*\|\s*FIX:\s*(.+)/mi

      # Approval indicators (case-insensitive).
      APPROVAL_PATTERNS = %w[APPROVED LGTM].freeze

      # Parse critique response into RefinementFeedback.
      #
      # @param content [String] Model response content
      # @param iteration [Integer] Current iteration number
      # @param source [Symbol] Feedback source (:self, :execution, :evaluation)
      # @return [SelfRefine::RefinementFeedback]
      def parse_critique_response(content, iteration, source: :self)
        text = content.to_s.strip
        upper = text.upcase

        return approval_feedback(iteration, source) if approved?(upper)
        return issue_fix_feedback(text, iteration, source) if text.match?(ISSUE_FIX_PATTERN)

        unclear_feedback(text, iteration, source)
      end

      private

      def approved?(upper_text)
        APPROVAL_PATTERNS.any? { |pattern| upper_text.include?(pattern) } ||
          upper_text.include?("LOOKS GOOD")
      end

      def approval_feedback(iteration, source)
        SelfRefine::RefinementFeedback.new(
          iteration:, source:, critique: "Code approved by reviewer",
          actionable: false, confidence: 0.9
        )
      end

      def issue_fix_feedback(text, iteration, source)
        text.match(ISSUE_FIX_PATTERN)
        issue, fix = ::Regexp.last_match.captures.map(&:strip)
        SelfRefine::RefinementFeedback.new(
          iteration:, source:, critique: "#{issue}. Fix: #{fix}",
          actionable: true, confidence: 0.8
        )
      end

      def unclear_feedback(text, iteration, source)
        SelfRefine::RefinementFeedback.new(
          iteration:, source:, critique: text.slice(0, 200),
          actionable: actionable_heuristic?(text),
          confidence: 0.5
        )
      end

      def actionable_heuristic?(text)
        text.length > 30 && !text.upcase.include?("GOOD")
      end
    end
  end
end
