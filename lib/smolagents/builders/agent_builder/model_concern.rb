module Smolagents
  module Builders
    # Model configuration DSL methods for AgentBuilder.
    #
    # Handles model setting via instance, block, or registered name.
    # Supports multi-model configuration for different purposes.
    module ModelConcern
      # Built-in purposes for multi-model configuration.
      # Custom purposes (e.g., :triage, :vision) are also supported.
      BUILT_IN_PURPOSES = %i[execution planning evaluation summarization code_review].freeze

      # @deprecated Use BUILT_IN_PURPOSES instead. Custom purposes are now allowed.
      MODEL_PURPOSES = BUILT_IN_PURPOSES

      # Set model via instance, block, registered name, or for a specific purpose.
      #
      # Supports four patterns for maximum flexibility:
      # - **Instance** (eager): `.model(my_model)` - pass a model directly
      # - **Block** (lazy): `.model { OpenAIModel.lm_studio("gemma") }` - deferred creation
      # - **Symbol** (lazy): `.model(:local)` - reference a registered model
      # - **Purpose** (multi-model): `.model(:execution) { }` - model for specific purpose
      #
      # Lazy instantiation defers connection setup, API key validation,
      # and resource allocation until `.build` is called.
      #
      # @overload model(instance)
      #   Pass a model instance directly (eager instantiation).
      #   @param instance [Model] A model instance
      #   @return [AgentBuilder]
      #
      # @overload model(&block)
      #   Set model via block (lazy instantiation). The block is called at build time.
      #   @yield Block that returns a Model instance
      #   @return [AgentBuilder]
      #
      # @overload model(registered_name)
      #   Reference a model registered in configuration. Also lazy - the
      #   registered factory is called at build time.
      #   @param registered_name [Symbol] Name of a registered model
      #   @return [AgentBuilder]
      #
      # @overload model(purpose, &block)
      #   Register a model for a specific purpose (multi-model configuration).
      #   @param purpose [Symbol] Purpose (:execution, :planning, :evaluation, etc.)
      #   @yield Block that returns a Model instance
      #   @return [AgentBuilder]
      #
      # @raise [ArgumentError] If neither instance, name, nor block provided
      #
      # @example Using a block (lazy - recommended)
      #   builder = Smolagents.agent.model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
      #
      # @example Multi-model configuration
      #   builder = Smolagents.agent
      #     .model(:execution) { OpenAIModel.lm_studio("gemma") }
      #     .model(:planning) { AnthropicModel.new(model_id: "claude-sonnet") }
      #     .model(:evaluation) { OpenAIModel.new(model_id: "gpt-4o-mini") }
      def model(instance_or_name = nil, &block)
        check_frozen!

        if purpose_with_block?(instance_or_name, block)
          add_model_for_purpose(instance_or_name, block)
        else
          set_default_model(instance_or_name, block)
        end
      end

      private

      # Check if this is a purpose + block call (multi-model).
      # Allows any symbol as a purpose - both built-in (execution, planning, etc.)
      # and custom (triage, vision, etc.).
      def purpose_with_block?(name, block)
        name.is_a?(Symbol) && block
      end

      # Add model for a specific purpose (multi-model mode).
      def add_model_for_purpose(purpose, block)
        current_config = configuration[:model_pool_config] || Types::ModelPoolConfig.create
        new_config = current_config.with_model(purpose, &block)
        with_config(model_pool_config: new_config, model_block: nil)
      end

      # Set the default model (backwards compatible single-model mode).
      def set_default_model(instance_or_name, block)
        with_config(model_block: resolve_model_block(instance_or_name, block))
      end

      # Resolve instance, name, or block into a model block.
      # @param instance_or_name [Model, Symbol, nil] Model instance, name, or nil
      # @param block [Proc, nil] Block that returns a model
      # @return [Proc] Block that returns a model instance
      def resolve_model_block(instance_or_name, block)
        case instance_or_name
        when Symbol then -> { Smolagents.registered_model(instance_or_name) }
        when nil
          raise ArgumentError, "Model required: provide instance, symbol, or block" unless block

          block
        else -> { instance_or_name }
        end
      end

      # Instantiate the model from the configured model block.
      # @return [Model] Model instance
      # @raise [ArgumentError] If model block is not configured
      def resolve_model
        # Check for multi-model pool config first
        if configuration[:model_pool_config]&.multi_model?
          configuration[:model_pool_config].resolve_model(:execution)
        elsif configuration[:model_block]
          configuration[:model_block].call
        else
          raise ArgumentError, "Model required. Use .model { YourModel.new(...) }"
        end
      end

      # Get the model pool config, creating one if needed.
      # @return [Types::ModelPoolConfig]
      def resolve_model_pool_config
        if configuration[:model_pool_config]
          configuration[:model_pool_config]
        elsif configuration[:model_block]
          Types::ModelPoolConfig.single(&configuration[:model_block])
        else
          raise ArgumentError, "Model required. Use .model { YourModel.new(...) }"
        end
      end

      # Check if multi-model mode is configured.
      # @return [Boolean]
      def multi_model? = configuration[:model_pool_config]&.multi_model? || false
    end
  end
end
