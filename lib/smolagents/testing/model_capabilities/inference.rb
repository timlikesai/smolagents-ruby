module Smolagents
  module Testing
    module ModelCapabilities
      # Parameter count lookup table for model name inference
      PARAM_COUNT_PATTERNS = [
        [/350m/i, 3.5e8], [/1\.2b|1b/i, 1.2e9], [/2b/i, 2.0e9], [/3n/i, 4.0e9],
        [/3b/i, 3.0e9], [/7b/i, 7.0e9], [/8b/i, 8.0e9], [/13b/i, 1.3e10],
        [/20b/i, 2.0e10], [/30b/i, 3.0e10], [/70b/i, 7.0e10]
      ].freeze

      # Inference methods for detecting model capabilities from name patterns.
      module Inference
        module_function

        # Infer execution speed category from model name.
        # @param id [String] Model ID/name
        # @return [Symbol] :fast, :medium, or :slow
        def infer_speed(id)
          case id
          when /350m|micro|nano|tiny|1\.2b|1b/i then :fast
          when /30b|20b/i then :slow
          else :medium
          end
        end

        # Infer model size category from parameter count patterns.
        # @param id [String] Model ID/name
        # @return [Symbol] :tiny, :small, :medium, or :large
        def infer_size(id)
          case id
          when /350m|micro|nano/i then :tiny
          when /1\.2b|1b|2b|3n|3b|4b/i then :small
          when /7b|8b/i then :medium
          else :large
          end
        end

        # Infer model specialization from name and type.
        # @param id [String] Model ID/name
        # @param is_vlm [Boolean] Whether model is a VLM
        # @return [Symbol] :vision, :code, or :general
        def infer_specialization(id, is_vlm)
          return :vision if is_vlm
          return :code if /coder|code/i.match?(id)

          :general
        end

        # Infer quantization type from model name patterns.
        # @param id [String] Model ID/name
        # @return [Symbol] :fp16, :int8, :int4, or :unknown
        def infer_quantization(id)
          case id
          when /fp16|bf16/i then :fp16
          when /int8|q8|w8/i then :int8
          when /int4|q4|w4|iq4|mxfp4|gguf|ggml/i then :int4
          else :unknown
          end
        end

        # Infer parameter count from model name patterns.
        # @param id [String] Model ID/name
        # @return [Float, nil] Estimated parameter count or nil
        def infer_param_count(id)
          PARAM_COUNT_PATTERNS.find { |pattern, _| id.match?(pattern) }&.last
        end

        # Infer model architecture from name patterns.
        # @param id [String] Model ID/name
        # @return [Symbol] :liquid, :mamba, :rwkv, :transformer, or :unknown
        def infer_architecture(id)
          case id
          when /lfm|liquid/i then :liquid
          when /mamba/i then :mamba
          when /rwkv/i then :rwkv
          when /gemma|llama|qwen|granite|gpt/i then :transformer
          else :unknown
          end
        end

        # Build attributes hash from LM Studio model info.
        # @param id [String] Model ID
        # @param ctx [Integer] Context length
        # @param is_vlm [Boolean] Whether model is a VLM
        # @return [Hash] Attributes for Capability.new
        def lm_studio_attrs(id, ctx, is_vlm)
          {
            model_id: id, context_length: ctx, vision: is_vlm, tool_use: true, reasoning: :basic,
            speed: infer_speed(id), size_category: infer_size(id), specialization: infer_specialization(id, is_vlm),
            provider: :lm_studio, quantization: infer_quantization(id), param_count: infer_param_count(id),
            architecture: infer_architecture(id)
          }
        end
      end
    end
  end
end
