# Event emission - producing events for observers.

require_relative "base"
require_relative "async_queue"

module Smolagents
  module Events
    # Event emission module.
    #
    # Provides ergonomic APIs for emitting events:
    # - Symbol-based: `emit :step_complete, step_number: 1`
    # - Block-based timing: `emit(:event) { work }` (captures duration_ms)
    # - Sync emission: `emit!` or `emit_sync`
    #
    # @example Basic emission
    #   class MyModel
    #     include Events::Emitter
    #
    #     def generate(messages)
    #       emit :model_generate_requested, model_id: @id, message_count: messages.size
    #       response = call_api(messages)
    #       emit :model_generate_completed, model_id: @id, duration_ms: elapsed
    #       response
    #     end
    #   end
    #
    # @example With timing block
    #   result = emit(:model_generate_completed, model_id: "gpt-4") { api.call }
    #
    module Emitter
      include Base

      # Emits an event.
      #
      # Accepts symbol name with kwargs, or a pre-built event object.
      # When a block is given, captures timing and yields the result.
      #
      # @overload emit(event_name, **kwargs)
      #   @param event_name [Symbol] Event name (e.g., :step_complete)
      #   @param kwargs [Hash] Event fields
      #   @return [Object] The created event
      #
      # @overload emit(event_name, **kwargs, &block)
      #   @param event_name [Symbol] Event name
      #   @param kwargs [Hash] Event fields (duration_ms auto-populated)
      #   @yield Block to execute and time
      #   @return [Object] Block result
      #
      # @overload emit(event)
      #   @param event [Object] Pre-built event object
      #   @return [Object] The event
      #
      def emit(event_or_name, **kwargs, &)
        return emit_with_timing(event_or_name, kwargs, &) if block_given?
        return event_or_name unless should_emit?

        if event_or_name.is_a?(Symbol)
          dispatch_event(build_event(event_or_name, kwargs))
        else
          dispatch_event(event_or_name)
        end
      end

      # Emits an event synchronously (blocks until handlers complete).
      # @see #emit
      def emit!(event_or_name, **kwargs, &)
        return event_or_name unless should_emit?

        event = event_or_name.is_a?(Symbol) ? build_event(event_or_name, kwargs) : event_or_name

        if block_given?
          emit_with_timing_sync(event, &)
        else
          dispatch_event(event, sync: true)
        end
      end

      alias emit_sync emit!

      # Emits an error event.
      # @param error [Exception] The error
      # @param context [Hash] Additional context
      # @param recoverable [Boolean] Whether the error is recoverable
      def emit_error(error, context: {}, recoverable: false)
        emit :error, error:, context:, recoverable:
      end

      private

      def should_emit? = !!(@event_queue || @event_handlers&.any?)

      def emit_with_timing(event_or_name, kwargs, &)
        result, duration_ms = timed_execution(&)
        return result unless should_emit?

        dispatch_event(build_timed_event(event_or_name, kwargs, duration_ms))
        result
      rescue StandardError => e
        emit_on_error(event_or_name, kwargs) if should_emit?
        raise e
      end

      def timed_execution
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round
        [result, duration]
      end

      def build_timed_event(event_or_name, kwargs, duration_ms)
        if event_or_name.is_a?(Symbol)
          build_event(event_or_name, kwargs.merge(duration_ms:))
        elsif event_or_name.respond_to?(:duration_ms)
          rebuild_with_duration(event_or_name, duration_ms)
        else
          event_or_name
        end
      end

      def emit_with_timing_sync(event)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round

        final_event = event.respond_to?(:duration_ms) ? rebuild_with_duration(event, duration_ms) : event
        dispatch_event(final_event, sync: true)
        result
      end

      def emit_on_error(event_or_name, kwargs)
        error_event = if event_or_name.is_a?(Symbol)
                        build_event(event_or_name, kwargs.merge(duration_ms: 0, outcome: :error))
                      else
                        event_or_name
                      end
        # rubocop:disable Style/RescueModifier -- silently ignore errors during error emission to prevent cascading failures
        dispatch_event(error_event) rescue nil
        # rubocop:enable Style/RescueModifier
      end

      def rebuild_with_duration(event, duration_ms)
        attrs = event.to_h.except(:id, :sequence, :created_at)
        event.class.create(**attrs, duration_ms:)
      end

      def dispatch_event(event, sync: false)
        if @event_queue
          @event_queue.push(event)
        elsif respond_to?(:consume) && @event_handlers&.any?
          sync ? consume(event) : AsyncQueue.push(event) { |e| consume(e) }
        end
        event
      end
    end
  end
end
