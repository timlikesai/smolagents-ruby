module Smolagents
  module Executors
    class Executor
      # Concern for registering tools and variables in the executor sandbox.
      #
      # Provides methods for making tools and variables available to executed code.
      # Includes security checks to block dangerous method names from being registered.
      #
      # @example Including in an executor
      #   class MyExecutor < Executor
      #     include ToolRegistration
      #   end
      module ToolRegistration
        def self.included(base)
          base.attr_reader :tools, :variables
        end

        # Registers tools that can be called from executed code.
        #
        # Makes tools available to agent code for execution. Tools are exposed as
        # callable methods within the sandbox. Dangerous method names are blocked.
        #
        # @param tools [Hash{String, Symbol => Tool}] Mapping of tool names to Tool instances
        # @raise [ArgumentError] If any tool name matches DANGEROUS_METHODS
        # @return [void]
        def send_tools(tools)
          tools.each do |name, tool|
            name_str = name.to_s
            validate_tool_name!(name_str)
            @tools[name_str] = tool
          end
        end

        # Registers variables accessible from executed code.
        #
        # Makes variables available to agent code as named values. Variables become
        # accessible as method calls within the sandbox (read-only).
        #
        # @param variables [Hash{String, Symbol => Object}] Mapping of names to values
        # @return [void]
        def send_variables(variables)
          variables.each { |name, value| @variables[name.to_s] = value }
        end

        private

        def initialize_tool_registration
          @tools = {}
          @variables = {}
        end

        def validate_tool_name!(name)
          return unless Security::Allowlists::DANGEROUS_METHODS.include?(name)

          raise ArgumentError, "Cannot register tool with dangerous name: #{name}"
        end
      end
    end
  end
end
