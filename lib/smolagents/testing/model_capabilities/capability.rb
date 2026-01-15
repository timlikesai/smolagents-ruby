require_relative "inference"
require_relative "formatters"

module Smolagents
  module Testing
    module ModelCapabilities
      # Immutable description of a model's capabilities for testing.
      #
      # Captures multiple dimensions:
      # - Performance: speed, throughput
      # - Capability: tool_use, vision, reasoning depth
      # - Architecture: size, context length, quantization
      # - Identity: provider, model family
      #
      # @example
      #   caps = Capability.new(
      #     model_id: "gpt-oss-20b",
      #     context_length: 131_072,
      #     vision: false,
      #     tool_use: true,
      #     reasoning: :strong
      #   )
      Capability = Data.define(
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
        include Formatters::InstanceMethods

        # Create Capability from LM Studio model info.
        # @param model_info [Hash] Model metadata from LM Studio API
        # @return [Capability] Inferred capability description
        def self.from_lm_studio(model_info)
          id = model_info["id"]
          ctx = model_info["max_context_length"] || 4096
          is_vlm = model_info["type"] == "vlm"
          new(**Inference.lm_studio_attrs(id, ctx, is_vlm))
        end

        # @return [Boolean] True if model supports vision
        def vision? = vision

        # @return [Boolean] True if model supports tool calling
        def tool_use? = tool_use

        # @return [Boolean] True if speed is :fast
        def fast? = speed == :fast

        # @return [Boolean] True if context >= 100k tokens
        def large_context? = context_length >= 100_000

        # @return [Boolean] True if reasoning is not :minimal
        def can_reason? = reasoning != :minimal

        # Recommended max steps for benchmarks.
        # @return [Integer] 4, 6, or 10 based on reasoning level
        def recommended_max_steps
          case reasoning
          when :strong then 10
          when :basic then 6
          else 4
          end
        end

        # Recommended timeout for benchmarks.
        # @return [Integer] 30, 60, or 120 seconds based on speed
        def recommended_timeout
          case speed
          when :fast then 30
          when :medium then 60
          else 120
          end
        end

        # @return [Hash] All capability fields as hash
        def to_h
          {
            model_id:, context_length:, vision:, tool_use:,
            reasoning:, speed:, size_category:, specialization:, provider:,
            quantization:, param_count:, architecture:
          }
        end
      end
    end
  end
end
