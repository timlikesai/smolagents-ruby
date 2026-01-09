# frozen_string_literal: true

module Smolagents
  # Base class for model implementations.
  # Models are responsible for generating text and handling tool calls.
  #
  # Subclasses should implement:
  # - #generate(messages, **kwargs) -> ChatMessage
  # - Optionally: #generate_stream(messages, **kwargs) { |delta| }
  #
  # @example Creating a custom model
  #   class MyModel < Model
  #     include Concerns::Retryable
  #
  #     def generate(messages, **kwargs)
  #       with_retry do
  #         # Call your API
  #       end
  #     end
  #   end
  #
  # @example Using a model
  #   model = OpenAIModel.new(model_id: "gpt-4")
  #   response = model.generate([
  #     ChatMessage.system("You are a helpful assistant"),
  #     ChatMessage.user("Hello!")
  #   ])
  class Model
    attr_reader :model_id

    # Initialize a model.
    #
    # @param model_id [String] model identifier (e.g., "gpt-4", "claude-3-opus")
    # @param kwargs [Hash] additional model configuration
    def initialize(model_id:, **kwargs)
      @model_id = model_id
      @kwargs = kwargs
    end

    # Generate a response from the model.
    #
    # @param messages [Array<ChatMessage>] conversation history
    # @param stop_sequences [Array<String>, nil] sequences that stop generation
    # @param response_format [Hash, nil] structured output format
    # @param tools_to_call_from [Array<Tool>, nil] tools available for calling
    # @param kwargs [Hash] additional generation parameters
    # @return [ChatMessage] model response
    # @raise [NotImplementedError] if not implemented by subclass
    def generate(messages, stop_sequences: nil, response_format: nil, tools_to_call_from: nil, **kwargs)
      raise NotImplementedError, "#{self.class}#generate must be implemented"
    end

    # Stream responses from the model.
    # Returns an Enumerator if no block given, yields ChatMessage deltas if block given.
    #
    # @param messages [Array<ChatMessage>] conversation history
    # @param kwargs [Hash] generation parameters
    # @yield [delta] each response chunk
    # @yieldparam delta [ChatMessage] partial response
    # @return [Enumerator, nil] enumerator if no block, nil if block given
    def generate_stream(messages, **kwargs)
      return enum_for(:generate_stream, messages, **kwargs) unless block_given?

      raise NotImplementedError, "#{self.class}#generate_stream must be implemented"
    end

    # Parse tool calls from a message (override if provider has custom format).
    #
    # @param message [ChatMessage] message to parse
    # @return [ChatMessage] message with parsed tool calls
    def parse_tool_calls(message)
      message
    end

    # Alias for generate (some APIs use "call").
    #
    # @see #generate
    def call(*args, **kwargs)
      generate(*args, **kwargs)
    end

    # Validate that required parameters are present.
    #
    # @param required [Array<Symbol>] required parameter names
    # @param kwargs [Hash] parameters to validate
    # @raise [ArgumentError] if required parameters missing
    def validate_required_params(required, kwargs)
      missing = required - kwargs.keys
      return if missing.empty?

      raise ArgumentError, "Missing required parameters: #{missing.join(', ')}"
    end

    # Get logger if available.
    #
    # @return [Logger, nil]
    def logger
      @logger if defined?(@logger)
    end

    # Set logger for model.
    #
    # @param logger [Logger]
    def logger=(logger)
      @logger = logger
    end
  end
end
