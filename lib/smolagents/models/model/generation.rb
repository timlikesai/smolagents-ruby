module Smolagents
  module Models
    class Model
      # Core generation interface for Model instances.
      #
      # Provides the abstract generation methods that subclasses must implement
      # to interact with their respective LLM APIs.
      module Generation
        # Generates a response from the model given a sequence of messages.
        #
        # @param _messages [Array<ChatMessage>] The conversation history
        # @param stop_sequences [Array<String>, nil] Sequences that stop generation
        # @param response_format [Hash, nil] Structured output format specification
        # @param tools_to_call_from [Array<Tool>, nil] Available tools for function calling
        # @param _kwargs [Hash] Additional provider-specific options
        #
        # @return [ChatMessage] The model's response as an assistant ChatMessage
        #
        # @raise [NotImplementedError] When called on the abstract base Model class
        def generate(_messages, stop_sequences: nil, response_format: nil, tools_to_call_from: nil, **_kwargs)
          raise NotImplementedError, "#{self.class}#generate must be implemented"
        end

        # Generates a streaming response from the model.
        #
        # Returns an Enumerator that yields ChatMessage chunks as they arrive.
        #
        # @param messages [Array<ChatMessage>] The conversation history
        # @param kwargs [Hash] Additional provider-specific options
        #
        # @yield [ChatMessage] Each chunk of the streaming response
        # @return [Enumerator<ChatMessage>] When no block given
        #
        # @raise [NotImplementedError] When called on the abstract base Model class
        def generate_stream(messages, **)
          return enum_for(:generate_stream, messages, **) unless block_given?

          raise NotImplementedError, "#{self.class}#generate_stream must be implemented"
        end
      end
    end
  end
end
