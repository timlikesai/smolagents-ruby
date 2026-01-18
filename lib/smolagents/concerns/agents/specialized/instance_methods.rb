module Smolagents
  module Concerns
    module Specialized
      # Instance methods for specialized agents.
      #
      # Overrides initialize to automatically resolve tools and inject
      # specialized instructions from class-level declarations.
      module InstanceMethods
        # Initialize a specialized agent with resolved tools and instructions.
        #
        # @param model [Model] Language model for this agent
        # @param options [Hash] Additional options passed to parent initialize
        def initialize(model:, **options)
          tools = resolve_default_tools(options)
          config = Types::AgentConfig.create(custom_instructions: self.class.specialized_instructions)
          super(
            model:,
            tools:,
            config:,
            **options.except(*specialized_option_keys)
          )
        end

        private

        def resolve_default_tools(options)
          if self.class.default_tools_block
            self.class.default_tools_block.call(options)
          elsif self.class.default_tool_names
            self.class.default_tool_names.map { |name| instantiate_tool(name) }
          else
            []
          end
        end

        def instantiate_tool(name)
          tool = Smolagents::Tools.get(name.to_s)
          raise ArgumentError, "Unknown tool: #{name}" unless tool

          # If it's a class, instantiate it; if it's already an instance, use it
          tool.is_a?(Class) ? tool.new : tool
        end

        # Keys consumed by specialized agent logic, not passed to parent.
        # Override in subclass to filter custom options.
        #
        # @return [Array<Symbol>] Option keys to filter out
        def specialized_option_keys = []
      end
    end
  end
end
