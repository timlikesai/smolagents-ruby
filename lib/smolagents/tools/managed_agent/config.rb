module Smolagents
  module Tools
    class ManagedAgentTool < Tool
      # DSL configuration for managed agent settings.
      #
      # Provides a fluent interface for configuring managed agent properties
      # through a class-level DSL block.
      #
      # @example Configure a managed agent subclass
      #   class MyAgent < ManagedAgentTool
      #     configure do
      #       name "researcher"
      #       description "Researches topics using web search"
      #       prompt_template "Research this: %{task}"
      #     end
      #   end
      class Config
        attr_accessor :agent_name, :agent_description, :prompt

        def initialize
          @agent_name = nil
          @agent_description = nil
          @prompt = nil
        end

        # Set the agent name.
        # @param value [String] The name for the managed agent
        # @return [String] The configured name
        def name(value) = (@agent_name = value)

        # Set the agent description.
        # @param value [String] Description of what this agent does
        # @return [String] The configured description
        def description(value) = (@agent_description = value)

        # Set the prompt template.
        # @param value [String] Template with %{name} and %{task} placeholders
        # @return [String] The configured template
        def prompt_template(value) = (@prompt = value)

        # Convert config to hash for initialization.
        # @return [Hash] Configuration values
        def to_h = { name: @agent_name, description: @agent_description, prompt_template: @prompt }
      end
    end
  end
end
