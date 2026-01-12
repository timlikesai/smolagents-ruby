module Smolagents
  module Concerns
    module Monitorable
      def monitor_step(step_name, metadata: {})
        monitor = StepMonitor.new(step_name, metadata)
        log_step_start(step_name, metadata)

        result = yield(monitor)
        monitor.stop

        log_step_complete(step_name, monitor)
        trigger_callbacks(:on_step_complete, step_name, monitor)
        step_monitors[step_name] = monitor
        result
      rescue StandardError => e
        monitor.stop
        monitor.error = e
        log_step_error(step_name, e, monitor)
        trigger_callbacks(:on_step_error, step_name, e, monitor)
        raise
      end

      def track_tokens(usage)
        @total_tokens ||= { input: 0, output: 0 }
        @total_tokens[:input] += usage.input_tokens
        @total_tokens[:output] += usage.output_tokens
        logger&.debug("Tokens: +#{usage.input_tokens} input, +#{usage.output_tokens} output (total: #{@total_tokens[:input]}/#{@total_tokens[:output]})")
        trigger_callbacks(:on_tokens_tracked, usage)
      end

      def register_callback(event, callable = nil, &block)
        callbacks[event] << (callable || block) if callable || block
      end

      def clear_callbacks(event = nil)
        event ? callbacks.delete(event) : callbacks.clear
      end

      def total_token_usage = @total_tokens || { input: 0, output: 0 }

      def reset_monitoring
        @total_tokens = { input: 0, output: 0 }
        @step_history = []
      end

      def step_monitors = @step_monitors ||= {}

      private

      def callbacks
        @callbacks ||= Hash.new { |h, k| h[k] = [] }
      end

      def trigger_callbacks(event, *)
        callbacks[event].each do |callback|
          callback.call(*)
        rescue StandardError => e
          warn "Callback error for #{event}: #{e.message}"
        end
      end

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
        attr_reader :step_name, :metadata
        attr_accessor :error

        def initialize(step_name, metadata = {})
          @step_name = step_name
          @metadata = metadata
          @start_time = Time.now
          @end_time = nil
          @error = nil
          @custom_metrics = {}
        end

        def stop = @end_time = Time.now
        def timing = Timing.new(start_time: @start_time, end_time: @end_time)
        def record_metric(key, value) = @custom_metrics[key.to_sym] = value
        def metrics = @custom_metrics
        def error? = !@error.nil?
        def duration = @end_time && (@end_time - @start_time)
      end
    end
  end
end
