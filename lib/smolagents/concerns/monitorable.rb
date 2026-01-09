# frozen_string_literal: true

module Smolagents
  module Concerns
    # Monitoring and logging support for agents.
    # Provides a clean DSL for tracking agent execution.
    #
    # @example Basic monitoring
    #   class MyAgent
    #     include Concerns::Monitorable
    #
    #     def run(task)
    #       monitor_step(:initialization) do
    #         setup_tools
    #       end
    #
    #       monitor_step(:execution) do
    #         execute_task(task)
    #       end
    #     end
    #   end
    #
    # @example With custom metrics
    #   monitor_step(:api_call, metadata: { model: "gpt-4" }) do |monitor|
    #     result = call_api
    #     monitor.record_tokens(result.token_usage)
    #     result
    #   end
    module Monitorable
      # Monitor a step with automatic timing and error tracking.
      #
      # @param step_name [Symbol, String] name of the step
      # @param metadata [Hash] additional metadata to track
      # @yield [monitor] block to execute and monitor
      # @yieldparam monitor [StepMonitor] monitor for recording metrics
      # @return [Object] result of the block
      def monitor_step(step_name, metadata: {})
        monitor = StepMonitor.new(step_name, metadata)
        log_step_start(step_name, metadata)

        result = yield(monitor)
        monitor.stop

        log_step_complete(step_name, monitor)
        call_step_callbacks(:on_step_complete, step_name, monitor)

        result
      rescue StandardError => e
        monitor.stop
        monitor.error = e

        log_step_error(step_name, e, monitor)
        call_step_callbacks(:on_step_error, step_name, e, monitor)

        raise
      end

      # Track token usage across steps.
      #
      # @param usage [TokenUsage] token usage to record
      def track_tokens(usage)
        @total_tokens ||= { input: 0, output: 0 }
        @total_tokens[:input] += usage.input_tokens
        @total_tokens[:output] += usage.output_tokens

        logger&.debug("Tokens: +#{usage.input_tokens} input, +#{usage.output_tokens} output " \
                      "(total: #{@total_tokens[:input]}/#{@total_tokens[:output]})")

        call_step_callbacks(:on_tokens_tracked, usage)
      end

      # Register a callback for monitoring events.
      #
      # @param event [Symbol] event name (:on_step_complete, :on_step_error, :on_tokens_tracked)
      # @param callable [Proc, #call] callback to execute
      #
      # @example Register callbacks
      #   agent.register_callback(:on_step_complete) do |step_name, monitor|
      #     puts "Completed #{step_name} in #{monitor.timing.duration}s"
      #   end
      #
      #   agent.register_callback(:on_tokens_tracked) do |usage|
      #     metrics.record("tokens.input", usage.input_tokens)
      #   end
      def register_callback(event, callable = nil, &block)
        @callbacks ||= Hash.new { |h, k| h[k] = [] }
        @callbacks[event] << (callable || block)
      end

      # Unregister callbacks for an event.
      #
      # @param event [Symbol] event name
      def clear_callbacks(event = nil)
        if event
          @callbacks&.delete(event)
        else
          @callbacks&.clear
        end
      end

      # Get total token usage.
      #
      # @return [Hash] { input: Integer, output: Integer }
      def total_token_usage
        @total_tokens || { input: 0, output: 0 }
      end

      # Reset monitoring state.
      def reset_monitoring
        @total_tokens = { input: 0, output: 0 }
        @step_history = []
      end

      private

      def log_step_start(step_name, metadata)
        logger&.info("▶ Starting step: #{step_name}#{" (#{metadata})" unless metadata.empty?}")
      end

      def log_step_complete(step_name, monitor)
        duration = monitor.timing.duration&.round(3)
        logger&.info("✓ Completed step: #{step_name} in #{duration}s")
      end

      def log_step_error(step_name, error, monitor)
        duration = monitor.timing.duration&.round(3)
        logger&.error("✗ Step failed: #{step_name} after #{duration}s: #{error.class} - #{error.message}")
      end

      def call_step_callbacks(event, *args)
        @callbacks ||= {}
        @callbacks[event]&.each { |callback| callback.call(*args) }
      rescue StandardError => e
        logger&.warn("Callback error for #{event}: #{e.message}")
      end

      def logger
        @logger if defined?(@logger)
      end

      # Simple monitor object yielded to blocks.
      # Manages its own timing state for clean Ruby idioms.
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

        # Stop timing.
        def stop
          @end_time = Time.now
        end

        # Get timing as a Timing object.
        #
        # @return [Timing]
        def timing
          Timing.new(start_time: @start_time, end_time: @end_time)
        end

        # Record a custom metric for this step.
        #
        # @param key [Symbol, String] metric name
        # @param value [Object] metric value
        def record_metric(key, value)
          @custom_metrics[key.to_sym] = value
        end

        # Get custom metrics.
        #
        # @return [Hash]
        def metrics
          @custom_metrics
        end

        # Check if step had an error.
        #
        # @return [Boolean]
        def error?
          !@error.nil?
        end

        # Get duration in seconds.
        #
        # @return [Float, nil]
        def duration
          return nil unless @end_time

          @end_time - @start_time
        end
      end
    end
  end
end
