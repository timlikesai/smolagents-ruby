module Smolagents
  module Concerns
    module Monitorable
      # Per-step monitoring with timing and custom metrics.
      #
      # Tracks timing information and custom metrics for a step.
      # Created by {Monitorable#monitor_step} and accessible via {Monitorable#step_monitors}.
      #
      # @!attribute [r] step_name
      #   @return [String, Symbol] Name of the step being monitored
      # @!attribute [r] metadata
      #   @return [Hash] Additional context passed at creation
      # @!attribute [r] timing
      #   @return [Timing] Timing object tracking duration
      # @!attribute [rw] error
      #   @return [StandardError, nil] Error that occurred, if any
      #
      # @example Recording metrics during a step
      #   monitor.record_metric(:items_processed, 42)
      #   monitor.record_metric(:cache_hit_rate, 0.85)
      #   monitor.metrics  # => { items_processed: 42, cache_hit_rate: 0.85 }
      class StepMonitor
        attr_reader :step_name, :metadata, :timing
        attr_accessor :error

        # Initialize step monitor.
        #
        # @param step_name [String, Symbol] Name for this step
        # @param metadata [Hash] Additional context data
        def initialize(step_name, metadata = {})
          @step_name = step_name
          @metadata = metadata
          @timing = Timing.start_now
          @error = nil
          @custom_metrics = {}
        end

        # Stop timing this step.
        #
        # @return [Timing] Stopped timing object
        def stop = @timing = @timing.stop

        # Record a custom metric for this step.
        #
        # @param key [Symbol, String] Metric name
        # @param value [Object] Metric value
        # @return [Object] The recorded value
        def record_metric(key, value) = @custom_metrics[key.to_sym] = value

        # Get all custom metrics recorded for this step.
        #
        # @return [Hash<Symbol, Object>] Custom metrics
        def metrics = @custom_metrics

        # Check if step had an error.
        #
        # @return [Boolean] true if error occurred
        def error? = !@error.nil?

        # Get step duration in seconds.
        #
        # @return [Float, nil] Duration or nil if still running
        def duration = @timing.duration
      end
    end
  end
end
