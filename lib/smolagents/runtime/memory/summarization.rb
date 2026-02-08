module Smolagents
  module Runtime
    module Memory
      # Context compression via model-generated summaries.
      #
      # When memory exceeds a configurable token threshold, selects
      # oldest action steps (beyond preserve_recent window) and replaces
      # them with a SummaryStep containing a model-generated summary.
      #
      # @example
      #   memory.compress_if_needed!(model: @model)
      module Summarization
        # Compress memory if usage exceeds threshold.
        #
        # @param model [Models::Model] Model to generate summary
        # @param threshold [Float] Usage fraction to trigger (default: 0.75)
        # @return [Types::SummaryStep, nil] Summary step if compressed
        def compress_if_needed!(model:, threshold: 0.75)
          return unless should_compress?(threshold)

          compressible = select_compressible_steps
          return if compressible.empty?

          summary_text = generate_summary(model, compressible)
          replace_with_summary!(compressible, summary_text)
        end

        private

        def should_compress?(threshold)
          return false unless %i[summarize hybrid].include?(config.strategy)
          return false unless config.budget?

          token_usage_percent > threshold
        end

        # @return [Float] Current usage as fraction (0.0-1.0+)
        def token_usage_percent
          return 0.0 unless config.budget? && config.budget.positive?

          estimated_tokens.to_f / config.budget
        end

        def select_compressible_steps
          action = action_steps.to_a
          preserve = config.preserve_recent || 3
          return [] if action.size <= preserve

          action[0..-(preserve + 1)]
        end

        def generate_summary(model, compressible_steps)
          observations = compressible_steps.map { |s| s.observations || s.to_h.inspect }
          prompt = "Summarize these agent observations concisely:\n#{observations.join("\n---\n")}"
          messages = [Types::ChatMessage.user(prompt)]
          response = model.generate(messages, tools: [], max_tokens: 200)
          response.respond_to?(:content) ? response.content : response.to_s
        end

        def replace_with_summary!(compressible_steps, summary_text)
          tokens_before = estimated_tokens
          build_and_insert_summary(compressible_steps, summary_text, tokens_before)
        end

        def build_and_insert_summary(compressible_steps, summary_text, tokens_before)
          range = compressible_steps.first.step_number..compressible_steps.last.step_number
          @steps.reject! { |s| compressible_steps.include?(s) }
          insert_idx = @steps.index { |s| s.is_a?(Types::ActionStep) } || @steps.size
          summary = Types::SummaryStep.create(
            summary: summary_text, original_step_range: range,
            original_step_count: compressible_steps.size,
            tokens_saved: [tokens_before - estimated_tokens, 0].max
          )
          @steps.insert(insert_idx, summary)
          summary
        end
      end
    end
  end
end
