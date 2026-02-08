module Smolagents
  module Concerns
    module ReActLoop
      module Execution
        # Token-level streaming support for agent generation.
        #
        # When enabled, uses +generate_stream+ instead of +generate+
        # and emits +ModelTokenGenerated+ events during generation.
        # Supports +run(stream: :tokens)+ mode for real-time output.
        #
        # @example
        #   agent = Smolagents.agent.model { m }.build
        #   agent.run("task", stream: :tokens) do |event|
        #     print event.token
        #   end
        module Streaming
          private

          # Whether token streaming is enabled for this run.
          # @return [Boolean]
          def token_streaming? = @stream_tokens == true

          # Enable token streaming for the current run.
          # @return [void]
          def enable_token_streaming!
            @stream_tokens = true
          end

          # Disable token streaming.
          # @return [void]
          def disable_token_streaming!
            @stream_tokens = false
          end

          # Generate with streaming, emitting token events.
          #
          # @param messages [Array<ChatMessage>] Messages for model
          # @param tools [Array] Tool definitions
          # @return [ChatMessage] Complete response
          def generate_with_streaming(messages, tools:)
            return with_generation_timeout(context: :step) { @model.generate(messages, tools:) } unless streamable?

            stream_and_accumulate(messages, tools:)
          end

          def streamable? = token_streaming? && @model.respond_to?(:generate_stream)

          def stream_and_accumulate(messages, tools:)
            accumulated = +""
            step_num = @ctx&.step_number || 0
            @model.generate_stream(messages, tools:).each do |chunk|
              emit_token_if_present(chunk, accumulated, step_num)
            end
            accumulated
          end

          def emit_token_if_present(chunk, accumulated, step_num)
            token = chunk.respond_to?(:content) ? chunk.content : chunk.to_s
            return if token.nil? || token.empty?

            accumulated << token
            emit :model_token_generated, token:, step_number: step_num,
                                         accumulated_content: accumulated.dup
          end
        end
      end
    end
  end
end
