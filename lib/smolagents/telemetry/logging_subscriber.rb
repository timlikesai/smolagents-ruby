module Smolagents
  module Telemetry
    # Simple logging subscriber for instrumentation events.
    #
    # LoggingSubscriber provides human-readable logging of all agent operations
    # without requiring external dependencies. It logs:
    #
    # - Agent execution start, progress, and completion
    # - Model generation requests and responses
    # - Tool calls and results
    # - Step completion and errors
    # - Executor operations
    # - Error events with context
    #
    # LoggingSubscriber is useful for:
    # - Development and debugging
    # - Understanding agent behavior
    # - Monitoring in production (with appropriate log level)
    # - Testing and validation
    #
    # Uses Ruby's standard Logger class, so output can be directed to:
    # - $stdout (default)
    # - Files
    # - Syslog
    # - Any IO stream
    #
    # @example Enable logging to stdout with default config
    #   Smolagents::Telemetry::LoggingSubscriber.enable
    #   agent = Smolagents.agent.with(:code).model { ... }.build
    #   agent.run("task")  # Logs automatically
    #
    # @example Enable with custom logger and file output
    #   logger = Logger.new("agent.log")
    #   Smolagents::Telemetry::LoggingSubscriber.enable(logger: logger, level: :debug)
    #
    # @example Enable with minimal output (warnings and errors only)
    #   Smolagents::Telemetry::LoggingSubscriber.enable(level: :warn)
    #
    # @example Disable logging
    #   Smolagents::Telemetry::LoggingSubscriber.disable
    #
    # @see https://ruby-doc.org/stdlib/libdoc/logger/rdoc/Logger.html Ruby Logger
    # @see Instrumentation For low-level instrumentation data
    # @see OTel For distributed tracing with OpenTelemetry
    #
    module LoggingSubscriber
      class << self
        # @return [Logger, nil] The logger instance or nil if disabled
        attr_reader :logger

        # @return [Symbol, nil] The log level or nil if disabled
        attr_reader :level

        # Enables logging for all instrumentation events.
        #
        # Creates a logger (if not provided) and registers a subscriber
        # that logs all agent operations. Log output respects the specified level.
        #
        # @param logger [Logger, nil] Custom logger instance (default: Logger.new($stdout))
        # @param level [Symbol] Log level (:debug, :info, :warn, :error) (default: :info)
        # @return [Module] self for method chaining
        #
        # @example With file logging
        #   Smolagents::Telemetry::LoggingSubscriber.enable(
        #     logger: Logger.new("agent.log"),
        #     level: :debug
        #   )
        #
        # @example Check if enabled
        #   if Smolagents::Telemetry::LoggingSubscriber.enabled?
        #     puts "Logging is active"
        #   end
        def enable(logger: nil, level: :info)
          require "logger"

          @logger = logger || create_default_logger
          @logger.level = Logger.const_get(level.to_s.upcase) if level
          @level = level

          Instrumentation.subscriber = method(:handle_event)
          self
        end

        def create_default_logger
          Logger.new($stdout, progname: "smolagents").tap do |log|
            log.formatter = proc { |_sev, _time, _prog, msg| "#{msg}\n" }
          end
        end

        # Disables logging for instrumentation events.
        #
        # Unregisters the logging subscriber and clears the logger instance.
        # Future operations will not generate logs.
        #
        # @return [nil]
        def disable
          Instrumentation.subscriber = nil
          @logger = nil
        end

        # Checks if logging is currently enabled.
        #
        # @return [Boolean] True if enabled, false otherwise
        def enabled? = !@logger.nil?

        # Events that are interesting to log (skip noisy setup events)
        EVENT_HANDLERS = {
          "smolagents.agent.run" => :log_agent_run,
          "smolagents.agent.step" => :log_agent_step,
          "smolagents.model.generate" => :log_model_generate,
          "smolagents.tool.call" => :log_tool_call
        }.freeze

        private

        def handle_event(event, payload)
          return unless @logger

          handler = EVENT_HANDLERS[event.to_s]
          return unless handler # Skip events we don't care about

          dur = payload[:duration] ? format("%.1fs", payload[:duration]) : "?"
          send(handler, payload, dur)
        end

        def log_agent_run(payload, dur)
          outcome = payload[:outcome] || (payload[:error] ? :error : :success)
          case outcome
          when :success, :final_answer
            @logger.info("done (#{dur})")
          when :error
            @logger.error("FAILED: #{payload[:error]}")
          end
        end

        def log_agent_step(payload, dur)
          step = payload[:step_number]
          outcome = payload[:outcome] || (payload[:error] ? :error : :success)
          case outcome
          when :final_answer then @logger.info("step #{step}: final answer (#{dur})")
          when :error
            err = payload[:error].to_s.lines.first&.chomp || "unknown"
            @logger.warn("step #{step}: ERROR - #{err}")
          else @logger.info("step #{step}: (#{dur})")
          end
        end

        def log_model_generate(payload, dur)
          model = payload[:model_id] || "model"
          @logger.debug("model: #{model} (#{dur})")
        end

        def log_tool_call(payload, dur)
          tool = payload[:tool_name]
          case payload[:outcome]
          when :final_answer then @logger.info("tool: #{tool} -> final_answer (#{dur})")
          when :error then @logger.warn("tool: #{tool} FAILED: #{payload[:error]}")
          else @logger.info("tool: #{tool} (#{dur})")
          end
        end
      end
    end
  end
end
