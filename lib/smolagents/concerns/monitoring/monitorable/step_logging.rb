module Smolagents
  module Concerns
    module Monitorable
      # Step-level logging for monitoring.
      #
      # Provides logging methods for step lifecycle events.
      # Requires the including class to respond to `logger`.
      #
      # @example Logging a step lifecycle
      #   log_step_start(:search, { query: "ruby" })
      #   # ... perform step ...
      #   log_step_complete(:search, monitor)
      module StepLogging
        # Log step start.
        #
        # @param step_name [String, Symbol] Step name
        # @param metadata [Hash] Additional context
        # @api private
        def log_step_start(step_name, metadata)
          msg = "Starting step: #{step_name}"
          msg += " (#{metadata})" unless metadata.empty?
          logger&.info(msg)
        end

        # Log step completion.
        #
        # @param step_name [String, Symbol] Step name
        # @param monitor [StepMonitor] Monitor with timing
        # @api private
        def log_step_complete(step_name, monitor)
          duration = monitor.timing.duration&.round(3)
          logger&.info("Completed step: #{step_name} in #{duration}s")
        end

        # Log step error.
        #
        # @param step_name [String, Symbol] Step name
        # @param error [StandardError] Error that occurred
        # @param monitor [StepMonitor] Monitor with timing
        # @api private
        def log_step_error(step_name, error, monitor)
          duration = monitor.timing.duration&.round(3)
          logger&.error("Step failed: #{step_name} after #{duration}s: #{error.class} - #{error.message}")
        end

        # Get the logger instance.
        #
        # @return [Logger, nil] Logger or nil if not set
        def logger
          defined?(@logger) ? @logger : nil
        end
      end
    end
  end
end
