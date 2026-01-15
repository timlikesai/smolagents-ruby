module Smolagents
  module Concerns
    # Step monitoring and timing for agent operations
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
      # Hook called when module is included
      # @api private
      def self.included(base)
        base.include(Events::Emitter) unless base < Events::Emitter
      end

      # Monitor a named step with timing and metrics
      #
      # Wraps step execution with automatic timing, logging, and error handling.
      # Emits error events on failure.
      #
      # @param step_name [String] Name for this step
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

      def complete_monitoring(step_name, monitor)
        monitor.stop
        log_step_complete(step_name, monitor)
        step_monitors[step_name] = monitor
      end

      def handle_step_error(step_name, monitor, error)
        monitor.stop
        monitor.error = error
        log_step_error(step_name, error, monitor)
        emit_error(error, context: { step_name:, duration: monitor.duration }, recoverable: false) if emitting?
        raise
      end

      # Track cumulative token usage
      #
      # Adds tokens to running total and logs via logger.
      #
      # @param usage [TokenUsage] Token usage from current operation
      # @return [TokenUsage] Updated total token usage
      def track_tokens(usage)
        @total_tokens = total_token_usage + usage
        t = @total_tokens
        logger&.debug("Tokens: +#{usage.input_tokens}/+#{usage.output_tokens} (#{t.input_tokens}/#{t.output_tokens})")
      end

      # Get total token usage since reset
      #
      # @return [TokenUsage] Cumulative token usage
      def total_token_usage = @total_tokens || TokenUsage.zero

      # Reset all monitoring state
      #
      # Clears token counters and step history.
      #
      # @return [void]
      def reset_monitoring
        @total_tokens = TokenUsage.zero
        @step_history = []
      end

      # Get step monitors by name
      #
      # @return [Hash<String, StepMonitor>] Step monitors keyed by step name
      def step_monitors = @step_monitors ||= {}

      # Log step start
      # @param step_name [String] Step name
      # @param metadata [Hash] Additional context
      # @api private
      def log_step_start(step_name, metadata)
        logger&.info("Starting step: #{step_name}#{" (#{metadata})" unless metadata.empty?}")
      end

      # Log step completion
      # @param step_name [String] Step name
      # @param monitor [StepMonitor] Monitor with timing
      # @api private
      def log_step_complete(step_name, monitor)
        logger&.info("Completed step: #{step_name} in #{monitor.timing.duration&.round(3)}s")
      end

      # Log step error
      # @param step_name [String] Step name
      # @param error [StandardError] Error that occurred
      # @param monitor [StepMonitor] Monitor with timing
      # @api private
      def log_step_error(step_name, error, monitor)
        dur = monitor.timing.duration&.round(3)
        logger&.error("Step failed: #{step_name} after #{dur}s: #{error.class} - #{error.message}")
      end

      # Get the logger instance
      # @return [Logger, nil] Logger or nil if not set
      def logger
        defined?(@logger) ? @logger : nil
      end

      # Per-step monitoring with timing and custom metrics
      #
      # Immutable tracking of timing information and custom metrics for a step.
      #
      # @!attribute [r] step_name
      #   @return [String] Name of the step being monitored
      # @!attribute [r] metadata
      #   @return [Hash] Additional context passed at creation
      # @!attribute [r] timing
      #   @return [Timing] Timing object tracking duration
      # @!attribute [rw] error
      #   @return [StandardError, nil] Error that occurred, if any
      class StepMonitor
        attr_reader :step_name, :metadata, :timing
        attr_accessor :error

        # Initialize step monitor
        #
        # @param step_name [String] Name for this step
        # @param metadata [Hash] Additional context data
        def initialize(step_name, metadata = {})
          @step_name = step_name
          @metadata = metadata
          @timing = Timing.start_now
          @error = nil
          @custom_metrics = {}
        end

        # Stop timing this step
        # @return [Timing] Stopped timing object
        def stop = @timing = @timing.stop

        # Record a custom metric for this step
        #
        # @param key [Symbol, String] Metric name
        # @param value [Object] Metric value
        # @return [Object] The recorded value
        # @example
        #   monitor.record_metric("result_count", 42)
        def record_metric(key, value) = @custom_metrics[key.to_sym] = value

        # Get all custom metrics recorded for this step
        # @return [Hash<Symbol, Object>] Custom metrics
        def metrics = @custom_metrics

        # Check if step had an error
        # @return [Boolean] true if error occurred
        def error? = !@error.nil?

        # Get step duration in seconds
        # @return [Float, nil] Duration or nil if still running
        def duration = @timing.duration
      end
    end
  end
end
