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

        private

        def handle_event(event, payload)
          return unless @logger

          duration = payload[:duration]
          duration_str = duration ? format("%.3fs", duration) : "?"

          case event.to_s
          when "smolagents.agent.run"
            log_agent_run(payload, duration_str)
          when "smolagents.agent.step"
            log_agent_step(payload, duration_str)
          when "smolagents.model.generate"
            log_model_generate(payload, duration_str)
          when "smolagents.tool.call"
            log_tool_call(payload, duration_str)
          when "smolagents.executor.execute"
            log_executor(payload, duration_str)
          else
            log_generic(event, payload, duration_str)
          end
        end

        def log_agent_run(payload, duration_str)
          agent = payload[:agent_class]

          case payload[:outcome]
          when :success
            @logger.info("[agent.run] #{agent} completed successfully in #{duration_str}")
          when :final_answer
            @logger.info("[agent.run] #{agent} returned final answer in #{duration_str}")
          when :error
            @logger.error("[agent.run] #{agent} FAILED after #{duration_str}: #{payload[:error]}")
          else
            # Fallback for legacy code paths
            if payload[:error]
              @logger.error("[agent.run] #{agent} FAILED after #{duration_str}: #{payload[:error]}")
            else
              @logger.info("[agent.run] #{agent} completed in #{duration_str}")
            end
          end
        end

        def log_agent_step(payload, duration_str)
          step = payload[:step_number]
          agent = payload[:agent_class]

          case payload[:outcome]
          when :success
            @logger.debug("[step #{step}] #{agent} completed in #{duration_str}")
          when :final_answer
            @logger.debug("[step #{step}] #{agent} reached final answer in #{duration_str}")
          when :error
            @logger.warn("[step #{step}] #{agent} error after #{duration_str}: #{payload[:error]}")
          else
            # Fallback for legacy code paths
            if payload[:error]
              @logger.warn("[step #{step}] #{agent} error after #{duration_str}: #{payload[:error]}")
            else
              @logger.debug("[step #{step}] #{agent} completed in #{duration_str}")
            end
          end
        end

        def log_model_generate(payload, duration_str)
          model = payload[:model_id] || payload[:model_class]

          case payload[:outcome]
          when :success
            @logger.debug("[model] #{model} generated in #{duration_str}")
          when :error
            @logger.error("[model] #{model} FAILED after #{duration_str}: #{payload[:error]}")
          else
            # Fallback for legacy code paths
            if payload[:error]
              @logger.error("[model] #{model} FAILED after #{duration_str}: #{payload[:error]}")
            else
              @logger.debug("[model] #{model} generated in #{duration_str}")
            end
          end
        end

        def log_tool_call(payload, duration_str)
          tool = payload[:tool_name] || payload[:tool_class]

          case payload[:outcome]
          when :success
            @logger.debug("[tool] #{tool} completed in #{duration_str}")
          when :final_answer
            @logger.info("[tool] #{tool} returned final answer in #{duration_str}")
          when :error
            @logger.warn("[tool] #{tool} FAILED after #{duration_str}: #{payload[:error]}")
          else
            # Fallback for legacy code paths
            if payload[:error]
              @logger.warn("[tool] #{tool} FAILED after #{duration_str}: #{payload[:error]}")
            else
              @logger.debug("[tool] #{tool} called in #{duration_str}")
            end
          end
        end

        def log_executor(payload, duration_str)
          executor = payload[:executor_class]

          case payload[:outcome]
          when :success
            @logger.debug("[executor] #{executor} executed in #{duration_str}")
          when :error
            @logger.error("[executor] #{executor} FAILED after #{duration_str}: #{payload[:error]}")
          else
            # Fallback for legacy code paths
            if payload[:error]
              @logger.error("[executor] #{executor} FAILED after #{duration_str}: #{payload[:error]}")
            else
              @logger.debug("[executor] #{executor} executed in #{duration_str}")
            end
          end
        end

        def log_generic(event, payload, duration_str)
          case payload[:outcome]
          when :success
            @logger.debug("[#{event}] completed in #{duration_str}")
          when :final_answer
            @logger.info("[#{event}] reached final answer in #{duration_str}")
          when :error
            @logger.warn("[#{event}] error after #{duration_str}: #{payload[:error]}")
          else
            # Fallback for legacy code paths
            if payload[:error]
              @logger.warn("[#{event}] error after #{duration_str}: #{payload[:error]}")
            else
              @logger.debug("[#{event}] completed in #{duration_str}")
            end
          end
        end
      end
    end
  end
end
