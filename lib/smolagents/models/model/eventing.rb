module Smolagents
  module Models
    class Model
      # Event emission for model generation.
      #
      # Provides event emission around model generate calls for observability.
      # Models that include this can use `with_generate_events` to wrap
      # generation and emit ModelGenerateRequested/Completed events.
      #
      # @example Using in a model
      #   class MyModel < Model
      #     include Eventing
      #
      #     def generate(messages, **options)
      #       with_generate_events(messages, options) do
      #         # actual generation
      #       end
      #     end
      #   end
      #
      # @see Events::ModelGenerateRequested
      # @see Events::ModelGenerateCompleted
      module Eventing
        include Events::Emitter

        private

        # Wraps generation with event emission.
        #
        # @param messages [Array<ChatMessage>] Messages being sent
        # @param options [Hash] Generation options (may include :tools_to_call_from)
        # @yield Block performing actual generation
        # @return [ChatMessage] Result of the block
        def with_generate_events(messages, options = {}, &)
          return yield unless emitting?

          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          emit_generate_requested(messages, options)
          execute_with_completion_event(start_time, &)
        end

        def execute_with_completion_event(start_time)
          result = yield
          emit_generate_completed(start_time, result, :success)
          result
        rescue StandardError => e
          emit_generate_completed(start_time, nil, :error)
          raise e
        end

        def emit_generate_requested(messages, options)
          emit(Events::ModelGenerateRequested.create(
                 model_id:,
                 message_count: messages.size,
                 has_tools: !options[:tools_to_call_from].nil? && !options[:tools_to_call_from].empty?,
                 temperature: options[:temperature] || @temperature
               ))
        end

        def emit_generate_completed(start_time, result, outcome)
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).to_i
          token_usage = result.respond_to?(:token_usage) ? result.token_usage&.to_h : nil
          has_tool_calls = result.respond_to?(:tool_calls) && result.tool_calls&.any?

          emit(Events::ModelGenerateCompleted.create(
                 model_id:,
                 duration_ms:,
                 token_usage:,
                 has_tool_calls:,
                 outcome:
               ))
        end
      end
    end
  end
end
