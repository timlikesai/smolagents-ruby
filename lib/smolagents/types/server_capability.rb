module Smolagents
  module Types
    # Server type classification with base capability assumptions.
    #
    # Different inference servers (llama.cpp, MLX, LM Studio, etc.) support
    # different subsets of the OpenAI API. This type captures those defaults.
    #
    # @example Get capabilities for a server type
    #   type = ServerType.lookup(:llama_cpp)
    #   type.base_capabilities[:tools]  # => true
    #
    # @see ServerCapability For runtime capability state
    ServerType = Data.define(:name, :base_capabilities)

    # Server type registry - predefined server configurations
    #
    # Capability keys:
    # - tools: Function calling support
    # - json_object: response_format { type: "json_object" } support
    # - json_schema: response_format { type: "json_schema" } support
    # - stop_array: Array of stop sequences (vs single string only)
    #
    # Research sources:
    # - LM Studio: https://lmstudio.ai/docs/developer/openai-compat
    # - MLX LM: https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/SERVER.md
    # - llama.cpp: https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
    module ServerTypes
      # llama.cpp server - full OpenAI compatibility (with --jinja flag for tools)
      LLAMA_CPP = ServerType.new(
        name: :llama_cpp,
        base_capabilities: {
          tools: true,          # Requires --jinja flag
          json_object: true,    # Fully supported
          json_schema: true,    # Fully supported
          stop_array: true
        }.freeze
      )

      # MLX LM server - OpenAI-similar but NOT fully compatible
      # Tools: model-dependent (PR #217, June 2025)
      # response_format: NOT supported at all
      MLX_LM = ServerType.new(
        name: :mlx_lm,
        base_capabilities: {
          tools: :model_dependent,
          json_object: false,
          json_schema: false,
          stop_array: true
        }.freeze
      )

      # LM Studio - full tools support, partial json mode
      # CRITICAL: json_object returns 400 error, only json_schema works
      LM_STUDIO = ServerType.new(
        name: :lm_studio,
        base_capabilities: {
          tools: true,
          json_object: false,   # 400 error: "must be 'json_schema' or 'text'"
          json_schema: true,    # Requires full schema definition
          stop_array: true
        }.freeze
      )

      # Ollama - full support
      OLLAMA = ServerType.new(
        name: :ollama,
        base_capabilities: {
          tools: true,
          json_object: true,
          json_schema: true,
          stop_array: true
        }.freeze
      )

      # vLLM - full OpenAI compatibility
      VLLM = ServerType.new(
        name: :vllm,
        base_capabilities: {
          tools: true,
          json_object: true,
          json_schema: true,
          stop_array: true
        }.freeze
      )

      # Standard OpenAI API
      OPENAI = ServerType.new(
        name: :openai,
        base_capabilities: {
          tools: true,
          json_object: true,
          json_schema: true,
          stop_array: true
        }.freeze
      )

      REGISTRY = {
        llama_cpp: LLAMA_CPP,
        mlx_lm: MLX_LM,
        lm_studio: LM_STUDIO,
        ollama: OLLAMA,
        vllm: VLLM,
        openai: OPENAI
      }.freeze
    end

    # Add class methods to ServerType
    class << ServerType
      # Lookup by name.
      #
      # @param name [Symbol] Server type name
      # @return [ServerType, nil]
      def lookup(name)
        ServerTypes::REGISTRY[name]
      end

      # Infer server type from URL patterns.
      #
      # @param url [String] Base URL
      # @return [ServerType]
      def infer_from_url(url)
        case url.to_s.downcase
        when /llama-cpp|llama\.cpp/i then ServerTypes::LLAMA_CPP
        when /lmstudio|lm-studio|:1234/i then ServerTypes::LM_STUDIO
        when /ollama|:11434/i then ServerTypes::OLLAMA
        when /vllm/i then ServerTypes::VLLM
        when /mlx/i then ServerTypes::MLX_LM
        else ServerTypes::OPENAI
        end
      end
    end

    # Runtime capability state for an endpoint.
    #
    # Tracks both base capabilities (from server type) and learned capabilities
    # (discovered through runtime errors). Capabilities can be updated when
    # we learn that a server doesn't support something we expected.
    #
    # @example Check if server supports tools
    #   cap = ServerCapability.from_server_type(ServerType.lookup(:llama_cpp))
    #   cap.supports_tools  # => true
    #
    # @example Check JSON mode support
    #   cap = ServerCapability.from_server_type(ServerType.lookup(:lm_studio))
    #   cap.supports_json_object  # => false (LM Studio returns 400)
    #   cap.supports_json_schema  # => true (requires full schema)
    #
    # @example Learn from runtime error
    #   cap = cap.with_learned(:supports_json_object, false)
    #
    # @see ServerType For base capability definitions
    ServerCapability = Data.define(
      :server_type,
      :supports_tools,
      :supports_json_object,  # response_format: { type: "json_object" }
      :supports_json_schema,  # response_format: { type: "json_schema", json_schema: {...} }
      :supports_stop_array,
      :max_tokens_limit,
      :detected_at,
      :confidence
    )

    # Add class and instance methods to ServerCapability
    class << ServerCapability
      # Build capability state from a server type's defaults.
      #
      # @param type [ServerType] Server type to use
      # @return [ServerCapability]
      # rubocop:disable Metrics/MethodLength -- initializing Data.define with all fields
      def from_server_type(type)
        caps = type.base_capabilities
        new(
          server_type: type,
          supports_tools: caps[:tools],
          supports_json_object: caps[:json_object],
          supports_json_schema: caps[:json_schema],
          supports_stop_array: caps[:stop_array],
          max_tokens_limit: nil,
          detected_at: Time.now,
          confidence: :base
        )
      end
      # rubocop:enable Metrics/MethodLength

      # Build capability state from a URL (infers server type).
      #
      # @param url [String] Base URL
      # @return [ServerCapability]
      def from_url(url) = from_server_type(ServerType.infer_from_url(url))
    end

    # Instance methods for ServerCapability
    ServerCapability.define_method(:with_learned) do |capability, value|
      with(
        capability => value,
        detected_at: Time.now,
        confidence: :learned
      )
    end

    ServerCapability.define_method(:learned?) { confidence == :learned }
    ServerCapability.define_method(:base?) { confidence == :base }
  end
end
