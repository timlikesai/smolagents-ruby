module Smolagents
  module Builders
    # Simple setter methods for ModelBuilder.
    #
    # Provides chainable configuration methods for model parameters like ID,
    # API key, temperature, timeout, and max tokens. Each method returns a
    # new builder instance for immutable chaining.
    #
    # @see ModelBuilder The main builder class
    module ModelBuilderSetters
      # Set the model ID/name.
      #
      # @param model_id [String] The model identifier (e.g., "gpt-4", "claude-3-opus")
      # @return [ModelBuilder] New builder with model ID set
      #
      # @example Setting model ID
      #   builder = Smolagents.model(:openai).id("gpt-4-turbo")
      #   builder.config[:model_id]
      #   #=> "gpt-4-turbo"
      def id(model_id)
        check_frozen!
        validate!(:id, model_id)
        with_config(model_id:)
      end

      # Set the API authentication key.
      #
      # @param key [String] API key for authentication
      # @return [ModelBuilder] New builder with API key set
      #
      # @example Setting API key
      #   builder = Smolagents.model(:openai).api_key("sk-test-key")
      #   builder.config[:api_key]
      #   #=> "sk-test-key"
      def api_key(key)
        check_frozen!
        validate!(:api_key, key)
        with_config(api_key: key)
      end

      # Set the API base URL.
      #
      # @param url [String] Base URL for API requests
      # @return [ModelBuilder] New builder with endpoint set
      #
      # @example Setting custom endpoint
      #   builder = Smolagents.model(:openai).endpoint("https://my-proxy.example.com/v1")
      #   builder.config[:api_base]
      #   #=> "https://my-proxy.example.com/v1"
      def endpoint(url) = with_config(api_base: url)

      # Set the sampling temperature.
      #
      # Higher values (e.g., 1.5) increase creativity/randomness.
      # Lower values (e.g., 0.2) make output more deterministic.
      #
      # @param temp [Float] Temperature value (0.0-2.0)
      # @return [ModelBuilder] New builder with temperature set
      #
      # @example Setting temperature
      #   builder = Smolagents.model(:openai).temperature(0.7)
      #   builder.config[:temperature]
      #   #=> 0.7
      def temperature(temp)
        check_frozen!
        validate!(:temperature, temp)
        with_config(temperature: temp)
      end

      # Set the request timeout in seconds.
      #
      # @param seconds [Integer] Timeout in seconds (1-600)
      # @return [ModelBuilder] New builder with timeout set
      #
      # @example Setting timeout
      #   builder = Smolagents.model(:openai).timeout(30)
      #   builder.config[:timeout]
      #   #=> 30
      def timeout(seconds)
        check_frozen!
        validate!(:timeout, seconds)
        with_config(timeout: seconds)
      end

      # Set the maximum tokens in the response.
      #
      # @param tokens [Integer] Maximum tokens (1-100000)
      # @return [ModelBuilder] New builder with max tokens set
      #
      # @example Setting max tokens
      #   builder = Smolagents.model(:openai).max_tokens(4096)
      #   builder.config[:max_tokens]
      #   #=> 4096
      def max_tokens(tokens)
        check_frozen!
        validate!(:max_tokens, tokens)
        with_config(max_tokens: tokens)
      end

      # Configure the model for a specific host and port.
      #
      # Useful for custom deployments or non-standard port configurations.
      #
      # @param host [String] Hostname or IP address
      # @param port [Integer] Port number
      # @return [ModelBuilder] New builder with host/port configured
      #
      # @example Configuring custom host/port
      #   builder = Smolagents.model(:lm_studio).at(host: "192.168.1.100", port: 8080)
      #   builder.config[:api_base]
      #   #=> "http://192.168.1.100:8080/v1"
      def at(host:, port:)
        type = configuration[:type]
        base_path = type == :ollama ? "/api/v1" : "/v1"
        with_config(api_base: "http://#{host}:#{port}#{base_path}", api_key: "not-needed")
      end
    end
  end
end
