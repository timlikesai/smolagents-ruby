require_relative "progress/spinner"
require_relative "progress/step_tracker"
require_relative "progress/token_counter"
require_relative "progress/event_handlers"

module Smolagents
  module Interactive
    # Progress display for agent execution in interactive sessions.
    #
    # Subscribes to instrumentation events and provides visual feedback:
    # - Animated spinner during model generation
    # - Step progress tracking [Step 3/10]
    # - Tool call indicators
    # - Token usage summary
    #
    # @example Enable progress display
    #   Smolagents::Interactive::Progress.enable
    #   agent.run("task")  # Shows progress automatically
    #
    # @example Disable progress display
    #   Smolagents::Interactive::Progress.disable
    #
    # @see Telemetry::LoggingSubscriber For text-based logging
    # @see Telemetry::Instrumentation For the underlying event system
    #
    module Progress
      extend EventHandlers

      EVENT_HANDLERS = {
        "smolagents.agent.run" => :handle_agent_run,
        "smolagents.agent.step" => :handle_agent_step,
        "smolagents.model.generate" => :handle_model_generate,
        "smolagents.tool.call" => :handle_tool_call
      }.freeze

      class << self
        attr_reader :spinner, :step_tracker, :token_counter

        # Enables progress display for agent execution.
        #
        # @param output [IO] Output stream (default: $stdout)
        # @param max_steps [Integer] Maximum steps for progress bar
        # @return [Module] self for method chaining
        def enable(output: $stdout, max_steps: 10)
          @output = output
          @spinner = Spinner.new(output:)
          @step_tracker = StepTracker.new(max_steps:, output:)
          @token_counter = TokenCounter.new(output:)
          @previous_subscriber = Telemetry::Instrumentation.subscriber

          Telemetry::Instrumentation.subscriber = method(:handle_event)
          self
        end

        # Disables progress display.
        # @return [nil]
        def disable
          @spinner&.stop
          Telemetry::Instrumentation.subscriber = @previous_subscriber
          @spinner = nil
          @step_tracker = nil
          @token_counter = nil
          @previous_subscriber = nil
        end

        # Checks if progress display is enabled.
        # @return [Boolean]
        def enabled? = !@spinner.nil?

        private

        def handle_event(event, payload)
          handler = EVENT_HANDLERS[event.to_s]
          send(handler, payload) if handler

          @previous_subscriber&.call(event, payload)
        end

        def show_tool_result(tool_name)
          return unless tty?

          @output.puts "#{cyan("→")} #{bold(tool_name)} #{green("✓")}"
        end

        def show_tool_error(tool_name, error)
          return unless tty?

          msg = error ? " (#{error})" : ""
          @output.puts "#{cyan("→")} #{bold(tool_name)} #{yellow("!")}#{dim(msg)}"
        end

        def tty? = @output.respond_to?(:tty?) && @output.tty?
        def bold(text) = Colors.wrap(text, Colors::BOLD)
        def dim(text) = Colors.wrap(text, Colors::DIM)
        def green(text) = Colors.wrap(text, Colors::BRIGHT_GREEN)
        def yellow(text) = Colors.wrap(text, Colors::YELLOW)
        def cyan(text) = Colors.wrap(text, Colors::CYAN)
      end
    end
  end
end
