module Smolagents
  module Concerns
    # Human-readable event logging for agent debugging.
    #
    # Subscribes to all user-tier events and formats them as concise,
    # readable log messages via the agent's logger. Useful for development
    # and debugging agent behavior.
    #
    # @example Including in an agent
    #   class MyAgent
    #     include Events::Consumer
    #     include Concerns::VerboseSubscriber
    #
    #     def initialize(logger:)
    #       @logger = logger
    #       initialize_verbose
    #     end
    #   end
    #
    # @example Output format
    #   [Step 1] success
    #   [Tool] Calling search(query: "Ruby 4.0")
    #   [Tool] search returned: "Ruby 4.0 was released..." (truncated)
    #   [Model] gemma-3n generated 145 tokens (250ms)
    #   [Task] Started: "Find Ruby info" (max 10 steps)
    #   [Error] RuntimeError: Connection refused (recoverable)
    #
    # @see Events::Consumer For subscription API
    module VerboseSubscriber
      MAX_RESULT_LENGTH = 200

      # @api private
      FORMATTERS = {
        Events::StepCompleted => :format_step,
        Events::ToolCallRequested => :format_tool_request,
        Events::ToolCallCompleted => :format_tool_completed,
        Events::ToolCallParsed => :format_tool_parsed,
        Events::ModelGeneration => :format_model,
        Events::TaskLifecycle => :format_task,
        Events::ErrorOccurred => :format_error,
        Events::SubAgentLaunched => :format_sub_launch,
        Events::SubAgentCompleted => :format_sub_completed,
        Events::ControlYielded => :format_control_yield,
        Events::ControlResumed => :format_control_resume
      }.freeze

      def self.included(base)
        base.include(Events::Consumer)
      end

      private

      def initialize_verbose
        on_user_events { |event| log_verbose_event(event) }
      end

      def log_verbose_event(event)
        formatter = FORMATTERS[event.class]
        @logger&.debug(send(formatter, event)) if formatter
      end

      def format_step(evt) = "[Step #{evt.step_number}] #{evt.outcome}"

      def format_tool_request(evt) = "[Tool] Calling #{evt.tool_name}(#{format_args(evt.args)})"

      def format_tool_completed(evt) = "[Tool] #{evt.tool_name} returned: #{truncate(evt.result)}"

      def format_tool_parsed(evt) = "[Parsed] #{evt.model_id} -> #{evt.tool_name}(#{format_args(evt.arguments)})"

      def format_model(evt)
        return "[Model] #{evt.model_id} generation requested" if evt.requested?

        "[Model] #{evt.model_id} generated #{format_tokens(evt.token_usage)} (#{evt.duration_ms}ms)"
      end

      def format_task(evt)
        return "[Task] Started: #{truncate(evt.task)} (max #{evt.max_steps} steps)" if evt.started?

        "[Task] Completed: #{evt.outcome} (#{evt.steps_taken} steps)"
      end

      def format_error(evt)
        suffix = evt.recoverable? ? "recoverable" : "fatal"
        "[Error] #{evt.error_class}: #{evt.error_message} (#{suffix})"
      end

      def format_sub_launch(evt) = "[SubAgent] Launched #{evt.agent_name}: #{truncate(evt.task)}"

      def format_sub_completed(evt) = "[SubAgent] #{evt.agent_name} #{evt.outcome}"

      def format_control_yield(evt) = "[Control] Yielded #{evt.request_type}: #{truncate(evt.prompt)}"

      def format_control_resume(evt) = "[Control] Resumed #{evt.request_id} (approved: #{evt.approved})"

      def truncate(value, max: MAX_RESULT_LENGTH)
        text = value.to_s
        text.length > max ? "#{text[0, max]}..." : text
      end

      def format_args(args)
        return "" unless args

        args.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
      end

      def format_tokens(usage)
        return "?" unless usage.is_a?(Hash)

        "#{usage[:output_tokens] || usage["output_tokens"] || "?"} tokens"
      end
    end
  end
end
