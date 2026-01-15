module Smolagents
  module Concerns
    module RequestQueue
      # Queue operations: enqueue, dequeue, priority handling, capacity validation.
      module Operations
        # Generate with queueing - requests are processed one at a time.
        # @param messages [Array<Hash>] Messages to send
        # @param priority [Symbol] :normal or :high
        # @param kwargs [Hash] Additional generation parameters
        # @return [Object] Generation result
        def queued_generate(messages, priority: :normal, **kwargs)
          return generate_without_queue(messages, **kwargs) unless @queue_enabled

          validate_queue_capacity!
          request = build_queued_request(messages, priority, kwargs)
          enqueue_request(request, priority)
          await_result(request.result_queue)
        end

        # Clear all pending requests.
        # @return [void]
        def clear_queue = @request_queue&.clear

        private

        def validate_queue_capacity!
          return unless @queue_max_depth && queue_depth >= @queue_max_depth

          raise AgentError, "Queue full (#{queue_depth}/#{@queue_max_depth})"
        end

        def build_queued_request(messages, priority, kwargs)
          QueuedRequest.new(
            id: SecureRandom.uuid,
            priority:,
            messages: messages.freeze,
            kwargs: kwargs.freeze,
            result_queue: Thread::Queue.new,
            queued_at: Time.now
          )
        end

        def enqueue_request(request, priority)
          priority == :high ? reorder_with_priority(request) : @request_queue.push(request)
        end

        def reorder_with_priority(high_priority_request)
          # Atomic reorder: drain queue, insert high priority first, refill
          existing = drain_queue
          @request_queue.push(high_priority_request)
          existing.each { |req| @request_queue.push(req) }
        end

        def drain_queue
          existing = []
          while @request_queue.size.positive?
            begin
              existing << @request_queue.pop(true)
            rescue ThreadError
              break
            end
          end
          existing
        end

        def await_result(result_queue)
          result = result_queue.pop
          result.is_a?(Exception) ? raise(result) : result
        end

        def generate_without_queue(messages, **)
          if respond_to?(:original_generate, true)
            original_generate(messages, **)
          elsif respond_to?(:generate, true)
            method(:generate).super_method&.call(messages, **) || generate(messages, **)
          else
            raise NotImplementedError, "No generate method found"
          end
        end
      end
    end
  end
end
