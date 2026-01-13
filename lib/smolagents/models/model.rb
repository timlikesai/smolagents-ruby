module Smolagents
  module Models
    # Abstract base class for all LLM model implementations.
    #
    # Model provides the interface contract for generating text responses from
    # language models. Concrete implementations (OpenAIModel, AnthropicModel,
    # LiteLLMModel) handle provider-specific API interactions.
    #
    # All models support:
    # - Message-based chat completion
    # - Optional streaming responses
    # - Tool/function calling
    # - Token usage tracking
    #
    # @example Subclassing Model
    #   class MyCustomModel < Model
    #     def generate(messages, **options)
    #       # Call your API here
    #       ChatMessage.assistant(response_text)
    #     end
    #   end
    #
    # @example Using with ModelBuilder DSL (local model)
    #   model = Smolagents.model(:lm_studio)
    #     .id("gemma-3n-e4b-it-q8_0")
    #     .temperature(0.7)
    #     .build
    #
    # @example Using with cloud provider
    #   model = Smolagents.model(:anthropic)
    #     .id("claude-sonnet-4-5-20251101")
    #     .api_key(ENV["ANTHROPIC_API_KEY"])
    #     .build
    #
    # @abstract Subclass and implement {#generate} to create a custom model.
    # @see OpenAIModel For OpenAI-compatible APIs (including local servers)
    # @see AnthropicModel For Anthropic Claude 4.5 APIs
    # @see LiteLLMModel For multi-provider support
    class Model
      # @return [Logger, nil] Optional logger for debugging API calls
      attr_accessor :logger

      # @return [String] The model identifier (e.g., "gemma-3n-e4b-it-q8_0", "claude-opus-4-5-20251101")
      attr_reader :model_id

      # Creates a new model instance.
      #
      # @param model_id [String] The model identifier
      # @param kwargs [Hash] Additional provider-specific options
      def initialize(model_id:, **kwargs)
        @model_id = model_id
        @kwargs = kwargs
        @logger = nil
      end

      # Generates a response from the model given a sequence of messages.
      #
      # This is the primary method for interacting with the model. Subclasses
      # must implement this method to call their respective APIs.
      #
      # @param messages [Array<ChatMessage>] The conversation history
      # @param stop_sequences [Array<String>, nil] Sequences that stop generation
      # @param response_format [Hash, nil] Structured output format (provider-specific)
      # @param tools_to_call_from [Array<Tool>, nil] Available tools for function calling
      # @param kwargs [Hash] Additional provider-specific options
      # @return [ChatMessage] The model's response as an assistant message
      # @raise [NotImplementedError] When called on the abstract base class
      # @raise [AgentGenerationError] When the API call fails
      def generate(_messages, stop_sequences: nil, response_format: nil, tools_to_call_from: nil, **_kwargs)
        raise NotImplementedError, "#{self.class}#generate must be implemented"
      end

      # Generates a streaming response from the model.
      #
      # Returns an Enumerator that yields ChatMessage chunks as they arrive.
      # Useful for real-time display of model output.
      #
      # @param messages [Array<ChatMessage>] The conversation history
      # @param kwargs [Hash] Additional provider-specific options
      # @yield [ChatMessage] Each chunk of the response as it streams
      # @return [Enumerator<ChatMessage>] When no block given
      # @raise [NotImplementedError] When called on the abstract base class
      def generate_stream(messages, **)
        return enum_for(:generate_stream, messages, **) unless block_given?

        raise NotImplementedError, "#{self.class}#generate_stream must be implemented"
      end

      # Parses tool calls from a model response.
      #
      # @param message [Object] The raw tool call data from the model
      # @return [Object] Parsed tool calls (default: pass-through)
      def parse_tool_calls(message) = message

      # Alias for {#generate} for callable interface.
      #
      # @see #generate
      def call(*, **) = generate(*, **)

      # Validates that all required parameters are present.
      #
      # @param required [Array<Symbol>] Required parameter names
      # @param kwargs [Hash] Provided parameters
      # @raise [ArgumentError] When required parameters are missing
      def validate_required_params(required, kwargs)
        missing = required - kwargs.keys
        raise ArgumentError, "Missing required parameters: #{missing.join(", ")}" unless missing.empty?
      end
    end
  end
end
