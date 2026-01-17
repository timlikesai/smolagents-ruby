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
      # @!attribute [r] logger
      #   @return [Logger, nil] Optional logger for debugging API calls and performance metrics
      attr_accessor :logger

      # @!attribute [r] model_id
      #   @return [String] The model identifier (e.g., "gemma-3n-e4b-it-q8_0", "claude-opus-4-5-20251101")
      attr_reader :model_id

      # @!attribute [r] config
      #   @return [Types::ModelConfig, nil] The unified configuration object
      attr_reader :config

      # @!attribute [r] temperature
      #   @return [Float] The sampling temperature (default: 0.7)
      attr_reader :temperature

      # @!attribute [r] max_tokens
      #   @return [Integer, nil] Maximum tokens in response
      attr_reader :max_tokens

      # Creates a new model instance.
      #
      # Supports two initialization patterns:
      # 1. Config-based: Pass a ModelConfig object via the config: parameter
      # 2. Keyword-based: Pass individual parameters (model_id:, api_key:, etc.)
      #
      # @param model_id [String] The model identifier (provider-specific naming, e.g.,
      #   "gpt-4", "gemma-3n-e4b-it-q8_0", "claude-opus-4-5-20251101")
      # @param config [Types::ModelConfig, nil] Unified configuration object
      # @param api_key [String, nil] API key for authentication
      # @param api_base [String, nil] Custom API endpoint URL
      # @param temperature [Float] Sampling temperature (0.0-2.0, default: 0.7)
      # @param max_tokens [Integer, nil] Maximum tokens in response
      # @param kwargs [Hash] Additional provider-specific options
      #
      # @example Config-based initialization
      #   config = ModelConfig.create(model_id: "gpt-4", api_key: "sk-...")
      #   model = OpenAIModel.new(config:)
      #
      # @example Keyword-based initialization
      #   model = OpenAIModel.new(model_id: "gpt-4", api_key: "sk-...", temperature: 0.5)
      #
      # @see Types::ModelConfig
      # @see OpenAIModel#initialize
      # @see AnthropicModel#initialize
      def initialize(model_id: nil, config: nil, api_key: nil, api_base: nil,
                     temperature: 0.7, max_tokens: nil, **kwargs)
        if config
          init_from_config(config)
        else
          init_from_params(model_id, api_key, api_base, temperature, max_tokens, kwargs)
        end
        @logger = nil
      end

      def init_from_config(config)
        @config = config
        @model_id = config.model_id
        @api_key = config.api_key
        @api_base = config.api_base
        @temperature = config.temperature
        @max_tokens = config.max_tokens
        @kwargs = config.extras || {}
      end

      def init_from_params(model_id, api_key, api_base, temperature, max_tokens, kwargs)
        @config = nil
        @model_id = model_id
        @api_key = api_key
        @api_base = api_base
        @temperature = temperature
        @max_tokens = max_tokens
        @kwargs = kwargs
      end

      # Generates a response from the model given a sequence of messages.
      #
      # This is the primary method for interacting with the model. It accepts a list of
      # ChatMessage objects and returns a single ChatMessage response with optional
      # tool calls. Subclasses must implement this method to call their respective APIs.
      #
      # The method should handle:
      # - Formatting messages into provider-specific API format
      # - Making API calls with proper error handling
      # - Parsing responses and extracting tool calls if present
      # - Tracking token usage for billing and metrics
      #
      # @param _messages [Array<ChatMessage>] The conversation history, typically
      #   including system, user, assistant, and tool response messages
      # @param stop_sequences [Array<String>, nil] Sequences that should stop text
      #   generation (provider-specific support varies)
      # @param response_format [Hash, nil] Structured output format specification
      #   (provider-specific, e.g., { type: "json_object" } for OpenAI)
      # @param tools_to_call_from [Array<Tool>, nil] Available tools the model can
      #   call via function calling/tool use
      # @param _kwargs [Hash] Additional provider-specific options:
      #   - temperature [Float] Sampling temperature (0.0-2.0 range varies by provider)
      #   - max_tokens [Integer] Maximum tokens in the response
      #   - top_p [Float] Nucleus sampling parameter
      #   - frequency_penalty [Float] OpenAI-specific penalty
      #   - presence_penalty [Float] OpenAI-specific penalty
      #
      # @return [ChatMessage] The model's response as an assistant ChatMessage,
      #   potentially including tool_calls and token_usage metadata
      #
      # @raise [NotImplementedError] When called on the abstract base Model class
      # @raise [AgentGenerationError] When the API returns an error or request fails
      # @raise [Smolagents::GemLoadError] When required dependencies are missing
      #
      # @example Basic text generation
      #   messages = [ChatMessage.user("What is the capital of France?")]
      #   response = model.generate(messages)
      #   puts response.content  # "The capital of France is Paris."
      #
      # @example Function calling
      #   tools = [WeatherTool.new, LocationTool.new]
      #   messages = [ChatMessage.user("What's the weather in Tokyo?")]
      #   response = model.generate(messages, tools_to_call_from: tools)
      #   response.tool_calls.each do |call|
      #     puts "#{call.name}(#{call.arguments})"
      #   end
      #
      # @example With token usage tracking
      #   response = model.generate(messages)
      #   puts "Input tokens: #{response.token_usage&.input_tokens}"
      #   puts "Output tokens: #{response.token_usage&.output_tokens}"
      #
      # @see #generate_stream For streaming responses
      # @see ChatMessage for message structure
      # @see Tool for tool/function calling
      def generate(_messages, stop_sequences: nil, response_format: nil, tools_to_call_from: nil, **_kwargs)
        raise NotImplementedError, "#{self.class}#generate must be implemented"
      end

      # Generates a streaming response from the model.
      #
      # Returns an Enumerator that yields ChatMessage chunks as they arrive from the API.
      # This is useful for real-time display of model output and reducing perceived latency.
      #
      # The method should:
      # - Stream partial content chunks to the block as they arrive
      # - Handle streaming-specific API mechanics (e.g., SSE, line-delimited JSON)
      # - Parse streaming messages into ChatMessage objects
      # - Return an Enumerator if no block is provided for lazy evaluation
      #
      # @param messages [Array<ChatMessage>] The conversation history
      # @param kwargs [Hash] Additional provider-specific options (same as {#generate})
      # @option options [Float] :temperature Sampling temperature
      # @option options [Integer] :max_tokens Maximum tokens in response
      #
      # @yield [ChatMessage] Each chunk of the streaming response as a partial ChatMessage
      #   with content field containing the delta text
      #
      # @return [Enumerator<ChatMessage>] When no block given, returns an Enumerator for
      #   lazy evaluation and composition
      #
      # @raise [NotImplementedError] When called on the abstract base Model class
      # @raise [AgentGenerationError] When the streaming connection fails
      #
      # @example Streaming with a block
      #   model.generate_stream(messages) do |chunk|
      #     print chunk.content
      #   end
      #
      # @example Streaming as Enumerator
      #   stream = model.generate_stream(messages)
      #   tokens = stream.map(&:content).join
      #
      # @example Streaming with composition
      #   model.generate_stream(messages)
      #     .each_with_index { |chunk, i| puts "[#{i}] #{chunk.content}" }
      #
      # @see #generate For non-streaming generation
      # @see ChatMessage for message structure
      def generate_stream(messages, **)
        return enum_for(:generate_stream, messages, **) unless block_given?

        raise NotImplementedError, "#{self.class}#generate_stream must be implemented"
      end

      # Parses tool calls from a model response.
      #
      # This method is called internally after API responses to extract and normalize
      # tool calls. The default implementation returns the input as-is, but subclasses
      # can override to handle provider-specific tool call formats.
      #
      # @param message [Object] The raw tool call data from the model response.
      #   Format varies by provider:
      #   - OpenAI: Array of { id, type, function: { name, arguments } }
      #   - Anthropic: Array of { type: "tool_use", id, name, input }
      #
      # @return [Object] Parsed tool calls in normalized format. Returns nil or empty
      #   array if no tool calls present.
      #
      # @example Override in subclass
      #   class CustomModel < Model
      #     def parse_tool_calls(raw_calls)
      #       raw_calls.map { |c| ToolCall.new(id: c[:id], name: c[:fn], arguments: c[:args]) }
      #     end
      #   end
      #
      # @see OpenAIModel#parse_tool_calls
      # @see AnthropicModel for Anthropic-specific parsing
      def parse_tool_calls(message) = message

      # Alias for {#generate} enabling a callable interface.
      #
      # Allows the model to be used with Ruby's call syntax:
      #   response = model.(messages)
      #
      # This is useful when the model is passed as a callable object or Proc.
      #
      # @param messages [Array<ChatMessage>] Conversation history passed to {#generate}
      # @param options [Hash] All keyword arguments passed to {#generate}
      # @option options [Array<String>] :stop_sequences Sequences that stop generation
      # @option options [Array<Tool>] :tools_to_call_from Available tools
      #
      # @return [ChatMessage] Same as {#generate}
      #
      # @example Using model as callable
      #   processor = ->(m) { m.call(messages) }
      #   response = processor.call(model)
      #
      # @see #generate
      def call(*, **) = generate(*, **)

      # Validates that all required parameters are present.
      #
      # This helper method is used during initialization to ensure provider-specific
      # required parameters are supplied. Raises an ArgumentError with a descriptive
      # message listing missing parameters.
      #
      # @param required [Array<Symbol>] Required parameter names to check
      # @param kwargs [Hash] The provided parameters hash to validate
      #
      # @return [void]
      #
      # @raise [ArgumentError] When any required parameters are missing, with message
      #   format: "Missing required parameters: param1, param2"
      #
      # @example Usage in initializer
      #   def initialize(model_id:, api_key: nil, api_base: nil, **)
      #     validate_required_params([:api_key, :api_base], { api_key:, api_base: })
      #   end
      #
      # @see OpenAIModel#initialize
      # @see AnthropicModel#initialize
      def validate_required_params(required, kwargs)
        missing = required - kwargs.keys
        raise ArgumentError, "Missing required parameters: #{missing.join(", ")}" unless missing.empty?
      end
    end
  end
end
