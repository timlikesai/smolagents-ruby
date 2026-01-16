module Smolagents
  module Tools
    # Tool that enables agents to spawn specialized sub-agents at runtime.
    #
    # This tool provides constrained agent spawning - the LLM specifies structured
    # parameters (task, persona, tools) and we build the agent using our DSL.
    # This is safer and more predictable than having the LLM write arbitrary code.
    #
    # All spawned agents inherit ruby_interpreter and final_answer implicitly.
    # Only additional tools need to be specified.
    #
    # @example Enabling spawn capability
    #   agent = Smolagents.agent
    #     .model(:router)
    #     .can_spawn(allow: [:researcher, :analyst], tools: [:search, :web])
    #     .build
    #
    # @example How the LLM calls spawn_agent
    #   # spawn_agent(task: "Research Ruby 4 features", persona: "researcher", tools: ["search"])
    #   # spawn_agent(task: "Analyze this data", persona: "analyst")  # No extra tools
    #
    # @see Types::SpawnConfig Configuration for spawn capability
    # @see AgentBuilder#can_spawn DSL for enabling spawning
    class SpawnAgentTool < Tool
      self.tool_name = "spawn_agent"
      self.description = "Create a specialized sub-agent to handle a subtask. " \
                         "All agents can write Ruby code and return final answers - " \
                         "only specify additional tools needed."
      self.inputs = {
        task: { type: "string", description: "What the sub-agent should do" },
        persona: { type: "string",
                   description: "Persona for the agent (researcher, analyst, fact_checker, calculator, scraper)" },
        tools: { type: "array", nullable: true,
                 description: "Toolkits or individual tools (optional)" }
      }
      self.output_type = "any"

      # Creates a spawn tool configured for a specific parent agent.
      #
      # @param parent_model [Model] The model to use for spawned agents
      # @param spawn_config [Types::SpawnConfig] Configuration with allowed personas/tools
      # @param inline_tools [Array<InlineTool>] Inline tools to pass to children (optional)
      def initialize(parent_model:, spawn_config:, inline_tools: [])
        super()
        @parent_model = parent_model
        @spawn_config = spawn_config
        @inline_tools = inline_tools
        @children_spawned = 0
      end

      def execute(task:, persona:, tools: nil)
        validate_spawn_allowed!
        validate_persona!(persona)

        tools_array = Array(tools).map(&:to_sym)
        validate_tools!(tools_array)

        sub_agent = build_sub_agent(persona.to_sym, tools_array)
        result = sub_agent.run(task)

        @children_spawned += 1
        format_result(result, persona)
      end

      private

      def validate_spawn_allowed!
        return if @spawn_config.enabled?

        raise SpawnError.new("Spawning is disabled", reason: "spawn_disabled")
      end

      def validate_persona!(persona)
        return if Personas.names.include?(persona.to_sym)

        raise SpawnError.new(
          "Unknown persona: #{persona}. Available: #{Personas.names.join(", ")}",
          reason: "invalid_persona"
        )
      end

      def validate_tools!(tools)
        return if tools.empty?

        tools.each do |tool|
          # Skip toolkit names - they'll be expanded
          next if Toolkits.toolkit?(tool)

          next if @spawn_config.tool_allowed?(tool)

          raise SpawnError.new(
            "Tool not allowed: #{tool}. Allowed: #{@spawn_config.allowed_tools.join(", ")}",
            reason: "tool_not_allowed"
          )
        end
      end

      def validate_children_limit!
        return if @children_spawned < @spawn_config.max_children

        raise SpawnError.new(
          "Maximum children (#{@spawn_config.max_children}) already spawned",
          reason: "max_children_exceeded"
        )
      end

      def build_sub_agent(persona, tools)
        builder = Smolagents.agent
                            .model { @parent_model }
                            .as(persona)

        # Add allowed tools (toolkits get expanded automatically)
        builder = builder.tools(*tools) unless tools.empty?

        # Add any inline tools from parent
        @inline_tools.each do |inline_tool|
          builder = builder.tools(inline_tool)
        end

        # Reduce max_steps for children to prevent runaway agents
        builder = builder.max_steps(5)

        builder.build
      end

      def format_result(result, persona)
        output = result.respond_to?(:output) ? result.output : result
        "Sub-agent (#{persona}) result: #{output}"
      end
    end
  end

  # Re-export at Smolagents level
  SpawnAgentTool = Tools::SpawnAgentTool
end
