# frozen_string_literal: true

module Smolagents
  module Concerns
    # Monitoring and logging support for agents with timing and callback DSL.
    module Monitorable
      def monitor_step(step_name, metadata: {})
        monitor = StepMonitor.new(step_name, metadata)
        log_step_start(step_name, metadata)

        result = yield(monitor)
        monitor.stop

        log_step_complete(step_name, monitor)
        call_step_callbacks(:on_step_complete, step_name, monitor)
        step_monitors[step_name] = monitor
        result
      rescue StandardError => e
        monitor.stop
        monitor.error = e
        log_step_error(step_name, e, monitor)
        call_step_callbacks(:on_step_error, step_name, e, monitor)
        raise
      end

      def track_tokens(usage)
        @total_tokens ||= { input: 0, output: 0 }
        @total_tokens[:input] += usage.input_tokens
        @total_tokens[:output] += usage.output_tokens
        logger&.debug("Tokens: +#{usage.input_tokens} input, +#{usage.output_tokens} output (total: #{@total_tokens[:input]}/#{@total_tokens[:output]})")
        call_step_callbacks(:on_tokens_tracked, usage)
      end

      def register_callback(event, callable = nil, &block)
        callbacks_registry.register(event, &callable || block)
      end

      def clear_callbacks(event = nil) = callbacks_registry.clear(event)
      def total_token_usage = @total_tokens || { input: 0, output: 0 }

      def reset_monitoring
        (@total_tokens = { input: 0, output: 0 }
         @step_history = [])
      end

      def step_monitors = @step_monitors ||= {}

      private

      def log_step_start(step_name, metadata)
        logger&.info("Starting step: #{step_name}#{" (#{metadata})" unless metadata.empty?}")
      end

      def log_step_complete(step_name, monitor)
        logger&.info("Completed step: #{step_name} in #{monitor.timing.duration&.round(3)}s")
      end

      def log_step_error(step_name, error, monitor)
        logger&.error("Step failed: #{step_name} after #{monitor.timing.duration&.round(3)}s: #{error.class} - #{error.message}")
      end

      def call_step_callbacks(event, *)
        callbacks_registry.trigger(event, *)
      end

      def callbacks_registry
        @callbacks_registry ||= Monitoring::CallbackRegistry.new
      end

      def logger
        defined?(@logger) ? @logger : nil
      end

      # Simple monitor object yielded to blocks.
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
