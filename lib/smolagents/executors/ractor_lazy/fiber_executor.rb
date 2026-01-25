require_relative "../final_answer_signal"

module Smolagents
  module Executors
    module RactorLazy
      # Executes code in a Fiber, handling batch yields.
      class FiberExecutor
        include FutureResolution
        include BatchHandling

        # rubocop:disable Metrics/ParameterLists -- mirrors Context.build parameters
        def initialize(ctx, output, batch, tool_port, result_port, max_ops)
          # rubocop:enable Metrics/ParameterLists
          @ctx = ctx
          @output = output
          @batch = batch
          @tool_port = tool_port
          @result_port = result_port
          @max_ops = max_ops
        end

        def execute(code)
          reset_output
          @batch.clear
          run_fiber(create_fiber(code))
        end

        private

        def reset_output = @output.truncate(0) && @output.rewind

        def create_fiber(code)
          ctx = @ctx
          max_ops = @max_ops
          Fiber.new do
            execute_with_tracing(ctx, code, max_ops)
          rescue StandardError => e
            # Catch TracePoint exceptions (e.g., operation limit exceeded)
            { type: :error, error: "#{e.class}: #{e.message}" }
          end
        end

        def execute_with_tracing(ctx, code, max_ops)
          ops = 0
          trace = TracePoint.new(:line) { (ops += 1) > max_ops && raise("Operation limit exceeded") }
          trace.enable
          run_code(ctx, code)
        ensure
          trace.disable
        end

        def run_code(ctx, code)
          { type: :result, value: ctx.instance_eval(code) }
        rescue FinalAnswerSignal => e
          { type: :final_answer, value: e.value }
        rescue StandardError => e
          { type: :error, error: "#{e.class}: #{e.message}" }
        end

        def run_fiber(fiber)
          loop { break unless process_fiber_result(fiber.resume) }
        end

        # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def process_fiber_result(result)
          case result
          in { type: :batch, futures: }
            batch_result = handle_batch(futures)
            # handle_batch returns [:final_answer, value] if final_answer was called in batch
            batch_result ? (send_final(batch_result.last) && false) : true
          in { type: :result, value: } then resolve_and_send(:result, value) && false
          in { type: :final_answer, value: } then resolve_and_send(:final, value) && false
          in { type: :error, error: } then send_error(error) && false
          end
        end
        # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        def resolve_and_send(type, value)
          resolve_all_pending(value)
          type == :final ? send_final(value) : send_result(value)
        rescue FinalAnswerSignal => e
          send_final(e.value)
        rescue StandardError => e
          send_error("#{e.class}: #{e.message}")
        end

        def send_result(value)
          @result_port.send({ success: true, result: unwrap_future(value), logs: @output.string, is_final: false })
        end

        def send_final(value)
          @result_port.send({ success: true, result: unwrap_future(value), logs: @output.string, is_final: true })
        end

        def send_error(error)
          @result_port.send({ success: false, error:, logs: @output.string })
        end
      end
    end
  end
end
