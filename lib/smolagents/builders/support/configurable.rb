module Smolagents
  module Builders
    module Support
      # Standard immutable config update pattern for Data.define builders.
      #
      # Provides the `with_config` method that preserves all Data members while
      # merging new configuration values. Designed for use with Data.define
      # classes that have a :configuration member.
      #
      # @example Usage with Data.define
      #   MyBuilder = Data.define(:configuration) do
      #     include Smolagents::Builders::Support::Configurable
      #
      #     def max_steps(n)
      #       with_config(max_steps: n)
      #     end
      #   end
      #
      #   builder = MyBuilder.new(configuration: { max_steps: 5 })
      #   new_builder = builder.max_steps(10)
      #   new_builder.configuration[:max_steps]  #=> 10
      module Configurable
        private

        # Creates a new builder instance with merged configuration.
        #
        # Returns a new instance of the same class with all Data members
        # preserved, except :configuration which is merged with the provided
        # kwargs. This enables immutable builder chaining.
        #
        # @param kwargs [Hash] Configuration values to merge
        # @return [self.class] New builder with merged configuration
        #
        # @example Simple usage
        #   builder.with_config(max_steps: 10, timeout: 30)
        def with_config(**kwargs)
          self.class.new(configuration: configuration.merge(kwargs))
        end
      end
    end
  end
end
