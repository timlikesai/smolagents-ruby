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
    #   agent = Smolagents.code.model { ... }.build
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

          @logger = logger || Logger.new($stdout, progname: "smolagents")
          @logger.level = Logger.const_get(level.to_s.upcase) if level
          @level = level

          Instrumentation.subscriber = method(:handle_event)
          self
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

        EVENT_HANDLERS = { "smolagents.agent.run" => :log_agent_run, "smolagents.agent.step" => :log_agent_step,
                           "smolagents.model.generate" => :log_model_generate, "smolagents.tool.call" => :log_tool_call,
                           "smolagents.executor.execute" => :log_executor }.freeze

        private

        def handle_event(event, payload)
          return unless @logger

          dur_str = payload[:duration] ? format("%.3fs", payload[:duration]) : "?"
          handler = EVENT_HANDLERS[event.to_s]
          handler ? send(handler, payload, dur_str) : log_generic(event, payload, dur_str)
        end

        def log_agent_run(payload, dur)
          agent = payload[:agent_class]
          outcome = payload[:outcome] || (payload[:error] ? :error : :success)
          msg = { success: "completed successfully", final_answer: "returned final answer",
                  error: "FAILED" }[outcome] || "completed"
          level = outcome == :error ? :error : :info
          @logger.send(level, "[agent.run] #{agent} #{msg}#{": #{payload[:error]}" if outcome == :error} in #{dur}")
        end

        def log_agent_step(payload, dur)
          step = payload[:step_number]
          agent = payload[:agent_class]
          outcome = payload[:outcome] || (payload[:error] ? :error : :success)
          msg = { success: "completed", final_answer: "reached final answer", error: "error" }[outcome] || "completed"
          level = outcome == :error ? :warn : :debug
          @logger.send(level, "[step #{step}] #{agent} #{msg}#{": #{payload[:error]}" if outcome == :error} in #{dur}")
        end

        def log_model_generate(payload, dur)
          log_outcome("model", payload[:model_id] || payload[:model_class], payload, dur, error_level: :error)
        end

        def log_tool_call(payload, dur)
          log_outcome("tool", payload[:tool_name] || payload[:tool_class], payload, dur, error_level: :warn)
        end

        def log_executor(payload, dur)
          log_outcome("executor", payload[:executor_class], payload, dur, error_level: :error)
        end

        def log_generic(event, payload, dur)
          log_outcome(event, nil, payload, dur, error_level: :warn)
        end

        def log_outcome(tag, entity, payload, dur, error_level:)
          prefix = entity ? "[#{tag}] #{entity}" : "[#{tag}]"
          case payload[:outcome]
          when :success then @logger.debug("#{prefix} completed in #{dur}")
          when :final_answer then @logger.info("#{prefix} returned final answer in #{dur}")
          when :error then @logger.send(error_level, "#{prefix} FAILED after #{dur}: #{payload[:error]}")
          else log_outcome_fallback(prefix, payload, dur, error_level)
          end
        end

        def log_outcome_fallback(prefix, payload, dur, error_level)
          if payload[:error]
            @logger.send(error_level, "#{prefix} FAILED after #{dur}: #{payload[:error]}")
          else
            @logger.debug("#{prefix} completed in #{dur}")
          end
        end
      end
    end
  end
end
