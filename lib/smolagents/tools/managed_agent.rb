module Smolagents
  class ManagedAgentTool < Tool
    MANAGED_AGENT_PROMPT = <<~PROMPT
      You are a managed agent called '%<name>s'.
      You have been assigned the following task by your manager:
      %<task>s

      Complete this task thoroughly and return your findings.
    PROMPT

    attr_reader :agent, :agent_name, :agent_description, :inputs, :output_type, :output_schema

    def initialize(agent:, name: nil, description: nil)
      @agent = agent
      @agent_name = name || agent.class.name.split("::").last.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
      @agent_description = description || "A specialized agent with access to: #{agent.tools.keys.join(", ")}"
      @inputs = { "task" => { type: "string", description: "The task to assign to the #{@agent_name} agent" } }
      @output_type = "string"
      @output_schema = nil
      super()
    end

    def tool_name = @agent_name
    alias name tool_name
    def description = @agent_description

    def forward(task:)
      result = @agent.run(format(MANAGED_AGENT_PROMPT, name: @agent_name, task: task), reset: true)
      result.success? ? result.output.to_s : "Agent '#{@agent_name}' failed: #{result.state}"
    end

    def to_tool_calling_prompt
      "#{name}: #{description}\n  Use this tool to delegate tasks to the '#{@agent_name}' agent.\n  Takes inputs: #{inputs}\n  Returns: The agent's findings as a string."
    end
  end
end
