module Smolagents
  module Tools
    # Wraps an agent as a tool for agent-to-agent delegation.
    # Enables hierarchical agent architectures where a coordinator
    # orchestrates specialized sub-agents.
    class ManagedAgentTool < Tool # rubocop:disable Metrics/ClassLength
      include Events::Emitter

      # Default prompt template sent to managed agents with their task assignment.
      DEFAULT_PROMPT_TEMPLATE = <<~PROMPT.freeze
        You are a managed agent called '%<name>s'.
        You have been assigned the following task by your manager:
        %<task>s

        Complete this task thoroughly and return your findings.
      PROMPT

      # DSL configuration for managed agent settings.
      class Config
        attr_accessor :agent_name, :agent_description, :prompt

        def initialize = (@agent_name = @agent_description = @prompt = nil)
        def name(value) = (@agent_name = value)
        def description(value) = (@agent_description = value)
        def prompt_template(value) = (@prompt = value)
        def to_h = { name: @agent_name, description: @agent_description, prompt_template: @prompt }
      end

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
        initialize_agent_identity(config, name, description, prompt_template)
        initialize_io_schema
        super()
      end

      private

      def initialize_agent_identity(config, name, description, prompt_template)
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

      public

      def tool_name = @agent_name
      alias name tool_name
      def description = @agent_description

      # @return [String] Agent's findings or error message
      def execute(task:)
        launch_event = emit_event(Events::SubAgentLaunched.create(agent_name: @agent_name, task:))
        result = run_agent(format(@prompt_template, name: @agent_name, task:), launch_event)
        handle_agent_result(result, launch_event&.id)
      rescue StandardError => e
        handle_error(e, task, launch_event)
      end

      def run_agent(task, event)
        fiber_context? && @agent.respond_to?(:run_fiber) ? execute_fiber(task, event) : execute_sync(task, event)
      end

      def handle_error(err, task, event)
        emit_error(err, context: { agent_name: @agent_name, task: }, recoverable: true)
        emit_completion(event&.id, :error, error: err.message)
        "Agent '#{@agent_name}' error: #{err.message}"
      end

      private

      def execute_sync(task, _event) = @agent.run(task, reset: true)

      def execute_fiber(task, event)
        sub_fiber = @agent.run_fiber(task, reset: true)
        pending = nil
        loop do
          case (result = sub_fiber.resume(pending))
          when Types::ControlRequests::Request then pending = bubble_request(result)
          when Types::ActionStep then emit_progress(event, result)
          when Types::RunResult then return result
          end
        end
      end

      def bubble_request(req)
        wrapped = Types::ControlRequests::SubAgentQuery.create(
          agent_name: @agent_name, query: req.respond_to?(:prompt) ? req.prompt : req.query,
          context: { original: req.to_h, original_id: req.id }, options: req.respond_to?(:options) ? req.options : nil
        )
        parent_response = Fiber.yield(wrapped)
        Types::ControlRequests::Response.respond(request_id: req.id, value: parent_response.value)
      end

      def emit_progress(event, step)
        msg = step.observations&.to_s&.slice(0, 100)
        emit_event(Events::SubAgentProgress.create(launch_id: event&.id, agent_name: @agent_name,
                                                   step_number: step.step_number, message: msg))
      end

      def fiber_context? = Thread.current[:smolagents_fiber_context] == true

      def handle_agent_result(result, launch_id)
        return success_result(result, launch_id) if result.success?

        emit_completion(launch_id, :failure, result:, error: result.state.to_s)
        "Agent '#{@agent_name}' failed: #{result.state}"
      end

      def success_result(result, launch_id)
        emit_completion(launch_id, :success, result:, output: result.output.to_s)
        result.output.to_s
      end

      def emit_completion(launch_id, outcome, result: nil, output: nil, error: nil)
        record_to_observability(result, outcome)
        emit_event(Events::SubAgentCompleted.create(
                     launch_id:, agent_name: @agent_name, outcome:, output:, error:,
                     token_usage: result&.token_usage, step_count: result&.step_count, duration: result&.duration
                   ))
      end

      def record_to_observability(result, outcome)
        obs_ctx = Types::ObservabilityContext.current
        return unless obs_ctx && result

        obs_ctx.record_sub_agent(
          agent_name: @agent_name,
          token_usage: result.token_usage,
          step_count: result.step_count,
          duration: result.duration,
          outcome:
        )
      end

      def derive_name_from_class(agent)
        agent.class.name.split("::").last.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/,
                                                                                     '\1_\2').downcase
      end

      public

      # Format this tool for the given context.
      #
      # Uses :managed_agent format for tool calling prompts to include
      # delegation guidance, falls back to standard formatters otherwise.
      #
      # @param format [Symbol] Format type (:code, :tool_calling, etc.)
      # @return [String] Formatted tool description
      def format_for(format)
        # Use managed_agent formatter for tool_calling to preserve delegation context
        effective_format = format == :tool_calling ? :managed_agent : format
        ToolFormatter.format(self, format: effective_format)
      end

      # @deprecated Use {#format_for}(:tool_calling) instead
      def to_tool_calling_prompt
        format_for(:tool_calling)
      end

      # @deprecated Use {#format_for}(:code) instead
      def to_code_prompt
        format_for(:code)
      end
    end
  end

  ManagedAgentTool = Tools::ManagedAgentTool
end
