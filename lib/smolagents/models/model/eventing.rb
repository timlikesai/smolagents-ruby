module Smolagents
  module Models
    class Model
      # Event emission for model generation.
      #
      # Provides event emission around model generate calls for observability.
      # Models that include this can use `with_generate_events` to wrap
      # generation and emit ModelGeneration events.
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
      # @see Events::ModelGeneration
      # @see Events::ModelGeneration
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
          emit_tool_calls_parsed(result)
          emit_generate_completed(start_time, result, :success)
          result
        rescue StandardError => e
          emit_generate_completed(start_time, nil, :error)
          raise e
        end

        def emit_tool_calls_parsed(result)
          tool_calls = extract_tool_calls(result)
          return if tool_calls.empty?

          tool_calls.each { |call| emit_single_tool_call_parsed(call) }
        end

        def extract_tool_calls(result)
          return [] unless result.respond_to?(:tool_calls)

          result.tool_calls.to_a
        end

        def emit_single_tool_call_parsed(call)
          emit(Events::ToolCallParsed.create(
                 model_id:,
                 tool_name: call.name,
                 arguments: freeze_arguments(call.arguments),
                 call_id: call.id
               ))
        end

        def freeze_arguments(args)
          args&.dup&.freeze || {}
        end

        def emit_generate_requested(messages, options)
          emit(Events::ModelGeneration.create(
                 phase: :requested,
                 model_id:,
                 message_count: messages.size,
                 has_tools: !options[:tools_to_call_from].nil? && !options[:tools_to_call_from].empty?,
                 temperature: options[:temperature] || @temperature
               ))
        end

        def emit_generate_completed(start_time, result, outcome)
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).to_i
          token_usage = extract_token_usage(result)
          has_tool_calls = result.respond_to?(:tool_calls) && result.tool_calls.to_a.any?

          emit(Events::ModelGeneration.create(
                 phase: :completed, model_id:, duration_ms:,
                 token_usage:, has_tool_calls:, outcome:
               ))
        end

        def extract_token_usage(result)
          result.respond_to?(:token_usage) ? result.token_usage&.to_h : nil
        end
      end
    end
  end
end
