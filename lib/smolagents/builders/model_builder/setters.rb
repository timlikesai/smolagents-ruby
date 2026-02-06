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
      SETTER_CONFIG = {
        id: { key: :model_id }, api_key: {}, endpoint: { key: :api_base },
        temperature: {}, timeout: {}, max_tokens: {}, server_capabilities: {}
      }.freeze

      def self.included(base)
        base.extend(Support::ValidatedSetter)
        base.validated_setters(**SETTER_CONFIG)
        base.alias_method :base_url, :endpoint
      end

      # Configure the model for a specific host and port.
      #
      # @param host [String] Hostname or IP address
      # @param port [Integer] Port number
      # @return [ModelBuilder] New builder with host/port configured
      def at(host:, port:)
        check_frozen!
        type = configuration[:type]
        base_path = type == :ollama ? "/api/v1" : "/v1"
        with_config(api_base: "http://#{host}:#{port}#{base_path}", api_key: "not-needed")
      end

      # Set server type for capability auto-detection.
      #
      # @param type [Symbol] Server type (:llama_cpp, :lm_studio, :mlx_lm, :ollama, :vllm, :openai)
      # @return [ModelBuilder] New builder with server type set
      def server_type(type)
        check_frozen!
        server_type_obj = Types::ServerType.lookup(type)
        raise ArgumentError, "Unknown server type: #{type}" unless server_type_obj

        caps = Types::ServerCapability.from_server_type(server_type_obj)
        with_config(server_capabilities: caps)
      end
    end
  end
end
