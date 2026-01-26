module Smolagents
  module Concerns
    module Orchestration
      # Multi-model pool for purpose-based model selection.
      #
      # ModelPool enables agents to use different models for different purposes
      # (planning, execution, evaluation, etc.) with health-aware selection and
      # fallback support.
      #
      # @example Basic usage
      #   class MyOrchestrator
      #     include ModelPool
      #
      #     def initialize
      #       configure_model_pool do |pool|
      #         pool.register(:execution) { OpenAIModel.lm_studio("gemma") }
      #         pool.register(:planning) { AnthropicModel.new(model_id: "claude-sonnet") }
      #       end
      #     end
      #   end
      #
      # @example Getting models
      #   model = model_for(:execution)
      #   model.generate(messages)
      #
      # @see Types::ModelPoolConfig For pool configuration type
      module ModelPool
        def self.included(base)
          base.extend(ClassMethods)
        end

        # Class methods for ModelPool configuration.
        module ClassMethods
          # Default pool config for subclasses.
          # @return [Types::ModelPoolConfig]
          def default_model_pool_config
            @default_model_pool_config ||= Types::ModelPoolConfig.create
          end

          # Set default pool config.
          # @param config [Types::ModelPoolConfig]
          def default_model_pool_config=(config)
            @default_model_pool_config = config
          end
        end

        # Configure the model pool.
        # @yield [PoolConfigurator] Configurator for registering models
        # @return [self]
        def configure_model_pool
          @model_pool_config ||= self.class.default_model_pool_config
          yield PoolConfigurator.new(self) if block_given?
          self
        end

        # Register a model for a purpose.
        # @param purpose [Symbol] Purpose (:execution, :planning, etc.)
        # @yield Block that returns a Model instance
        # @return [self]
        def register_model(purpose, &)
          @model_pool_config = model_pool_config.with_model(purpose, &)
          @model_instances = {} # Clear cache
          self
        end

        # Get a model for the given purpose.
        # @param purpose [Symbol] Purpose to get model for (default: :default or :execution)
        # @return [Model] Model instance
        def model_for(purpose = nil)
          effective_purpose = purpose || :execution
          @model_instances ||= {}
          @model_instances[effective_purpose] ||= resolve_model_instance(effective_purpose)
        end

        # Check if multi-model mode is active.
        # @return [Boolean]
        def multi_model? = model_pool_config.multi_model?

        # List registered purposes.
        # @return [Array<Symbol>]
        def registered_purposes = model_pool_config.purposes

        # Get the pool configuration.
        # @return [Types::ModelPoolConfig]
        def model_pool_config
          @model_pool_config ||= self.class.default_model_pool_config
        end

        # Set the pool configuration directly.
        # @param config [Types::ModelPoolConfig]
        def model_pool_config=(config)
          @model_pool_config = config
          @model_instances = {}
        end

        private

        def resolve_model_instance(purpose)
          model_pool_config.resolve_model(purpose)
        end

        # Fluent configurator for model pool setup.
        class PoolConfigurator
          def initialize(pool) = @pool = pool

          def register(purpose, &)
            @pool.register_model(purpose, &)
            self
          end
        end
      end
    end
  end
end
