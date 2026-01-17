module Smolagents
  module Concerns
    module SelfRefine
      # Prompt building and critique parsing for self-refinement.
      #
      # Uses CritiqueParsing from concerns/parsing/critique.rb for shared logic.
      module Prompts
        # System prompt for self-critique.
        CRITIQUE_SYSTEM = <<~PROMPT.strip.freeze
          You are a code reviewer. Identify specific issues that can be fixed.
          Be concise. If the code is correct, say "LGTM".
        PROMPT

        private

        # Gets feedback through self-critique.
        #
        # Only recommended for capable models.
        #
        # @param output [Object] Current output
        # @param task [String] Original task
        # @param iteration [Integer] Current iteration
        # @return [Smolagents::Types::RefinementFeedback]
        def self_critique_feedback(output, task, iteration)
          prompt = build_critique_prompt(output, task)
          messages = [
            ChatMessage.system(CRITIQUE_SYSTEM),
            ChatMessage.user(prompt)
          ]

          response = @model.generate(messages, max_tokens: 150)
          parse_self_critique_response(response.content, iteration)
        end

        def build_critique_prompt(output, task)
          <<~PROMPT
            Task: #{task}
            Output: #{output.to_s.slice(0, 500)}

            Review this output. Is it correct and complete?
            If issues exist, describe ONE specific fix.
            Format: ISSUE: <problem> | FIX: <solution>
            Or if correct: LGTM
          PROMPT
        end

        def parse_self_critique_response(content, iteration)
          text = content.strip
          return lgtm_feedback(iteration) if text.upcase.include?("LGTM") || text.upcase.include?("LOOKS GOOD")
          return issue_fix_feedback(text, iteration) if /ISSUE:\s*(.+?)\s*\|\s*FIX:\s*(.+)/mi.match?(text)

          self_feedback(iteration, text, text.length > 20, 0.5)
        end

        def lgtm_feedback(iteration) = self_feedback(iteration, "Code looks good", false, 0.8)

        def issue_fix_feedback(text, iteration)
          text =~ /ISSUE:\s*(.+?)\s*\|\s*FIX:\s*(.+)/mi
          self_feedback(iteration, "#{::Regexp.last_match(1).strip}. Fix: #{::Regexp.last_match(2).strip}", true, 0.7)
        end

        def self_feedback(iteration, critique, actionable, confidence)
          Smolagents::Types::RefinementFeedback.new(iteration:, source: :self, critique:, actionable:, confidence:)
        end

        # Applies refinement by asking model to fix based on feedback.
        #
        # @param current_output [Object] Current output to refine
        # @param feedback [Smolagents::Types::RefinementFeedback] Feedback to apply
        # @param task [String] Original task
        # @return [Object] Refined output
        REFINE_SYSTEM = "You fix code based on feedback. Output only the corrected code.".freeze

        def apply_refinement(current_output, feedback, task)
          messages = [ChatMessage.system(REFINE_SYSTEM),
                      ChatMessage.user(refinement_prompt(current_output, feedback, task))]
          @model.generate(messages, max_tokens: 500).content.strip
        end

        def refinement_prompt(current_output, feedback, task)
          truncated = current_output.to_s.slice(0, 500)
          "Task: #{task}\nCurrent code/output: #{truncated}\nFeedback: #{feedback.critique}" \
            "\n\nFix the issue and provide the corrected code only."
        end
      end
    end
  end
end
