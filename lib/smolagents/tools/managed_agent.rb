require_relative "managed_agent/config"
require_relative "managed_agent/fiber_execution"
require_relative "managed_agent/result_handling"

module Smolagents
  module Tools
    # Wraps an agent as a tool for agent-to-agent delegation.
    # Enables hierarchical agent architectures where a coordinator
    # orchestrates specialized sub-agents.
    class ManagedAgentTool < Tool
      include Events::Emitter
      include FiberExecution
      include ResultHandling

      DEFAULT_PROMPT_TEMPLATE = <<~PROMPT.freeze
        You are a managed agent called '%<name>s'.
        You have been assigned the following task by your manager:
        %<task>s

        Complete this task thoroughly and return your findings.
      PROMPT

      class << self
        def configure(&block)
          @config ||= Config.new
          @config.instance_eval(&block) if block
          @config
        end

        def config = @config || (superclass.config if superclass.respond_to?(:config)) || Config.new
      end

      attr_reader :agent, :agent_name, :agent_description, :inputs, :output_type, :output_schema, :prompt_template

      def initialize(agent:, name: nil, description: nil, prompt_template: nil)
        @agent = agent
        config = self.class.config.to_h
        initialize_identity(config, name, description, prompt_template)
        initialize_io_schema
        super()
      end

      def tool_name = @agent_name
      alias name tool_name
      def description = @agent_description

      # @return [String] Agent's findings or error message
      def execute(task:)
        launch_event = emit_event(Events::SubAgentLaunched.create(agent_name: @agent_name, task:))
        result = run_agent(format(@prompt_template, name: @agent_name, task:), launch_event)
        handle_result(result, launch_event&.id)
      rescue StandardError => e
        handle_error(e, task, launch_event)
      end

      def run_agent(task, event)
        fiber_context? && @agent.respond_to?(:run_fiber) ? execute_fiber(task, event) : execute_sync(task, event)
      end

      def format_for(format)
        effective_format = format == :tool_calling ? :managed_agent : format
        ToolFormatter.format(self, format: effective_format)
      end

      private

      def initialize_identity(config, name, description, prompt_template)
        @agent_name = name || config[:name] || derive_name_from_class(@agent)
        @agent_description = description || config[:description] || default_description
        @prompt_template = prompt_template || config[:prompt_template] || DEFAULT_PROMPT_TEMPLATE
      end

      def default_description = "A specialized agent with access to: #{@agent.tools.keys.join(", ")}"

      def initialize_io_schema
        @inputs = { "task" => { type: "string", description: "The task to assign to the #{@agent_name} agent" } }
        @output_type = "string"
        @output_schema = nil
      end

      def derive_name_from_class(agent)
        agent.class.name.split("::").last
             .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
             .gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
      end
    end
  end

  ManagedAgentTool = Tools::ManagedAgentTool
end
