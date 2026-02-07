require_relative "../base_concern"

module Smolagents
  module Concerns
    # DSL concern for defining specialized agents with minimal boilerplate.
    #
    # Focused, narrow roles help every model perform at its best.
    # Specialized agents encode domain knowledge and tool preferences
    # directly in the class definition.
    #
    # @example Defining a specialized agent
    #   class MySearchAgent < Agents::Agent
    #     include Concerns::Specialized
    #
    #     instructions <<~TEXT
    #       You are a search specialist. Your approach:
    #       1. Search for relevant information
    #       2. Summarize findings
    #     TEXT
    #
    #     default_tools :duckduckgo_search, :visit_webpage, :final_answer
    #   end
    #
    #   agent = MySearchAgent.new(model: my_model)
    #
    # @example With configurable tool options
    #   class FactChecker < Agents::Agent
    #     include Concerns::Specialized
    #
    #     instructions "You are a fact-checking specialist..."
    #
    #     default_tools do |options|
    #       search = case options[:search_provider]
    #                when :google then GoogleSearchTool.new
    #                else DuckDuckGoSearchTool.new
    #                end
    #       [search, FinalAnswerTool.new]
    #     end
    #   end
    #
    #   agent = FactChecker.new(model: my_model, search_provider: :google)
    #
    # @see Specialized::ClassMethods For class-level DSL methods
    # @see Specialized::InstanceMethods For instance behavior
    module Specialized
      # Class-level DSL methods for specialized agent configuration.
      #
      # Provides macros for declaring agent instructions and default tools.
      #
      # @example
      #   class MyAgent < Agents::Agent
      #     include Concerns::Specialized
      #
      #     instructions "You are a search specialist..."
      #     default_tools :search, :final_answer
      #   end
      module ClassMethods
        # Sets the custom instructions for this specialized agent.
        #
        # @param text [String] Instructions text (heredoc recommended)
        # @return [String] The frozen instructions
        def instructions(text)
          @specialized_instructions = text.freeze
        end

        # Returns the configured instructions.
        #
        # @return [String, nil] Instructions or nil if not set
        def specialized_instructions = @specialized_instructions

        # Declares default tools for this specialized agent.
        #
        # @overload default_tools(*tool_names)
        #   @param tool_names [Array<Symbol>] Tool names from registry
        #
        # @overload default_tools(&block)
        #   @yield [options] Block receiving initialization options
        #   @yieldreturn [Array<Tool>] Array of tool instances
        def default_tools(*tool_names, &block)
          if block_given?
            @default_tools_block = block
          else
            @default_tool_names = tool_names.flatten
          end
        end

        # @api private
        def default_tool_names = @default_tool_names

        # @api private
        def default_tools_block = @default_tools_block
      end

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
          behavioral = Types::BehavioralConfig.create(custom_instructions: self.class.specialized_instructions)
          config = Types::AgentConfig.create(behavioral:)
          super(
            model:,
            tools:,
            config:,
            **options.except(*specialized_option_keys)
          )
        end

        private

        # Resolve tools from class-level declarations or provided options.
        # @param options [Hash] Initialization options
        # @return [Array<Tool>] Tool instances
        def resolve_default_tools(options)
          if self.class.default_tools_block
            self.class.default_tools_block.call(options)
          elsif self.class.default_tool_names
            self.class.default_tool_names.map { |name| instantiate_tool(name) }
          else
            []
          end
        end

        # Instantiate a tool by name from the tool registry.
        # @param name [Symbol, String] Tool name
        # @return [Tool] Instantiated tool
        # @raise [ArgumentError] If tool not found in registry
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

      BaseConcern.define_composite(self, InstanceMethods, class_methods: ClassMethods)
    end
  end
end
