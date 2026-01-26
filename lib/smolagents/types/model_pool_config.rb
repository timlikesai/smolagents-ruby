module Smolagents
  module Types
    # Configuration for multi-model pool management.
    #
    # ModelPoolConfig holds the mapping of purposes to model factories,
    # enabling agents to use different models for different tasks (planning,
    # execution, evaluation, etc.).
    #
    # @example Single model (backwards compatible)
    #   config = ModelPoolConfig.single { OpenAIModel.new(model_id: "gpt-4") }
    #   config.purposes  # => [:default]
    #
    # @example Multi-model configuration
    #   config = ModelPoolConfig.create
    #     .with_model(:execution) { OpenAIModel.lm_studio("gemma") }
    #     .with_model(:planning) { AnthropicModel.new(model_id: "claude-sonnet") }
    #     .with_model(:evaluation) { OpenAIModel.new(model_id: "gpt-4o-mini") }
    #
    # @see Concerns::Orchestration::ModelPool For pool management
    ModelPoolConfig = Data.define(:model_factories, :default_purpose, :selection_strategy) do
      include TypeSupport::Deconstructable

      # Known model purposes
      PURPOSES = %i[default execution planning evaluation summarization code_review].freeze

      # Selection strategies for choosing between multiple models at same purpose
      STRATEGIES = %i[first health_aware round_robin].freeze

      # Create an empty configuration.
      # @return [ModelPoolConfig]
      def self.create
        new(model_factories: {}.freeze, default_purpose: :default, selection_strategy: :first)
      end

      # Create a single-model configuration (backwards compatible).
      # @yield Block that returns a Model instance
      # @return [ModelPoolConfig]
      def self.single(&)
        create.with_model(:default, &)
      end

      # Add a model for a specific purpose.
      # @param purpose [Symbol] The purpose (:execution, :planning, etc.)
      # @yield Block that returns a Model instance
      # @return [ModelPoolConfig] New config with model added
      def with_model(purpose, &block)
        raise ArgumentError, "Block required for model factory" unless block

        new_factories = model_factories.merge(purpose => block).freeze
        with(model_factories: new_factories)
      end

      # Set the default purpose when none specified.
      # @param purpose [Symbol] Default purpose to use
      # @return [ModelPoolConfig] New config with default set
      def with_default(purpose)
        with(default_purpose: purpose)
      end

      # Set the selection strategy.
      # @param strategy [Symbol] Selection strategy (:first, :health_aware, :round_robin)
      # @return [ModelPoolConfig] New config with strategy set
      def with_strategy(strategy)
        raise ArgumentError, "Unknown strategy: #{strategy}" unless STRATEGIES.include?(strategy)

        with(selection_strategy: strategy)
      end

      # List configured purposes.
      # @return [Array<Symbol>] Purposes with models registered
      def purposes = model_factories.keys

      # Check if a purpose has a model.
      # @param purpose [Symbol] Purpose to check
      # @return [Boolean]
      # rubocop:disable Naming/PredicatePrefix -- has_model? reads better than model?
      def has_model?(purpose) = model_factories.key?(purpose)
      # rubocop:enable Naming/PredicatePrefix

      # Check if only a default model is configured (single-model mode).
      # @return [Boolean]
      def single_model? = purposes == [:default]

      # Check if multi-model mode is active.
      # @return [Boolean]
      def multi_model? = purposes.size > 1 || (purposes.size == 1 && purposes.first != :default)

      # Get the factory for a purpose, falling back to default.
      # @param purpose [Symbol] Desired purpose
      # @return [Proc, nil] Factory block or nil if not found
      def factory_for(purpose)
        model_factories[purpose] || model_factories[default_purpose] || model_factories[:default]
      end

      # Instantiate a model for the given purpose.
      # @param purpose [Symbol] Purpose to get model for
      # @return [Model] Instantiated model
      # @raise [ArgumentError] If no model configured for purpose
      def resolve_model(purpose = nil)
        effective_purpose = purpose || default_purpose
        factory = factory_for(effective_purpose)
        raise ArgumentError, "No model configured for purpose: #{effective_purpose}" unless factory

        factory.call
      end

      private

      def with(**)
        self.class.new(**to_h, **)
      end
    end
  end
end
