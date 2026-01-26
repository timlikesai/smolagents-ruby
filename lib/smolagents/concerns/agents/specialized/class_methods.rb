module Smolagents
  module Concerns
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
    end
  end
end
