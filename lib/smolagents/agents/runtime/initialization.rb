module Smolagents
  module Agents
    class AgentRuntime
      # Initialization logic for AgentRuntime.
      #
      # Handles assignment of core and optional components during construction.
      # Uses Ruby metaprogramming to reduce boilerplate in component assignment.
      #
      # @api private
      module Initialization
        # Core component names that must be assigned during initialization.
        CORE_COMPONENTS = %i[model tools executor memory max_steps logger].freeze

        # Optional component names with their default values.
        OPTIONAL_COMPONENTS = {
          custom_instructions: nil,
          spawn_config: nil,
          authorized_imports: [],
          state: {}
        }.freeze

        private

        # Assigns core runtime components from keyword arguments.
        #
        # Uses metaprogramming to assign instance variables from the CORE_COMPONENTS list.
        #
        # @param kwargs [Hash] Component values keyed by component name
        # @return [void]
        def assign_core(**kwargs)
          CORE_COMPONENTS.each { |name| instance_variable_set(:"@#{name}", kwargs.fetch(name)) }
        end

        # Assigns optional runtime components with defaults.
        #
        # Uses metaprogramming to assign instance variables with fallback to defaults.
        #
        # @param kwargs [Hash] Component values (nil values use defaults)
        # @return [void]
        def assign_optional(**kwargs)
          OPTIONAL_COMPONENTS.each do |name, default|
            value = kwargs.key?(name) ? (kwargs[name] || default) : default
            instance_variable_set(:"@#{name}", value)
          end
        end
      end
    end
  end
end
