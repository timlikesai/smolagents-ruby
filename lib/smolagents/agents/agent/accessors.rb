module Smolagents
  module Agents
    class Agent
      # Accessor declarations for Agent core attributes.
      #
      # Provides read access to runtime, executor, tools, model, memory,
      # configuration values, and logger. Uses metaprogramming to reduce
      # repetition in accessor definitions.
      #
      # @api private
      module Accessors
        def self.included(base)
          base.extend(ClassMethods)
          base.define_accessors
        end

        # Class methods for accessor definition.
        module ClassMethods
          # Attribute definitions with types for documentation.
          # Each key maps to [attribute_name, description].
          ATTRIBUTES = {
            runtime: "The execution runtime that manages the ReAct loop",
            executor: "The code executor for sandboxed Ruby execution",
            authorized_imports: "List of Ruby libraries allowed for require statements",
            tools: "Tools available to the agent, keyed by tool name",
            model: "The LLM model used for code generation",
            memory: "Conversation history and step tracking",
            max_steps: "Maximum number of steps before the agent stops",
            logger: "Logger for agent operations"
          }.freeze

          # Define all accessors using metaprogramming.
          def define_accessors
            ATTRIBUTES.each_key { |attr| attr_reader(attr) }
          end
        end

        # Readable REPL output for agents.
        #
        # @return [String] Compact representation showing model, tools, steps
        def inspect
          "#<Agent model=#{inspect_model} tools=#{inspect_tools} steps=#{@memory&.steps&.size || 0}>"
        end

        private

        def inspect_model = @model&.model_id || "none"

        def inspect_tools
          return "[0]" unless @tools&.any?

          names = @tools.keys.first(3).join(", ")
          names += ", ..." if @tools.size > 3
          "[#{names}] (#{@tools.size})"
        end
      end
    end
  end
end
