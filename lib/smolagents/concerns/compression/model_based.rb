module Smolagents
  module Concerns
    module Compression
      # Model-based compression using LLM summarization.
      #
      # Uses a language model to generate concise summaries of agent
      # observations. Extracts key information while reducing token usage.
      #
      # @example Compressing steps
      #   compressor = Object.new.extend(ModelBased)
      #   summary = compressor.compress(old_steps, budget: 200, model: llm)
      #   summary.summary  # => "Agent searched for Ruby docs and found..."
      #
      # @see Strategy Base interface
      module ModelBased
        def self.included(base)
          base.include Events::Emitter
          base.extend ClassMethods
        end

        # Class methods for model-based strategy.
        module ClassMethods
          def strategy_name = :model_based
        end

        # Determines if compression should be triggered.
        # Delegates to Strategy's should_compress? logic.
        #
        # @param memory [Object] Memory object with token_usage_percent
        # @param config [Types::CompressionConfig] Compression configuration
        # @return [Boolean] True if compression should occur
        def should_compress?(memory, config)
          return false unless config.enabled?

          memory.token_usage_percent >= config.threshold
        end

        # Compresses steps into a SummaryStep using model summarization.
        #
        # @param steps [Array<ActionStep>] Steps to compress
        # @param budget [Integer] Token budget for summary
        # @param model [Model] Model to generate summary
        # @return [Types::SummaryStep, nil] Summary step or nil if empty
        def compress(steps, budget:, model:)
          return nil if steps.empty?

          summary_content = generate_summary(steps, model, budget)
          build_summary_step(steps, summary_content)
        end

        # Estimates compression quality.
        #
        # @param original_steps [Array] Steps before compression
        # @param summary_step [Types::SummaryStep] Resulting summary
        # @return [Float] Quality score 0.0-1.0 (higher is better)
        def estimate_quality(original_steps, summary_step)
          original_tokens = original_steps.sum { |s| estimate_step_tokens(s) }
          summary_tokens = estimate_step_tokens(summary_step)
          return 1.0 if original_tokens.zero?

          compression_ratio = 1.0 - (summary_tokens.to_f / original_tokens)
          [compression_ratio, 1.0].min
        end

        private

        def generate_summary(steps, model, budget)
          observations = extract_observations(steps)
          prompt = build_prompt(observations)
          messages = [Types::ChatMessage.user(prompt)]
          response = model.generate(messages, tools: [], max_tokens: budget)
          extract_content(response)
        end

        def extract_observations(steps)
          steps.map { |s| s.observations || s.to_h.inspect }.join("\n---\n")
        end

        def build_prompt(observations)
          "Summarize these agent observations concisely:\n\n#{observations}"
        end

        def extract_content(response)
          response.respond_to?(:content) ? response.content : response.to_s
        end

        def build_summary_step(steps, summary)
          range = steps.first.step_number..steps.last.step_number
          Types::SummaryStep.create(
            summary:,
            original_step_range: range,
            original_step_count: steps.size,
            tokens_saved: estimate_tokens_saved(steps, summary)
          )
        end

        def estimate_tokens_saved(steps, summary)
          original = steps.sum { |s| (s.to_s.length / 4.0).ceil }
          compressed = (summary.length / 4.0).ceil
          [original - compressed, 0].max
        end

        def estimate_step_tokens(step)
          (step.to_s.length / 4.0).ceil
        end
      end
    end
  end
end
