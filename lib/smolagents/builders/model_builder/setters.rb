module Smolagents
  module Builders
    # Simple setter methods for ModelBuilder.
    #
    # Extracted to keep the main builder focused on structure.
    module ModelBuilderSetters
      # Set the model ID.
      # @param model_id [String]
      # @return [ModelBuilder]
      def id(model_id)
        check_frozen!
        validate!(:id, model_id)
        with_config(model_id:)
      end

      # Set the API key.
      # @param key [String]
      # @return [ModelBuilder]
      def api_key(key)
        check_frozen!
        validate!(:api_key, key)
        with_config(api_key: key)
      end

      # Set the API base URL.
      # @param url [String]
      # @return [ModelBuilder]
      def endpoint(url) = with_config(api_base: url)

      # Set the temperature.
      # @param temp [Float]
      # @return [ModelBuilder]
      def temperature(temp)
        check_frozen!
        validate!(:temperature, temp)
        with_config(temperature: temp)
      end

      # Set the request timeout.
      # @param seconds [Integer]
      # @return [ModelBuilder]
      def timeout(seconds)
        check_frozen!
        validate!(:timeout, seconds)
        with_config(timeout: seconds)
      end

      # Set max tokens.
      # @param tokens [Integer]
      # @return [ModelBuilder]
      def max_tokens(tokens)
        check_frozen!
        validate!(:max_tokens, tokens)
        with_config(max_tokens: tokens)
      end

      # Configure for a specific host/port.
      # @param host [String]
      # @param port [Integer]
      # @return [ModelBuilder]
      def at(host:, port:)
        type = configuration[:type]
        base_path = type == :ollama ? "/api/v1" : "/v1"
        with_config(api_base: "http://#{host}:#{port}#{base_path}", api_key: "not-needed")
      end
    end
  end
end
