module Smolagents
  module Testing
    module ModelCapabilities
      # Inference methods for detecting model capabilities from name patterns.
      module Inference
        module_function

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
            specialization: infer_specialization(id, is_vlm),
            provider: :lm_studio, quantization: infer_quantization(id), architecture: infer_architecture(id)
          }
        end
      end
    end
  end
end
