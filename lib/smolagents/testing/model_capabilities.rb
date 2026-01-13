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

      def self.infer_speed(id, _ctx)
        case id
        when /350m|micro|nano|tiny/i then :fast
        when /1\.2b|1b/i then :fast
        when /30b|20b/i then :slow
        else :medium
        end
      end

      def self.infer_size(id)
        case id
        when /350m|micro|nano/i then :tiny
        when /1\.2b|1b|2b/i then :small
        when /3n|3b|4b/i then :small
        when /7b|8b/i then :medium
        else :large
        end
      end

      def self.infer_specialization(id, is_vlm)
        return :vision if is_vlm
        return :code if /coder|code/i.match?(id)

        :general
      end

      def self.infer_quantization(id)
        case id
        when /fp16|bf16/i then :fp16
        when /int8|q8|w8/i then :int8
        when /int4|q4|w4|iq4|mxfp4/i then :int4
        when /gguf|ggml/i then :int4 # Most GGUF are quantized
        else :unknown
        end
      end

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

      def self.infer_architecture(id)
        case id
        when /lfm|liquid/i then :liquid # LiquidAI's architecture
        when /mamba/i then :mamba
        when /rwkv/i then :rwkv
        when /gemma|llama|qwen|granite|gpt/i then :transformer
        else :unknown
        end
      end

      # Capability predicates
      def vision? = vision
      def tool_use? = tool_use
      def fast? = speed == :fast
      def large_context? = context_length >= 100_000
      def can_reason? = reasoning != :minimal

      # Test level recommendations
      def recommended_max_steps
        case reasoning
        when :strong then 10
        when :basic then 6
        else 4
        end
      end

      def recommended_timeout
        case speed
        when :fast then 30
        when :medium then 60
        else 120
        end
      end

      def to_h
        {
          model_id:, context_length:, vision:, tool_use:,
          reasoning:, speed:, size_category:, specialization:, provider:,
          quantization:, param_count:, architecture:
        }
      end

      # Human-readable parameter count
      def param_count_str
        return "?" unless param_count

        if param_count >= 1e9
          "#{(param_count / 1e9).round(1)}B"
        else
          "#{(param_count / 1e6).round(0)}M"
        end
      end

      # Header line for table display
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

      # Summary line for display
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

      def [](model_id) = @models[model_id]
      def each(&) = @models.values.each(&)
      def ids = @models.keys
      def size = @models.size
      def empty? = @models.empty?

      def with_tool_use = select(&:tool_use?)
      def with_vision = select(&:vision?)
      def fast_models = select(&:fast?)
      def by_reasoning(level) = select { |m| m.reasoning == level }

      def select
        self.class.new(@models.select { |_, v| yield(v) })
      end

      def to_h = @models.transform_values(&:to_h)
    end
  end
end
