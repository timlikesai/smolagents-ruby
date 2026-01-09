# frozen_string_literal: true

module Smolagents
  module Concerns
    # Streaming utilities for agents and models.
    # Provides Ruby-native streaming with Enumerators and Fibers.
    #
    # @example Basic streaming
    #   class MyAgent
    #     include Concerns::Streamable
    #
    #     def run_with_streaming(task)
    #       stream do |yielder|
    #         yielder << "Starting task"
    #         result = execute(task)
    #         yielder << result
    #       end
    #     end
    #   end
    #
    # @example Chaining streams
    #   agent.run_with_streaming(task)
    #     .select { |item| item.is_a?(ActionStep) }
    #     .map { |step| format_for_ui(step) }
    #     .each { |formatted| display(formatted) }
    module Streamable
      # Create a streamable enumerator.
      #
      # @yield [yielder] block that yields items to stream
      # @return [Enumerator] lazy enumerator
      def stream(&)
        Enumerator.new(&).lazy
      end

      # Create a Fiber-based stream with bidirectional communication.
      # Useful for pause/resume and interactive agents.
      #
      # @yield block that uses Fiber.yield to emit values
      # @return [Fiber] fiber for manual control
      #
      # @example Interactive agent
      #   fiber = stream_fiber do
      #     result = process_step_1
      #     user_input = Fiber.yield result  # Wait for user
      #     process_step_2(user_input)
      #   end
      #
      #   step1 = fiber.resume
      #   display(step1)
      #   final = fiber.resume(get_user_input)
      def stream_fiber(&)
        Fiber.new(&)
      end

      # Stream with automatic error handling and recovery.
      #
      # @param on_error [Proc, Symbol] error handler (:skip, :stop, or custom proc)
      # @yield [yielder] block that yields items
      # @return [Enumerator] error-handling enumerator
      #
      # @example Skip errors
      #   safe_stream(on_error: :skip) do |yielder|
      #     risky_items.each do |item|
      #       yielder << process(item)  # Errors are skipped
      #     end
      #   end
      #
      # @example Custom error handling
      #   safe_stream(on_error: ->(e) { log_error(e) }) do |yielder|
      #     yielder << dangerous_operation
      #   end
      def safe_stream(on_error: :skip, &block)
        Enumerator.new do |yielder|
          catch(:stop_stream) do
            block.call(yielder)
          rescue StandardError => e
            case on_error
            when :skip
              # Continue - error is swallowed
            when :stop
              throw :stop_stream
            when Proc
              on_error.call(e)
            else
              raise
            end
          end
        end.lazy
      end

      # Merge multiple streams into one.
      #
      # @param streams [Array<Enumerator>] streams to merge
      # @return [Enumerator] merged stream
      #
      # @example Parallel agent execution
      #   agent1_stream = agent1.run_stream(task1)
      #   agent2_stream = agent2.run_stream(task2)
      #   merge_streams(agent1_stream, agent2_stream).each { |result| handle(result) }
      def merge_streams(*streams)
        Enumerator.new do |yielder|
          streams.each do |stream|
            stream.each { |item| yielder << item }
          end
        end.lazy
      end

      # Transform a stream with a given block.
      #
      # @param stream [Enumerator] input stream
      # @yield [item] transformation block
      # @return [Enumerator] transformed stream
      def transform_stream(stream, &)
        stream.lazy.map(&)
      end

      # Filter a stream with a given predicate.
      #
      # @param stream [Enumerator] input stream
      # @yield [item] filter predicate
      # @return [Enumerator] filtered stream
      def filter_stream(stream, &)
        stream.lazy.select(&)
      end

      # Take items from stream until predicate is false.
      #
      # @param stream [Enumerator] input stream
      # @yield [item] stop predicate
      # @return [Enumerator] stream that stops when predicate is false
      def take_until(stream, &block)
        stream.lazy.take_while { |item| !block.call(item) }
      end

      # Batch items from a stream.
      #
      # @param stream [Enumerator] input stream
      # @param size [Integer] batch size
      # @return [Enumerator] stream of arrays
      #
      # @example Batch processing
      #   agent.run_stream(task)
      #     .batch(10)
      #     .each { |batch| process_batch(batch) }
      def batch_stream(stream, size:)
        stream.lazy.each_slice(size)
      end

      # Collect stream into an array (consumes entire stream).
      #
      # @param stream [Enumerator] input stream
      # @return [Array] collected items
      def collect_stream(stream)
        stream.to_a
      end

      # Execute a callback for each item without consuming the stream.
      #
      # @param stream [Enumerator] input stream
      # @param callback [Proc] callback to execute
      # @return [Enumerator] original stream (for chaining)
      #
      # @example Logging without consuming
      #   agent.run_stream(task)
      #     .tap_stream { |step| logger.info(step) }
      #     .each { |step| process(step) }
      def tap_stream(stream, &callback)
        stream.lazy.tap do |yielder|
          callback.call(yielder)
        end
      end
    end
  end
end
