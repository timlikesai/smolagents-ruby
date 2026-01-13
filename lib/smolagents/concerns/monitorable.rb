module Smolagents
  module Concerns
    # Step monitoring and timing for agent operations.
    #
    # All observations are logged and emitted as events when connected to an event queue.
    # No callbacks - just events.
    #
    module Monitorable
      def self.included(base)
        base.include(Events::Emitter) unless base < Events::Emitter
      end

      def monitor_step(step_name, metadata: {})
        monitor = StepMonitor.new(step_name, metadata)
        log_step_start(step_name, metadata)

        result = yield(monitor)
        monitor.stop

        log_step_complete(step_name, monitor)
        step_monitors[step_name] = monitor
        result
      rescue StandardError => e
        monitor.stop
        monitor.error = e
        log_step_error(step_name, e, monitor)
        emit_error(e, context: { step_name:, duration: monitor.duration }, recoverable: false) if emitting?
        raise
      end

      def track_tokens(usage)
        @total_tokens = total_token_usage + usage
        logger&.debug("Tokens: +#{usage.input_tokens} input, +#{usage.output_tokens} output (total: #{@total_tokens.input_tokens}/#{@total_tokens.output_tokens})")
      end

      def total_token_usage = @total_tokens || TokenUsage.zero

      def reset_monitoring
        @total_tokens = TokenUsage.zero
        @step_history = []
      end

      def step_monitors = @step_monitors ||= {}

      def log_step_start(step_name, metadata)
        logger&.info("Starting step: #{step_name}#{" (#{metadata})" unless metadata.empty?}")
      end

      def log_step_complete(step_name, monitor)
        logger&.info("Completed step: #{step_name} in #{monitor.timing.duration&.round(3)}s")
      end

      def log_step_error(step_name, error, monitor)
        logger&.error("Step failed: #{step_name} after #{monitor.timing.duration&.round(3)}s: #{error.class} - #{error.message}")
      end

      def logger
        defined?(@logger) ? @logger : nil
      end

      class StepMonitor
        attr_reader :step_name, :metadata, :timing
        attr_accessor :error

        def initialize(step_name, metadata = {})
          @step_name = step_name
          @metadata = metadata
          @timing = Timing.start_now
          @error = nil
          @custom_metrics = {}
        end

        def stop = @timing = @timing.stop
        def record_metric(key, value) = @custom_metrics[key.to_sym] = value
        def metrics = @custom_metrics
        def error? = !@error.nil?
        def duration = @timing.duration
      end
    end
  end
end
