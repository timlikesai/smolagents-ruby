# frozen_string_literal: true

module Smolagents
  # Wraps an agent as a tool, enabling hierarchical agent orchestration.
  class ManagedAgentTool < Tool
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

    def initialize(agent:, name: nil, description: nil)
      @agent = agent
      @agent_name = name || agent.class.name.split("::").last.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
      @agent_description = description || "A specialized agent with access to: #{agent.tools.keys.join(", ")}"
      setup_tool_metadata
      super()
    end

    def forward(task:)
      result = @agent.run(format(MANAGED_AGENT_PROMPT, name: @agent_name, task: task), reset: true)
      result.success? ? result.output.to_s : "Agent '#{@agent_name}' failed: #{result.state}"
    end

    def to_tool_calling_prompt
      "#{name}: #{description}\n  Use this tool to delegate tasks to the '#{@agent_name}' agent.\n  Takes inputs: #{inputs}\n  Returns: The agent's findings as a string."
    end

    private

    def setup_tool_metadata
      singleton_class.class_eval { attr_accessor :tool_name, :description, :inputs, :output_type, :output_schema }
      self.tool_name = @agent_name
      self.description = @agent_description
      self.inputs = { "task" => { "type" => "string", "description" => "The task to assign to the #{@agent_name} agent" } }
      self.output_type = "string"
      self.output_schema = nil
    end
  end
end
