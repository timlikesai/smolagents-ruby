module Smolagents
  module Types
    # Server type classification with base capability assumptions.
    #
    # Different inference servers (llama.cpp, MLX, LM Studio, etc.) support
    # different subsets of the OpenAI API. This type captures those defaults.
    #
    # Capability keys:
    # - tools: Function calling support (true, false, or :model_dependent)
    # - json_object: response_format { type: "json_object" } support
    # - json_schema: response_format { type: "json_schema" } support
    # - stop_array: Array of stop sequences (vs single string only)
    # - tools_response_format_conflict: CRITICAL - cannot use tools AND response_format together
    # - supports_capability_query: Server's /v1/models endpoint returns capability info
    #
    # @example Get capabilities for a server type
    #   type = ServerType.lookup(:llama_cpp)
    #   type.base_capabilities[:tools]  # => true
    #
    # @example Get resilience defaults
    #   type = ServerType.lookup(:llama_cpp)
    #   type.resilience_defaults[:retry][:max_attempts]  # => 5
    #
    # @see ServerCapability For runtime capability state
    ServerType = Data.define(:name, :base_capabilities, :resilience_defaults)

    # Server type registry - predefined server configurations.
    #
    # Research sources:
    # - LM Studio: https://lmstudio.ai/docs/developer/openai-compat
    # - MLX LM: https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/SERVER.md
    # - llama.cpp: https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
    #
    # See ServerType for capability key documentation.
    module ServerTypes
      # llama.cpp server - CRITICAL: Cannot use tools AND response_format together!
      #
      # With --jinja flag: Tools work, response_format fails with grammar conflict error
      # Without --jinja flag: response_format works, tools return "requires --jinja" error
      #
      # For agents, prefer tools over response_format (drop response_format if both requested).
      # See: docs/references/llama_cpp_api.md, GitHub Issue #11847
      LLAMA_CPP = ServerType.new(
        name: :llama_cpp,
        base_capabilities: {
          tools: true,                            # Requires --jinja flag
          json_object: true,                      # Works WITHOUT --jinja
          json_schema: true,                      # Works WITHOUT --jinja
          stop_array: true,
          tools_response_format_conflict: true,   # CRITICAL: Cannot use both
          supports_capability_query: false        # /v1/models doesn't include capabilities
        }.freeze,
        resilience_defaults: {
          retry: { max_attempts: 5, base_interval: 2.0, max_interval: 60.0 },
          circuit_breaker: { threshold: 10, cool_off: 60 }
        }.freeze
      )

      # MLX LM server (standalone mlx-lm package, NOT LM Studio)
      #
      # This is for the standalone `mlx_lm.server` Python package, not LM Studio.
      # LM Studio has its own MLX engine with different capabilities.
      #
      # Tools: model-dependent (PR #217, June 2025)
      # response_format: NOT supported at all
      MLX_LM = ServerType.new(
        name: :mlx_lm,
        base_capabilities: {
          tools: :model_dependent,
          json_object: false,
          json_schema: false,
          stop_array: true,
          tools_response_format_conflict: false, # N/A - response_format not supported anyway
          supports_capability_query: false
        }.freeze,
        resilience_defaults: {}
      )

      # LM Studio - supports both GGUF (llama.cpp) and MLX models
      #
      # Has programmatic capability detection via /v1/models endpoint.
      # Each model returns capabilities array: ["chat", "tool_use", "structured_output"]
      #
      # CRITICAL: json_object returns 400 error, only json_schema works
      # Tools and response_format CAN be used together (unlike llama.cpp)
      # See: docs/references/lm_studio_api.md
      LM_STUDIO = ServerType.new(
        name: :lm_studio,
        base_capabilities: {
          tools: :model_dependent,                # Native: Qwen 2.5, Llama 3.x, Mistral; fallback: others
          json_object: false,                     # 400 error: "must be 'json_schema' or 'text'"
          json_schema: true,                      # Requires full schema, uses grammar/Outlines
          stop_array: true,
          tools_response_format_conflict: false,  # CAN use both together
          supports_capability_query: true         # /v1/models returns capabilities array
        }.freeze,
        resilience_defaults: {}
      )

      # Ollama - full support
      OLLAMA = ServerType.new(
        name: :ollama,
        base_capabilities: {
          tools: true,
          json_object: true,
          json_schema: true,
          stop_array: true,
          tools_response_format_conflict: false,
          supports_capability_query: false
        }.freeze,
        resilience_defaults: {}
      )

      # vLLM - full OpenAI compatibility
      VLLM = ServerType.new(
        name: :vllm,
        base_capabilities: {
          tools: true,
          json_object: true,
          json_schema: true,
          stop_array: true,
          tools_response_format_conflict: false,
          supports_capability_query: false
        }.freeze,
        resilience_defaults: {}
      )

      # Standard OpenAI API
      OPENAI = ServerType.new(
        name: :openai,
        base_capabilities: {
          tools: true,
          json_object: true,
          json_schema: true,
          stop_array: true,
          tools_response_format_conflict: false,
          supports_capability_query: false
        }.freeze,
        resilience_defaults: {}
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
    # (discovered through runtime errors or API probing). Capabilities can be
    # updated when we learn that a server doesn't support something we expected.
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
    # @example Check for tools/response_format conflict (llama.cpp)
    #   cap = ServerCapability.from_server_type(ServerType.lookup(:llama_cpp))
    #   cap.tools_response_format_conflict?  # => true (cannot use both)
    #
    # @example Build from LM Studio 0.4.0 probe result
    #   cap = ServerCapability.from_lm_studio_probe(model_caps, server_type)
    #   cap.supports_tools   # => true (from trained_for_tool_use)
    #   cap.supports_vision  # => true (from vision capability)
    #
    # @see ServerType For base capability definitions
    # @see Concerns::Resilience::LmStudioProbe For LM Studio 0.4.0 probing
    ServerCapability = Data.define(
      :server_type,
      :supports_tools,
      :supports_json_object,                # response_format: { type: "json_object" }
      :supports_json_schema,                # response_format: { type: "json_schema", json_schema: {...} }
      :supports_stop_array,
      :supports_vision,                     # Multimodal image input support
      :tools_response_format_conflict,      # Cannot use tools AND response_format together
      :supports_capability_query,           # /api/v1/models returns capability info
      :max_context_length,                  # Maximum context window (from probe)
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
          supports_vision: caps[:vision] || false,
          tools_response_format_conflict: caps[:tools_response_format_conflict] || false,
          supports_capability_query: caps[:supports_capability_query] || false,
          max_context_length: nil,
          max_tokens_limit: nil,
          detected_at: Time.now,
          confidence: :base
        )
      end

      # Build capability state from LM Studio 0.4.0+ probe result.
      #
      # @param model_caps [Concerns::Resilience::LmStudioProbe::ModelCapabilities] Probed capabilities
      # @param type [ServerType] Server type (usually LM_STUDIO)
      # @return [ServerCapability]
      def from_lm_studio_probe(model_caps, type = ServerTypes::LM_STUDIO)
        caps = type.base_capabilities
        new(
          server_type: type,
          supports_tools: model_caps.trained_for_tool_use || false,
          supports_json_object: caps[:json_object],
          supports_json_schema: caps[:json_schema],
          supports_stop_array: caps[:stop_array],
          supports_vision: model_caps.vision || false,
          tools_response_format_conflict: caps[:tools_response_format_conflict] || false,
          supports_capability_query: true,
          max_context_length: model_caps.max_context_length,
          max_tokens_limit: nil,
          detected_at: Time.now,
          confidence: :probed
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
    ServerCapability.define_method(:probed?) { confidence == :probed }

    # Convenience predicate for conflict check
    ServerCapability.define_method(:tools_response_format_conflict?) do
      tools_response_format_conflict == true
    end

    # Convenience predicate for vision support
    ServerCapability.define_method(:vision?) { supports_vision == true }
  end
end
