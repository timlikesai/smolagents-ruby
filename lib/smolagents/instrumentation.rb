# frozen_string_literal: true

module Smolagents
  # Instrumentation module for metrics collection and monitoring.
  #
  # This module provides hooks for external metrics systems (Prometheus, StatsD, Datadog)
  # to collect performance metrics and operational data from agent execution.
  #
  # @example Using with Prometheus
  #   require 'prometheus/client'
  #
  #   registry = Prometheus::Client.registry
  #   step_duration = registry.histogram(:smolagents_step_duration_seconds, 'Step duration')
  #   model_calls = registry.counter(:smolagents_model_calls_total, 'Model API calls')
  #
  #   Smolagents::Instrumentation.subscriber = ->(event, payload) do
  #     case event
  #     when 'smolagents.agent.step'
  #       step_duration.observe(payload[:duration])
  #     when 'smolagents.model.generate'
  #       model_calls.increment(labels: { model: payload[:model_id] })
  #     end
  #   end
  #
  # @example Using with StatsD
  #   require 'statsd-instrument'
  #
  #   Smolagents::Instrumentation.subscriber = ->(event, payload) do
  #     StatsD.measure("smolagents.#{event}", payload[:duration] * 1000)
  #     StatsD.increment("smolagents.#{event}.count")
  #   end
  #
  module Instrumentation
    class << self
      # @return [Proc, nil] The subscriber that receives instrumentation events
      attr_accessor :subscriber

      # Instrument a block of code and emit an event with timing information.
      #
      # @param event [String] The event name (e.g., 'smolagents.agent.run')
      # @param payload [Hash] Additional event data (model_id, step_number, etc.)
      # @yield The block to instrument
      # @return The result of the block
      #
      # @example Basic usage
      #   result = Instrumentation.instrument('smolagents.tool.call', tool_name: 'web_search') do
      #     perform_search(query)
      #   end
      #
      def instrument(event, payload = {})
        # If no subscriber, just execute the block without overhead
        return yield unless subscriber

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

        # Emit success event with duration
        subscriber.call(event, payload.merge(duration: duration))
        result
      rescue StandardError => e
        # Calculate duration even on error
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time if start_time

        # Emit error event with duration and error information
        subscriber&.call(event, payload.merge(error: e.class.name, duration: duration))
        raise
      end
    end
  end
end
