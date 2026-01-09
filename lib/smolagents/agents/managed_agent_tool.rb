# frozen_string_literal: true

module Smolagents
  # Wraps an agent as a tool, enabling hierarchical agent orchestration.
  # Parent agents can use managed agents as tools to delegate sub-tasks.
  #
  # @example Creating a managed agent
  #   search_agent = CodeAgent.new(tools: [WebSearchTool.new], model: model)
  #   managed_tool = ManagedAgentTool.new(
  #     agent: search_agent,
  #     name: "search_specialist",
  #     description: "Searches the web and synthesizes findings"
  #   )
  #
  # @example Using managed agents in parent agent
  #   manager = CodeAgent.new(
  #     tools: [final_answer_tool],
  #     model: model,
  #     managed_agents: [search_agent, analysis_agent]
  #   )
  class ManagedAgentTool < Tool
    # Default template for managed agent prompts
    MANAGED_AGENT_PROMPT = <<~PROMPT
      You are a managed agent called '%<name>s'.
      You have been assigned the following task by your manager:
      %<task>s

      Complete this task thoroughly and return your findings.
    PROMPT

    class << self
      attr_accessor :tool_name, :description, :inputs, :output_type, :output_schema
    end

    attr_reader :agent, :agent_name, :agent_description

    # Initialize a managed agent tool.
    #
    # @param agent [MultiStepAgent] the agent to wrap
    # @param name [String, nil] custom name for the agent (defaults to agent class name)
    # @param description [String, nil] custom description (defaults to generic)
    def initialize(agent:, name: nil, description: nil)
      @agent = agent
      @agent_name = name || generate_default_name(agent)
      @agent_description = description || generate_default_description(agent)

      # Set class-level attributes dynamically
      setup_tool_metadata

      super()
    end

    # Execute the managed agent with the given task.
    #
    # @param task [String] the task to assign to the managed agent
    # @return [String] the agent's final answer
    def forward(task:)
      # Format the task with managed agent prompt
      formatted_task = format(MANAGED_AGENT_PROMPT, name: @agent_name, task: task)

      # Run the agent
      result = @agent.run(formatted_task, reset: true)

      if result.success?
        result.output.to_s
      else
        "Agent '#{@agent_name}' failed: #{result.state}"
      end
    end

    # Get description for prompt generation.
    #
    # @return [String] formatted description
    def to_tool_calling_prompt
      <<~TEXT
        #{name}: #{description}
          Use this tool to delegate tasks to the '#{@agent_name}' agent.
          Takes inputs: #{inputs}
          Returns: The agent's findings as a string.
      TEXT
    end

    private

    # Setup tool metadata based on agent configuration.
    def setup_tool_metadata
      # Create a singleton class to hold this instance's metadata
      singleton_class.class_eval do
        attr_accessor :tool_name, :description, :inputs, :output_type, :output_schema
      end

      self.tool_name = @agent_name
      self.description = @agent_description
      self.inputs = {
        "task" => {
          "type" => "string",
          "description" => "The task to assign to the #{@agent_name} agent"
        }
      }
      self.output_type = "string"
      self.output_schema = nil
    end

    # Generate default name from agent class.
    #
    # @param agent [MultiStepAgent] the agent
    # @return [String] generated name
    def generate_default_name(agent)
      # Convert class name to snake_case agent name
      agent.class.name
           .split("::")
           .last
           .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
           .gsub(/([a-z\d])([A-Z])/, '\1_\2')
           .downcase
    end

    # Generate default description from agent configuration.
    #
    # @param agent [MultiStepAgent] the agent
    # @return [String] generated description
    def generate_default_description(agent)
      tool_names = agent.tools.keys.join(", ")
      "A specialized agent with access to: #{tool_names}"
    end
  end
end
