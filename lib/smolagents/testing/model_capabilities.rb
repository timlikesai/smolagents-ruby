module Smolagents
  module Testing
    # Immutable description of a model's capabilities for testing.
    #
    # Captures multiple dimensions for analysis:
    # - Performance: speed, throughput
    # - Capability: tool_use, vision, reasoning depth
    # - Architecture: size, context length, quantization
    # - Identity: provider, model family
    #
    # @example Define a model's capabilities
    #   caps = ModelCapabilities.new(
    #     model_id: "gpt-oss-20b",
    #     context_length: 131_072,
    #     vision: false,
    #     tool_use: true,
    #     reasoning: :strong
    #   )
    #
    ModelCapabilities = Data.define(
      :model_id,
      :context_length,
      :vision,
      :tool_use,
      :reasoning,        # :minimal, :basic, :strong
      :speed,            # :fast, :medium, :slow
      :size_category,    # :tiny, :small, :medium, :large
      :specialization,   # :general, :code, :vision, :reasoning
      :provider,         # :lm_studio, :llama_cpp, :openai, :anthropic
      :quantization,     # :fp16, :int8, :int4, :unknown
      :param_count,      # estimated parameter count (e.g., 1.2e9)
      :architecture      # :transformer, :mamba, :hybrid, :unknown
    ) do
      # Create ModelCapabilities from LM Studio model info.
      #
      # Parses model metadata from LM Studio and infers capabilities:
      # - Speed (fast/medium/slow) from model name and context
      # - Size category (tiny/small/medium/large) from param count
      # - Specialization (general/code/vision) from model name
      # - Quantization (fp16/int8/int4/unknown) from metadata
      # - Parameter count estimate from model name patterns
      # - Architecture (transformer/mamba/liquid/rwkv/unknown)
      #
      # @param model_info [Hash] Model metadata from LM Studio API
      #   (must include "id", "type", "max_context_length")
      # @return [ModelCapabilities] Inferred capability description
      #
      # @example
      #   model_info = { "id" => "gpt-oss-20b", "type" => "llm", "max_context_length" => 4096 }
      #   caps = ModelCapabilities.from_lm_studio(model_info)
      #   puts "#{caps.model_id}: #{caps.architecture} (#{caps.size_category})"
      def self.from_lm_studio(model_info)
        id = model_info["id"]
        ctx = model_info["max_context_length"] || 4096
        is_vlm = model_info["type"] == "vlm"

        new(
          model_id: id,
          context_length: ctx,
          vision: is_vlm,
          tool_use: true, # All loaded models assumed tool-capable - tests will verify
          reasoning: :basic, # Let benchmark determine actual capability
          speed: infer_speed(id, ctx),
          size_category: infer_size(id),
          specialization: infer_specialization(id, is_vlm),
          provider: :lm_studio,
          quantization: infer_quantization(id),
          param_count: infer_param_count(id),
          architecture: infer_architecture(id)
        )
      end

      # Infer execution speed category from model name and context length.
      #
      # Classifies models as :fast, :medium, or :slow based on:
      # - Parameter count patterns (small models → fast)
      # - Model name keywords (350m, 1b, 30b, etc.)
      #
      # @param id [String] Model ID/name
      # @param _ctx [Integer] Context length (unused in current heuristics)
      # @return [Symbol] Speed category (:fast, :medium, or :slow)
      #
      # @example
      #   ModelCapabilities.infer_speed("lfm2.5-1.2b", 4096) # => :fast
      #   ModelCapabilities.infer_speed("gpt-oss-20b", 4096) # => :slow
      def self.infer_speed(id, _ctx)
        case id
        when /350m|micro|nano|tiny/i then :fast
        when /1\.2b|1b/i then :fast
        when /30b|20b/i then :slow
        else :medium
        end
      end

      # Infer model size category from parameter count patterns.
      #
      # Classifies models into size categories based on model name:
      # - :tiny (< 1B params)
      # - :small (1B-4B)
      # - :medium (5B-12B)
      # - :large (> 13B)
      #
      # @param id [String] Model ID/name containing size indicators
      # @return [Symbol] Size category (:tiny, :small, :medium, or :large)
      #
      # @example
      #   ModelCapabilities.infer_size("lfm2.5-1.2b") # => :small
      #   ModelCapabilities.infer_size("gpt-oss-20b") # => :large
      def self.infer_size(id)
        case id
        when /350m|micro|nano/i then :tiny
        when /1\.2b|1b|2b/i then :small
        when /3n|3b|4b/i then :small
        when /7b|8b/i then :medium
        else :large
        end
      end

      # Infer model specialization from name and type.
      #
      # Determines primary model focus:
      # - :vision (Vision Language Models)
      # - :code (Code-specialized models)
      # - :general (General-purpose)
      #
      # @param id [String] Model ID/name
      # @param is_vlm [Boolean] Whether model is marked as VLM in metadata
      # @return [Symbol] Specialization (:vision, :code, or :general)
      #
      # @example
      #   ModelCapabilities.infer_specialization("llava-13b", true)  # => :vision
      #   ModelCapabilities.infer_specialization("codellama-34b", false) # => :code
      def self.infer_specialization(id, is_vlm)
        return :vision if is_vlm
        return :code if /coder|code/i.match?(id)

        :general
      end

      # Infer quantization type from model name patterns.
      #
      # Detects quantization method used:
      # - :fp16 (16-bit float)
      # - :int8 (8-bit integer)
      # - :int4 (4-bit integer)
      # - :unknown (not detected)
      #
      # Assumes GGUF files are quantized (typically INT4).
      #
      # @param id [String] Model ID/name with quantization indicators
      # @return [Symbol] Quantization type (:fp16, :int8, :int4, or :unknown)
      #
      # @example
      #   ModelCapabilities.infer_quantization("model-fp16-GGUF") # => :fp16
      #   ModelCapabilities.infer_quantization("model-q4-ggml") # => :int4
      def self.infer_quantization(id)
        case id
        when /fp16|bf16/i then :fp16
        when /int8|q8|w8/i then :int8
        when /int4|q4|w4|iq4|mxfp4/i then :int4
        when /gguf|ggml/i then :int4 # Most GGUF are quantized
        else :unknown
        end
      end

      # Infer parameter count estimate from model name patterns.
      #
      # Extracts parameter count from common model name conventions:
      # - 350m → 3.5e8 (350 million)
      # - 1.2b → 1.2e9 (1.2 billion)
      # - 7b → 7.0e9 (7 billion)
      # - etc.
      #
      # @param id [String] Model ID/name containing param count indicator
      # @return [Float, nil] Estimated parameter count, or nil if not detected
      #
      # @example
      #   ModelCapabilities.infer_param_count("lfm2.5-1.2b") # => 1.2e9
      #   ModelCapabilities.infer_param_count("gpt-oss-20b") # => 2.0e10
      def self.infer_param_count(id)
        case id
        when /350m/i then 3.5e8
        when /1\.2b|1b/i then 1.2e9
        when /2b/i then 2.0e9
        when /3n/i then 4.0e9 # gemma-3n is ~4B params
        when /3b/i then 3.0e9
        when /7b/i then 7.0e9
        when /8b/i then 8.0e9
        when /13b/i then 1.3e10
        when /20b/i then 2.0e10
        when /30b/i then 3.0e10
        when /70b/i then 7.0e10
        end
      end

      # Infer model architecture from name patterns.
      #
      # Detects underlying architecture:
      # - :liquid (LiquidAI models)
      # - :mamba (Mamba architecture)
      # - :rwkv (RWKV/RNN architecture)
      # - :transformer (Standard transformer)
      # - :unknown (not detected)
      #
      # @param id [String] Model ID/name with architecture indicators
      # @return [Symbol] Architecture type (:liquid, :mamba, :rwkv, :transformer, or :unknown)
      #
      # @example
      #   ModelCapabilities.infer_architecture("lfm2.5-1.2b") # => :liquid
      #   ModelCapabilities.infer_architecture("llamacpp-7b") # => :transformer
      def self.infer_architecture(id)
        case id
        when /lfm|liquid/i then :liquid # LiquidAI's architecture
        when /mamba/i then :mamba
        when /rwkv/i then :rwkv
        when /gemma|llama|qwen|granite|gpt/i then :transformer
        else :unknown
        end
      end

      # Check if model supports vision/image processing.
      #
      # @return [Boolean] True if model is a Vision Language Model (VLM)
      def vision? = vision

      # Check if model can use tools.
      #
      # @return [Boolean] True if model supports tool calling
      def tool_use? = tool_use

      # Check if model execution is fast.
      #
      # @return [Boolean] True if speed category is :fast
      def fast? = speed == :fast

      # Check if model has large context window.
      #
      # @return [Boolean] True if context length >= 100,000 tokens
      def large_context? = context_length >= 100_000

      # Check if model can reason.
      #
      # @return [Boolean] True if reasoning level is not :minimal
      def can_reason? = reasoning != :minimal

      # Get recommended max steps for this model in benchmarks.
      #
      # Higher reasoning capability → more steps allowed to complete complex tasks.
      #
      # @return [Integer] Recommended maximum steps (4, 6, or 10)
      #
      # @example
      #   caps = ModelCapabilities.new(..., reasoning: :strong)
      #   caps.recommended_max_steps # => 10
      def recommended_max_steps
        case reasoning
        when :strong then 10
        when :basic then 6
        else 4
        end
      end

      # Get recommended timeout for this model in benchmarks.
      #
      # Faster models get shorter timeouts; slower models get more time.
      #
      # @return [Integer] Recommended timeout in seconds (30, 60, or 120)
      #
      # @example
      #   caps = ModelCapabilities.new(..., speed: :fast)
      #   caps.recommended_timeout # => 30
      def recommended_timeout
        case speed
        when :fast then 30
        when :medium then 60
        else 120
        end
      end

      # Convert to hash representation.
      #
      # @return [Hash] Hash with all capability fields
      def to_h
        {
          model_id:, context_length:, vision:, tool_use:,
          reasoning:, speed:, size_category:, specialization:, provider:,
          quantization:, param_count:, architecture:
        }
      end

      # Get human-readable parameter count string.
      #
      # Formats parameter count as:
      # - "X.XB" for billions of parameters
      # - "XXM" for millions of parameters
      # - "?" if param count unknown
      #
      # @return [String] Formatted parameter count (e.g., "7.0B", "350M", "?")
      #
      # @example
      #   caps = ModelCapabilities.new(..., param_count: 7.0e9)
      #   caps.param_count_str # => "7.0B"
      def param_count_str
        return "?" unless param_count

        if param_count >= 1e9
          "#{(param_count / 1e9).round(1)}B"
        else
          "#{(param_count / 1e6).round(0)}M"
        end
      end

      # Get header line for table display.
      #
      # @return [String] Formatted table header row
      #   (Model | Params | Context | Reason | V | T | Architecture)
      #
      # @example
      #   puts ModelCapabilities.header_line
      #   # => "Model                          | Params | Context | Reason   | V | T | Architecture"
      def self.header_line
        parts = ["Model".ljust(30)]
        parts << "Params".rjust(6)
        parts << "Context".rjust(8)
        parts << "Reason".ljust(8)
        parts << "V"
        parts << "T"
        parts << "Architecture".ljust(12)
        parts.join(" | ")
      end

      # Get summary line for table display.
      #
      # One-line representation of model capabilities suitable for formatted tables.
      # Flags: V=Vision, T=Tool-use
      #
      # @return [String] Formatted single-line summary row
      #
      # @example
      #   caps = ModelCapabilities.new(
      #     model_id: "gpt-oss-20b", param_count: 2.0e10,
      #     context_length: 4096, reasoning: :basic,
      #     vision: false, tool_use: true, architecture: :transformer
      #   )
      #   puts caps.summary_line
      #   # => "gpt-oss-20b                    |  20.0B |     4096 | basic    | - | T | transformer"
      def summary_line
        parts = [model_id.ljust(30)]
        parts << param_count_str.rjust(6)
        parts << context_length.to_s.rjust(8)
        parts << reasoning.to_s.ljust(8)
        parts << (vision? ? "V" : "-")
        parts << (tool_use? ? "T" : "-")
        parts << architecture.to_s.ljust(12)
        parts.join(" | ")
      end
    end

    # Registry of known models and their capabilities.
    #
    # Provides querying and filtering of available models.
    # Integrates with LM Studio to discover loaded models.
    #
    # @example Fetch capabilities from LM Studio
    #   registry = ModelRegistry.from_lm_studio("http://localhost:1234")
    #   registry.each { |caps| puts "#{caps.model_id}: #{caps.reasoning}" }
    #
    # @example Filter models
    #   fast_models = registry.select(&:fast?)
    #   vision_models = registry.select(&:vision?)
    #
    class ModelRegistry
      include Enumerable

      attr_reader :models

      def initialize(models = {})
        @models = models.freeze
      end

      # Create registry by discovering models from LM Studio.
      #
      # Fetches list of loaded models from LM Studio API and infers
      # their capabilities from metadata.
      #
      # @param base_url [String] LM Studio base URL (default: "http://localhost:1234")
      # @return [ModelRegistry] Registry with discovered models
      #
      # @example
      #   registry = ModelRegistry.from_lm_studio("http://localhost:1234")
      #   puts "Available models: #{registry.size}"
      #   puts registry.ids
      #
      # @example Handle errors gracefully
      #   registry = ModelRegistry.from_lm_studio("http://unreachable:1234")
      #   # Returns empty registry and warns on failure
      def self.from_lm_studio(base_url = "http://localhost:1234")
        require "net/http"
        require "json"

        uri = URI("#{base_url}/api/v0/models")
        response = Net::HTTP.get(uri)
        data = JSON.parse(response)

        models = data["data"]
                 .select { |m| m["state"] == "loaded" }
                 .to_h { |m| [m["id"], ModelCapabilities.from_lm_studio(m)] }

        new(models)
      rescue StandardError => e
        warn "Failed to fetch models from LM Studio: #{e.message}"
        new({})
      end

      # Get capabilities for a specific model by ID.
      #
      # @param model_id [String] Model ID to look up
      # @return [ModelCapabilities, nil] Model capabilities or nil if not found
      #
      # @example
      #   registry = ModelRegistry.from_lm_studio
      #   caps = registry["gpt-oss-20b"]
      #   puts caps.reasoning if caps
      def [](model_id) = @models[model_id]

      # Iterate over all model capabilities.
      #
      # @yield [ModelCapabilities] Each model's capabilities
      # @return [Enumerator, nil] Enumerator if block not given
      #
      # @example
      #   registry.each { |caps| puts caps.model_id }
      def each(&) = @models.values.each(&)

      # Get all model IDs in registry.
      #
      # @return [Array<String>] List of model IDs
      #
      # @example
      #   ids = registry.ids
      #   puts "Models: #{ids.join(', ')}"
      def ids = @models.keys

      # Get number of models in registry.
      #
      # @return [Integer] Number of models
      def size = @models.size

      # Check if registry is empty.
      #
      # @return [Boolean] True if no models registered
      def empty? = @models.empty?

      # Filter to models with tool-use capability.
      #
      # @return [ModelRegistry] New registry with only tool-capable models
      #
      # @example
      #   tool_models = registry.with_tool_use
      #   tool_models.each { |caps| puts caps.model_id }
      def with_tool_use = select(&:tool_use?)

      # Filter to models with vision/image capability.
      #
      # @return [ModelRegistry] New registry with only vision-capable models (VLMs)
      #
      # @example
      #   vlms = registry.with_vision
      #   puts "Vision models: #{vlms.size}"
      def with_vision = select(&:vision?)

      # Filter to fast execution models.
      #
      # @return [ModelRegistry] New registry with only fast models
      #
      # @example
      #   quick_models = registry.fast_models
      #   quick_models.each { |caps| puts caps.model_id }
      def fast_models = select(&:fast?)

      # Filter to models with specific reasoning capability.
      #
      # @param level [Symbol] Reasoning level (:minimal, :basic, :strong)
      # @return [ModelRegistry] New registry with matching reasoning capability
      #
      # @example
      #   strong_reasoners = registry.by_reasoning(:strong)
      #   puts "Strong reasoners: #{strong_reasoners.size}"
      def by_reasoning(level) = select { |m| m.reasoning == level }

      # Filter registry with custom predicate.
      #
      # @yield [ModelCapabilities] Model to test
      # @yieldreturn [Boolean] True to include model in result
      # @return [ModelRegistry] New registry with matching models
      #
      # @example
      #   large_models = registry.select { |m| m.param_count && m.param_count > 1e10 }
      def select
        self.class.new(@models.select { |_, v| yield(v) })
      end

      # Convert registry to hash representation.
      #
      # @return [Hash{String => Hash}] Hash mapping model IDs to their capability hashes
      #
      # @example
      #   data = registry.to_h
      #   json = JSON.generate(data)
      def to_h = @models.transform_values(&:to_h)
    end
  end
end
