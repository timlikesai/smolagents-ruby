module Smolagents
  module Builders
    # Model configuration DSL methods for AgentBuilder.
    #
    # Handles model setting via instance, block, or registered name.
    module ModelConcern
      # Set model via instance, block, or registered name.
      #
      # Supports three patterns for maximum flexibility:
      # - **Instance** (eager): `.model(my_model)` - pass a model directly
      # - **Block** (lazy): `.model { OpenAIModel.lm_studio("gemma") }` - deferred creation
      # - **Symbol** (lazy): `.model(:local)` - reference a registered model
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
      # @raise [ArgumentError] If neither instance, name, nor block provided
      #
      # @example Using a block (lazy instantiation)
      #   builder = Smolagents.agent.model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
      #   builder.config[:model_block].nil?
      #   #=> false
      #
      # @example Using a direct instance
      #   model = Smolagents::OpenAIModel.new(model_id: "gpt-4")
      #   builder = Smolagents.agent.model(model)
      #   builder.config[:model_block].nil?
      #   #=> false
      def model(instance_or_name = nil, &block)
        check_frozen!
        with_config(model_block: resolve_model_block(instance_or_name, block))
      end

      private

      def resolve_model_block(instance_or_name, block)
        case instance_or_name
        when Symbol then -> { Smolagents.get_model(instance_or_name) }
        when nil
          raise ArgumentError, "Model required: provide instance, symbol, or block" unless block

          block
        else -> { instance_or_name }
        end
      end

      def resolve_model
        raise ArgumentError, "Model required. Use .model { YourModel.new(...) }" unless configuration[:model_block]

        configuration[:model_block].call
      end
    end
  end
end
