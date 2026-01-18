# frozen_string_literal: true

module Smolagents
  module Models
    module ResilientModelConcerns
      # Fallback chain logic for resilient model generation.
      #
      # Provides methods to build and traverse a chain of fallback models,
      # automatically switching to backups when primary models fail.
      #
      # @example Add fallback models
      #   resilient.with_fallback(backup).with_fallback(emergency)
      module Fallback
        # Add a fallback model.
        #
        # @param fallback_model [Model] Model to use when primary fails
        # @return [self] For chaining
        def with_fallback(fallback_model)
          @fallbacks = (@fallbacks + [fallback_model]).freeze
          self
        end

        # Get the complete model chain.
        #
        # @return [Array<Model>] Base model followed by fallbacks
        def model_chain
          [base_model] + @fallbacks
        end

        # Number of fallback models.
        #
        # @return [Integer]
        def fallback_count = @fallbacks.size

        private

        # Try each model in the chain until one succeeds.
        #
        # @param messages [Array] Messages to send
        # @param state [Hash] Mutable state with :last_error, :attempt
        # @param kwargs [Hash] Additional arguments
        # @return [ChatMessage, nil] Response or nil if all failed
        def try_chain(messages, state, **)
          models = model_chain
          models.each_with_index do |model, idx|
            result = try_model_in_chain(model, models[idx + 1], messages, state, **)
            return result if result
          end
          nil
        end

        # Try a single model in the chain.
        #
        # @param model [Model] Model to try
        # @param next_model [Model, nil] Next model in chain (for failover event)
        # @param messages [Array] Messages to send
        # @param state [Hash] Mutable state hash
        # @param kwargs [Hash] Additional arguments
        # @return [ChatMessage, nil] Response or nil if failed
        def try_model_in_chain(model, next_model, messages, state, **)
          return nil if skip_unhealthy?(model, next_model, state[:attempt])

          policy = model_retry_policy(model)
          result = try_model_with_retry(model, messages, policy, state[:attempt], **)
          return handle_success(model, result) if result[:success]

          state[:last_error] = result[:error]
          state[:attempt] = result[:attempt]
          notify_failover(model, next_model, state[:last_error], state[:attempt]) if next_model
          nil
        end

        # Handle successful generation.
        #
        # @param model [Model] Model that succeeded
        # @param result [Hash] Result hash with :response, :attempt
        # @return [ChatMessage] The response
        def handle_success(model, result)
          notify_recovery(model, result[:attempt]) if result[:attempt] > 1
          result[:response]
        end
      end
    end
  end
end
