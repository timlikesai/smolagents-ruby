module Smolagents
  module Concerns
    # Fallback chain management for model failover.
    #
    # Provides methods to build and traverse a chain of fallback models,
    # switching to backup models when primary ones fail.
    #
    # @example Building a fallback chain
    #   model.with_fallback(backup_model).with_fallback(emergency_model)
    module ModelFallback
      # Add a fallback model to use when this model fails
      #
      # @param fallback_model [Model] Model to use as fallback
      # @return [self] For chaining
      def with_fallback(fallback_model)
        @fallback_chain ||= []
        @fallback_chain << fallback_model
        self
      end

      # Get the complete model chain including self and all fallbacks.
      #
      # @return [Array<Model>] Array with self as first element, followed by fallbacks
      def model_chain
        [self] + (@fallback_chain || [])
      end

      # Try each model in the chain until one succeeds.
      #
      # @param messages [Array] Messages to send
      # @param state [Hash] Mutable state hash with :last_error and :attempt
      # @param kwargs [Hash] Additional arguments for generate
      # @yield [model, next_model, messages, state] Block to try each model
      # @return [Object, nil] Result from successful model or nil
      def try_chain(messages, state, **)
        models = model_chain
        models.each_with_index do |model, idx|
          result = yield(model, models[idx + 1], messages, state)
          return result if result
        end
        nil
      end

      # Clear the fallback chain.
      #
      # @return [self] For chaining
      def clear_fallbacks
        @fallback_chain = nil
        self
      end

      # Get the number of fallback models configured.
      #
      # @return [Integer] Number of fallback models
      def fallback_count
        @fallback_chain&.size || 0
      end
    end
  end
end
