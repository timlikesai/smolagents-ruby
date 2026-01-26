# Custom RuboCop cop to require comments on rubocop:disable directives
# Ensures all disabled rules have documented rationale

module RuboCop
  module Cop
    module Smolagents
      # Requires explanation comments on rubocop:disable directives.
      #
      # Every disable should document WHY the rule is being disabled.
      # This helps future maintainers understand the intent.
      #
      class RequireDisableComment < Base
        MSG = "Add explanation after `rubocop:disable` using ` -- reason here`. " \
              "Document why this rule must be disabled for future maintainers.".freeze

        def on_new_investigation
          processed_source.comments.each { |comment| check_disable_comment(comment) }
        end

        private

        def check_disable_comment(comment)
          text = comment.text

          # Match rubocop:disable without explanation
          return unless text.match?(%r{rubocop:disable\s+[\w/,\s]+\s*$})

          # Skip if there's an explanation after --
          return if text.include?(" -- ")

          add_offense(comment)
        end
      end
    end
  end
end
