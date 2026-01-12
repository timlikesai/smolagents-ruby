module Smolagents
  module Concerns
    # DSL concern for defining specialized agents with minimal boilerplate.
    #
    # Provides class-level macros for declaring agent instructions and
    # default tool sets, eliminating repetitive initialize/default_tools
    # method definitions.
    #
    # @example Defining a specialized agent
    #   class MySearchAgent < Agents::ToolCalling
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
    #   # Usage:
    #   agent = MySearchAgent.new(model: my_model)
    #
    # @example With configurable tool options
    #   class FactChecker < Agents::ToolCalling
    #     include Concerns::Specialized
    #
    #     instructions "You are a fact-checking specialist..."
    #
    #     # Block form for dynamic tool instantiation
    #     default_tools do |options|
    #       search = case options[:search_provider]
    #                when :google then GoogleSearchTool.new
    #                else DuckDuckGoSearchTool.new
    #                end
    #       [search, WikipediaSearchTool.new, FinalAnswerTool.new]
    #     end
    #   end
    #
    #   agent = FactChecker.new(model: my_model, search_provider: :google)
    #
    # @example Combining with AgentBuilder
    #   # Specialized agents work seamlessly with the builder DSL:
    #   team = Smolagents.team
    #     .agent(MySearchAgent.new(model: m), as: "searcher")
    #     .agent(MyWriter.new(model: m), as: "writer")
    #     .build
    #
    # @see AgentBuilder For programmatic agent construction
    # @see TeamBuilder For multi-agent composition
    module Specialized
      # Hook called when module is included to set up DSL and initialize override.
      def self.included(base)
        base.extend(ClassMethods)
        base.include(InstanceMethods)
      end

      # Class-level DSL methods for specialized agent configuration
      module ClassMethods
        # Sets the custom instructions for this specialized agent.
        #
        # @param text [String] Instructions text (heredoc recommended)
        # @return [String] The frozen instructions
        def instructions(text)
          @specialized_instructions = text.freeze
        end

        # Returns the configured instructions.
        # @return [String, nil] Instructions or nil if not set
        def specialized_instructions
          @specialized_instructions
        end

        # Declares default tools for this specialized agent.
        #
        # @overload default_tools(*tool_names)
        #   @param tool_names [Array<Symbol>] Tool names from registry
        #   @example default_tools :duckduckgo_search, :final_answer
        #
        # @overload default_tools(&block)
        #   @yield [options] Block receiving initialization options
        #   @yieldreturn [Array<Tool>] Array of tool instances
        #   @example
        #     default_tools do |options|
        #       [DuckDuckGoSearchTool.new, FinalAnswerTool.new]
        #     end
        def default_tools(*tool_names, &block)
          if block_given?
            @default_tools_block = block
          else
            @default_tool_names = tool_names.flatten
          end
        end

        # @api private
        def default_tool_names
          @default_tool_names
        end

        # @api private
        def default_tools_block
          @default_tools_block
        end
      end

      # Instance methods added to specialized agents
      module InstanceMethods
        def initialize(model:, **options)
          tools = resolve_default_tools(options)
          super(
            model: model,
            tools: tools,
            custom_instructions: self.class.specialized_instructions,
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

        def specialized_option_keys
          # Keys consumed by specialized agent logic, not passed to parent
          []
        end
      end
    end
  end
end
