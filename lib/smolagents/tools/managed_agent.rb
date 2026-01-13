module Smolagents
  module Tools
    # Wraps an agent as a tool, enabling agent-to-agent delegation.
    #
    # ManagedAgentTool allows a parent agent (manager) to delegate tasks to a
    # specialized sub-agent. The sub-agent runs independently with its own tools
    # and returns results as strings. This enables hierarchical agent architectures
    # where a coordinator agent orchestrates multiple specialized agents.
    #
    # The managed agent receives a formatted prompt containing its name and the
    # assigned task, runs to completion, and returns its findings. Failed runs
    # return an error message rather than raising exceptions.
    #
    # @example Basic usage with a specialized agent
    #   # Create a specialized agent with specific tools
    #   research_agent = CodeAgent.new(
    #     model: model,
    #     tools: [WebSearchTool.new, VisitWebpageTool.new]
    #   )
    #
    #   # Wrap it as a tool for the manager agent
    #   research_tool = ManagedAgentTool.new(
    #     agent: research_agent,
    #     name: "researcher",
    #     description: "Searches the web and summarizes findings"
    #   )
    #
    #   # Manager agent can now delegate research tasks
    #   manager = CodeAgent.new(model: model, tools: [research_tool])
    #   manager.run("Research the latest Ruby 4.0 features")
    #
    # @example Multi-agent team with coordinator
    #   # Create specialized agents
    #   coder = CodeAgent.new(model: model, tools: [RubyInterpreterTool.new])
    #   reviewer = CodeAgent.new(model: model, tools: [ReadFileTool.new])
    #
    #   # Wrap as managed tools
    #   coder_tool = ManagedAgentTool.new(agent: coder, name: "coder")
    #   reviewer_tool = ManagedAgentTool.new(agent: reviewer, name: "reviewer")
    #
    #   # Coordinator orchestrates the team
    #   coordinator = CodeAgent.new(model: model, tools: [coder_tool, reviewer_tool])
    #   coordinator.run("Write a Ruby class and have it reviewed")
    #
    # @example Custom subclass via DSL
    #   class ResearcherTool < ManagedAgentTool
    #     configure do
    #       name "researcher"
    #       description "Searches the web and summarizes findings"
    #       prompt_template <<~PROMPT
    #         You are a research specialist called '%<name>s'.
    #         Your task: %<task>s
    #         Be thorough and cite sources.
    #       PROMPT
    #     end
    #   end
    #
    #   tool = ResearcherTool.new(agent: my_research_agent)
    #
    # @example Auto-generated name from agent class
    #   tool = ManagedAgentTool.new(agent: some_code_agent)
    #   tool.name  # => "code_agent" (derived from class name)
    #
    # @see Tool Base class for all tools
    # @see CodeAgent Agent implementation that can be wrapped
    # @see ToolCallingAgent Alternative agent type for wrapping
    class ManagedAgentTool < Tool
      include Events::Emitter

      # Default prompt template sent to managed agents with their task assignment.
      DEFAULT_PROMPT_TEMPLATE = <<~PROMPT.freeze
        You are a managed agent called '%<name>s'.
        You have been assigned the following task by your manager:
        %<task>s

        Complete this task thoroughly and return your findings.
      PROMPT

      # DSL configuration class for managed agent settings
      class Config
        attr_accessor :agent_name, :agent_description, :prompt

        def initialize
          @agent_name = nil
          @agent_description = nil
          @prompt = nil
        end

        # Sets the agent's tool name for invocation.
        #
        # @param value [String] The name to use when calling this managed agent tool
        # @return [String] The name that was set
        #
        # @example
        #   config.name("researcher")
        def name(value)
          @agent_name = value
        end

        # Sets a human-readable description of the agent's capabilities.
        #
        # @param value [String] Description of what the agent does
        # @return [String] The description that was set
        #
        # @example
        #   config.description("Searches the web and synthesizes findings")
        def description(value)
          @agent_description = value
        end

        # Sets the custom prompt template for task delegation.
        #
        # The template should include %<name>s and %<task>s placeholders,
        # which will be interpolated with the agent name and assigned task.
        #
        # @param value [String] Prompt template with interpolation placeholders
        # @return [String] The template that was set
        #
        # @example
        #   config.prompt_template(<<~PROMPT)
        #     You are a research agent called '%<name>s'.
        #     Your task: %<task>s
        #   PROMPT
        def prompt_template(value)
          @prompt = value
        end

        # Converts configuration to a Hash for use in initialization.
        #
        # @return [Hash{Symbol => Object}] Hash with :name, :description, and :prompt_template keys
        #
        # @example
        #   config = Config.new
        #   config.name("bot")
        #   config.description("A helpful bot")
        #   config.to_h
        #   # => { name: "bot", description: "A helpful bot", prompt_template: nil }
        def to_h
          { name: @agent_name, description: @agent_description, prompt_template: @prompt }
        end
      end

      class << self
        # DSL block for configuring managed agent settings at the class level.
        #
        # @example
        #   class ResearcherTool < ManagedAgentTool
        #     configure do
        #       name "researcher"
        #       description "Searches and summarizes"
        #     end
        #   end
        #
        # @yield Configuration block
        # @return [Config] The configuration
        def configure(&block)
          @config ||= Config.new
          @config.instance_eval(&block) if block
          @config
        end

        # Returns the configuration, inheriting from parent if not set.
        # @return [Config] Always returns a Config
        def config
          @config ||
            (superclass.config if superclass.respond_to?(:config)) ||
            Config.new
        end
      end

      # @return [Object] The wrapped agent instance
      attr_reader :agent

      # @return [String] The agent's tool name (used for invocation)
      attr_reader :agent_name

      # @return [String] Human-readable description of the agent's capabilities
      attr_reader :agent_description

      # @return [Hash] Input specification (always includes "task" parameter)
      attr_reader :inputs

      # @return [String] Output type (always "string")
      attr_reader :output_type

      # @return [nil] Output schema (not used for managed agents)
      attr_reader :output_schema

      # @return [String] The prompt template used for task delegation
      attr_reader :prompt_template

      # Creates a new managed agent tool.
      #
      # @param agent [Object] The agent to wrap (must respond to #run and #tools)
      # @param name [String, nil] Tool name for invocation. If nil, uses DSL config
      #   or derives from agent class name (e.g., CodeAgent -> "code_agent")
      # @param description [String, nil] Description of agent capabilities. If nil,
      #   uses DSL config or auto-generates from agent's available tools
      # @param prompt_template [String, nil] Custom prompt template with %<name>s
      #   and %<task>s placeholders. If nil, uses DSL config or default template.
      #
      # @example With explicit name and description
      #   ManagedAgentTool.new(
      #     agent: my_agent,
      #     name: "data_analyst",
      #     description: "Analyzes datasets and produces statistical summaries"
      #   )
      #
      # @example With auto-generated attributes
      #   ManagedAgentTool.new(agent: my_agent)
      #   # name derived from class, description lists available tools
      def initialize(agent:, name: nil, description: nil, prompt_template: nil)
        @agent = agent
        config = self.class.config.to_h

        @agent_name = name ||
                      config[:name] ||
                      derive_name_from_class(agent)

        @agent_description = description ||
                             config[:description] ||
                             "A specialized agent with access to: #{agent.tools.keys.join(", ")}"

        @prompt_template = prompt_template ||
                           config[:prompt_template] ||
                           DEFAULT_PROMPT_TEMPLATE

        @inputs = { "task" => { type: "string", description: "The task to assign to the #{@agent_name} agent" } }
        @output_type = "string"
        @output_schema = nil
        super()
      end

      # Returns the tool name for this managed agent.
      # @return [String] The agent's tool name
      def tool_name = @agent_name
      alias name tool_name

      # Returns the tool description.
      # @return [String] The agent's description
      def description = @agent_description

      # Executes the managed agent with the given task.
      #
      # The agent runs with a fresh memory (reset: true) and returns either
      # its output on success or an error message on failure.
      #
      # Emits SubAgentLaunched when starting and SubAgentCompleted when done,
      # enabling event-driven orchestration and parallel sub-agent execution.
      #
      # @param task [String] The task description to delegate to the agent
      # @return [String] The agent's findings or an error message
      #
      # @example
      #   result = managed_tool.execute(task: "Find all TODO comments in the codebase")
      #   # => "Found 15 TODO comments across 8 files..."
      def execute(task:)
        launch_event = emit_event(Events::SubAgentLaunched.create(
                                    agent_name: @agent_name,
                                    task: task
                                  ))

        result = @agent.run(format(@prompt_template, name: @agent_name, task: task), reset: true)

        if result.success?
          emit_event(Events::SubAgentCompleted.create(
                       launch_id: launch_event&.id,
                       agent_name: @agent_name,
                       outcome: :success,
                       output: result.output.to_s
                     ))
          result.output.to_s
        else
          emit_event(Events::SubAgentCompleted.create(
                       launch_id: launch_event&.id,
                       agent_name: @agent_name,
                       outcome: :failure,
                       error: result.state.to_s
                     ))
          "Agent '#{@agent_name}' failed: #{result.state}"
        end
      rescue StandardError => e
        emit_error(e, context: { agent_name: @agent_name, task: task }, recoverable: true)
        emit_event(Events::SubAgentCompleted.create(
                     launch_id: launch_event&.id,
                     agent_name: @agent_name,
                     outcome: :error,
                     error: e.message
                   ))
        "Agent '#{@agent_name}' error: #{e.message}"
      end

      # Generates a prompt describing this tool for tool-calling agents.
      #
      # @return [String] Formatted prompt with name, description, inputs, and return type
      def to_tool_calling_prompt
        "#{name}: #{description}\n  Use this tool to delegate tasks to the '#{@agent_name}' agent.\n  Takes inputs: #{inputs}\n  Returns: The agent's findings as a string."
      end

      private

      def derive_name_from_class(agent)
        agent.class.name
             .split("::")
             .last
             .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
             .gsub(/([a-z\d])([A-Z])/, '\1_\2')
             .downcase
      end
    end
  end

  # Re-export ManagedAgentTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::ManagedAgentTool
  ManagedAgentTool = Tools::ManagedAgentTool
end
