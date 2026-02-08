module Smolagents
  module Concerns
    module Compression
      # Base interface for compression strategies.
      #
      # Provides common methods and a contract for implementing compression
      # approaches. Strategies decide when compression is needed and how
      # to compress steps into summaries.
      #
      # @example Implementing a custom strategy
      #   module MyStrategy
      #     include Concerns::Compression::Strategy
      #
      #     def self.strategy_name = :my_strategy
      #
      #     def compress(steps, budget:, model: nil)
      #       # Build SummaryStep from steps
      #     end
      #   end
      #
      # @see Concerns::Compression::ModelBased Model-based implementation
      module Strategy
        def self.included(base)
          base.extend ClassMethods
        end

        # Class methods for strategy registration.
        module ClassMethods
          # Strategy identifier for configuration.
          #
          # @return [Symbol] Strategy name
          def strategy_name
            raise NotImplementedError, "#{self}.strategy_name must return a Symbol"
          end
        end

        # Determines if compression should be triggered.
        #
        # @param memory [Object] Memory object with token_usage_percent
        # @param config [Types::CompressionConfig] Compression configuration
        # @return [Boolean] True if compression should occur
        def should_compress?(memory, config)
          return false unless config.enabled?

          memory.token_usage_percent >= config.threshold
        end

        # Compresses steps into a SummaryStep.
        #
        # @param steps [Array<ActionStep>] Steps to compress
        # @param budget [Integer] Token budget for summary
        # @param model [Model, nil] Model for summarization (strategy-dependent)
        # @return [Types::SummaryStep, nil] Summary step or nil if empty
        def compress(steps, budget:, model: nil)
          raise NotImplementedError, "#{self.class}#compress must be implemented"
        end

        # Estimates compression quality.
        #
        # @param original_steps [Array] Steps before compression
        # @param summary_step [Types::SummaryStep] Resulting summary
        # @return [Float] Quality score 0.0-1.0 (higher is better compression)
        def estimate_quality(original_steps, summary_step)
          original_tokens = original_steps.sum { |s| estimate_step_tokens(s) }
          summary_tokens = estimate_step_tokens(summary_step)
          return 1.0 if original_tokens.zero?

          compression_ratio = 1.0 - (summary_tokens.to_f / original_tokens)
          [compression_ratio, 1.0].min
        end

        private

        def estimate_step_tokens(step)
          (step.to_s.length / 4.0).ceil
        end
      end
    end
  end
end
