require_relative "../final_answer_signal"

module Smolagents
  module Executors
    module RactorLazy
      # Batch handling for FiberExecutor.
      #
      # Futures may have dependencies on other futures (e.g., @y = multiply(a: @x, b: 3)
      # where @x is itself a future). Uses wave-based resolution to handle this:
      # only batch futures whose dependencies are already resolved.
      module BatchHandling
        # Handle a batch yield from the Fiber.
        # Returns nil normally, or [:final_answer, value] if final_answer was called.
        def handle_batch(_futures)
          resolve_in_waves
          nil
        rescue FinalAnswerSignal => e
          # final_answer called during batch - return signal for process_fiber_result
          [:final_answer, e.value]
        end

        # Resolve all pending futures in dependency order.
        def resolve_in_waves
          loop do
            pending = @batch.select(&:_pending?)
            return if pending.empty?

            ready = select_ready(pending)
            raise_circular_dependency!(pending) if ready.empty?

            execute_batch(ready)
          end
        end

        alias force_resolve resolve_in_waves

        # Select futures that are ready to resolve (all dependencies satisfied).
        def select_ready(pending)
          pending.select { |f| ready_to_resolve?(f) }
        end

        # A future is ready if all its args/kwargs are resolved (or not futures).
        def ready_to_resolve?(future) = all_resolved?(future.args) && all_resolved?(future.kwargs.values)

        def all_resolved?(values)
          values.all? { |v| !v.is_a?(ToolFuture) || v._resolved? }
        end

        def raise_circular_dependency!(pending)
          names = pending.map(&:tool_name).join(", ")
          ::Kernel.raise "Circular dependency detected in tool futures: #{names}"
        end

        # Execute a batch of ready futures via the tool port.
        def execute_batch(futures)
          requests = futures.map { |f| build_request(f) }
          @tool_port.send({ type: :batch, requests: })
          response = ::Ractor.receive
          resolve_futures(futures, response[:results])
        end

        def resolve_futures(futures, results)
          futures.zip(results).each { |future, result| apply_result(future, result) }
        end

        def apply_result(future, result)
          case result
          in { success: true, value: } then future._resolve!(value)
          in { success: false, error: } then future._reject!(error)
          in { final_answer: value } then resolve_final(future, value)
          end
        end

        def resolve_final(future, value)
          future._resolve!(value)
          raise Smolagents::Executors::FinalAnswerSignal, value
        end

        def build_request(future)
          { name: future.tool_name, args: unwrap_args(future.args), kwargs: unwrap_kwargs(future.kwargs) }
        end

        def unwrap_args(args)
          args.map { |a| a.is_a?(ToolFuture) && a._resolved? ? a._result : a }
        end

        def unwrap_kwargs(kwargs)
          kwargs.transform_values { |v| v.is_a?(ToolFuture) && v._resolved? ? v._result : v }
        end
      end
    end
  end
end
