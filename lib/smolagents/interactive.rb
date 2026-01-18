require_relative "interactive/colors"
require_relative "interactive/help"
require_relative "interactive/display"
require_relative "interactive/suggestions"
require_relative "interactive/completion"
require_relative "interactive/progress"

module Smolagents
  # Interactive session support for IRB/Pry/console.
  module Interactive
    include ColorHelpers

    class << self
      def session?
        @session = detect_session unless defined?(@session)
        @session
      end

      def colors? = Colors.enabled?
      def activated? = @activated || false
      attr_reader :last_discovery

      def activate!(quiet: false, scan: true, progress: true)
        @activated = true
        Completion.enable
        Progress.enable if progress && $stdout.tty?

        return unless scan

        result = Discovery.scan
        show_welcome(result) unless quiet
        result
      end

      def progress(enabled: true, **)
        enabled ? Progress.enable(**) : Progress.disable
      end

      def progress? = Progress.enabled?

      def show_welcome(discovery = nil)
        discovery ||= Discovery.scan

        puts Display.header
        puts

        discovery.any? ? show_discovered(discovery) : Display.getting_started

        puts
        puts Display.dim("Type #{Display.bold("Smolagents.help")} for more information")
        puts
      end

      def help(topic = nil) = Help.show(topic)

      def models(refresh: false, all: false, filter: nil)
        @last_discovery = nil if refresh
        @last_discovery ||= Discovery.scan

        effective_filter = filter || (all ? :all : :ready)
        Display.models_list(@last_discovery, filter: effective_filter)
        filtered_models(effective_filter)
      end

      def default_handlers
        {
          tool_call: ->(e) { puts tool_call_line(e) },
          tool_complete: ->(e) { puts tool_result_line(e) },
          step_complete: ->(e) { puts step_complete_line(e) }
        }
      end

      def agent
        builder = Smolagents.agent
        default_handlers.each { |event, handler| builder = builder.on(event, &handler) }
        builder
      end

      private

      def detect_session
        irb_session? || pry_session? || rails_console? || tty_irb?
      rescue StandardError
        false
      end

      def irb_session? = defined?(IRB) && IRB.CurrentContext
      def pry_session? = defined?(Pry) && Pry::CLI.started?
      def rails_console? = defined?(Rails::Console)
      def tty_irb? = $stdin.tty? && $PROGRAM_NAME == "irb"

      def show_discovered(discovery)
        Display.models_section(discovery)
        Display.search_section
        Display.cloud_section(discovery)
        Display.try_it_section(discovery)
      end

      def filtered_models(filter)
        case filter
        when :ready, :loaded then @last_discovery.all_models.select(&:ready?)
        when :unloaded then @last_discovery.all_models.reject(&:ready?)
        else @last_discovery.all_models
        end
      end

      def tool_call_line(event)
        args = event.arguments&.map { |k, v| "#{k}: #{v.inspect}" }&.join(", ") || ""
        "#{Display.cyan("→")} #{Display.bold(event.tool_name)}(#{Display.dim(args)})"
      end

      def tool_result_line(event)
        result = event.result.to_s.gsub(/\s+/, " ")
        result = "#{result[0, 100]}..." if result.length > 100
        "#{Display.green("←")} #{Display.dim(result)}"
      end

      def step_complete_line(event)
        "#{Display.dim("─")} Step #{event.step_number} #{Display.green("✓")}"
      end
    end
  end
end
