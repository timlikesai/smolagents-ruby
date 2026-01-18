module Smolagents
  module Testing
    module Helpers
      # Model-related test helper methods.
      #
      # Provides convenience methods for creating mock models in tests.
      # @see MockModel The underlying mock model class
      module ModelHelpers
        # Creates a MockModel for a single-step agent test.
        #
        # @param answer [String] The final answer the agent should return
        # @return [MockModel] Configured model ready for use
        def mock_model_for_single_step(answer)
          MockModel.new.queue_final_answer(answer)
        end

        # Creates a MockModel with optional block configuration.
        #
        # @yield [MockModel] Optional block to configure the model
        # @return [MockModel] Configured model ready for use
        #
        # @example Basic usage
        #   let(:model) { mock_model { |m| m.queue_final_answer("42") } }
        def mock_model(&block)
          MockModel.new.tap { |m| block&.call(m) }
        end

        # Creates a MockModel for testing agents with planning.
        #
        # @param plan [String] The planning text
        # @param answer [String] The final answer
        # @return [MockModel] Configured model ready for use
        def mock_model_with_planning(plan:, answer:)
          MockModel.new
                   .queue_planning_response(plan)
                   .queue_final_answer(answer)
        end

        # Creates a MockModel for multi-step agent tests.
        #
        # @param steps [Array<String, Hash>] Steps to queue in order
        # @return [MockModel] Configured model ready for use
        # @see MultiStepBuilder For step format details
        def mock_model_for_multi_step(steps)
          MultiStepBuilder.build(steps)
        end

        # Creates a simple double that responds with a specific response.
        #
        # @param response [String, ChatMessage] The response to return
        # @param tool_calls [Array<Hash>, nil] Tool calls to include in response
        # @return [Object] A double that responds to generate
        def mock_model_that_responds(response, tool_calls: nil)
          message = build_response_message(response, tool_calls)
          instance_double(Models::Model, generate: message, model_id: "mock-model")
        end

        # Creates a mock streaming model for testing streaming responses.
        #
        # @param responses [Array<String>] Responses to stream
        # @return [Object] A double that responds to generate_stream
        def mock_streaming_model(*responses)
          instance_double(Models::Model).tap do |m|
            allow(m).to receive(:generate_stream) { |&block|
              responses.flatten.each { |r| block.call(Types::ChatMessage.assistant(r)) }
            }
          end
        end

        private

        def build_response_message(response, tool_calls)
          return response if response.is_a?(Types::ChatMessage)
          return Types::ChatMessage.assistant(response) unless tool_calls

          calls = tool_calls.map { |tc| Types::ToolCall.new(**tc) }
          Types::ChatMessage.assistant(response, tool_calls: calls)
        end
      end
    end
  end
end
