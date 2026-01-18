require_relative "monitorable/step_monitor"
require_relative "monitorable/step_logging"
require_relative "monitorable/token_tracking"

module Smolagents
  module Concerns
    # Step monitoring and timing for agent operations.
    #
    # All observations are logged and emitted as events when connected to an event queue.
    # No callbacks - just events. Integrates with Events::Emitter for event-driven monitoring.
    #
    # @example Monitoring a step
    #   result = monitor_step("search") do |monitor|
    #     response = perform_search
    #     monitor.record_metric("result_count", response.size)
    #     response
    #   end
    #   # Logs start, completion, and metrics
    #
    # @see StepMonitor For per-step monitoring details
    # @see Events::Emitter For event system integration
    module Monitorable
      # Hook called when module is included.
      # @api private
      def self.included(base)
        BaseConcern.conditionally_include(base, Events::Emitter)
        base.include(StepLogging)
        base.include(TokenTracking)
      end

      # Monitor a named step with timing and metrics.
      #
      # Wraps step execution with automatic timing, logging, and error handling.
      # Emits error events on failure.
      #
      # @param step_name [String, Symbol] Name for this step
      # @param metadata [Hash] Additional context (logged at start)
      # @yield [monitor] Yields StepMonitor for metric recording
      # @yieldparam monitor [StepMonitor] For recording custom metrics
      # @return [Object] Result of the block
      # @raise [StandardError] Re-raises exceptions after logging
      def monitor_step(step_name, metadata: {})
        monitor = StepMonitor.new(step_name, metadata)
        log_step_start(step_name, metadata)
        yield(monitor).tap { complete_monitoring(step_name, monitor) }
      rescue StandardError => e
        handle_step_error(step_name, monitor, e)
      end

      # Get step monitors by name.
      #
      # @return [Hash<String, StepMonitor>] Step monitors keyed by step name
      def step_monitors = @step_monitors ||= {}

      # Reset all monitoring state.
      #
      # Clears token counters and step history.
      #
      # @return [void]
      def reset_monitoring
        reset_tokens
        @step_history = []
      end

      private

      # Complete step monitoring after successful execution.
      # @api private
      def complete_monitoring(step_name, monitor)
        monitor.stop
        log_step_complete(step_name, monitor)
        step_monitors[step_name] = monitor
      end

      # Handle step error: log, emit, and re-raise.
      # @api private
      def handle_step_error(step_name, monitor, error)
        monitor.stop
        monitor.error = error
        log_step_error(step_name, error, monitor)
        emit_error(error, context: { step_name:, duration: monitor.duration }, recoverable: false) if emitting?
        raise
      end
    end
  end
end
