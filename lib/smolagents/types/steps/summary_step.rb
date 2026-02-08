module Smolagents
  module Types
    # Represents a compressed summary replacing multiple action steps.
    #
    # Created by the context compression system when memory exceeds
    # the configured threshold. Contains a model-generated summary
    # of the original steps.
    #
    # @!attribute [r] summary [String] Model-generated summary text
    # @!attribute [r] original_step_range [Range] Step numbers summarized
    # @!attribute [r] original_step_count [Integer] How many steps were compressed
    # @!attribute [r] tokens_saved [Integer] Estimated tokens freed
    #
    # @example
    #   step = SummaryStep.create(summary: "Searched for Ruby docs, found v3.3 release notes")
    #   step.to_messages  #=> [ChatMessage(role: :assistant, content: "[Summary] ...")]
    SummaryStep = Data.define(:summary, :original_step_range, :original_step_count, :tokens_saved) do
      def self.create(summary:, original_step_range: nil, original_step_count: 0, tokens_saved: 0)
        new(summary:, original_step_range:, original_step_count:, tokens_saved:)
      end

      def to_messages
        [ChatMessage.assistant("[Summary of #{original_step_count} steps] #{summary}")]
      end

      def to_h
        { type: :summary, summary:, original_step_range: original_step_range&.to_s,
          original_step_count:, tokens_saved: }
      end

      def deconstruct_keys(_) = { summary:, original_step_range:, original_step_count:, tokens_saved: }
    end
  end
end
