module Smolagents
  module Types
    # Immutable wrapper for a tool call with confidence and source metadata.
    #
    # Used by fast dispatcher models (FunctionGemma) where predictions are
    # speculative and may need validation by a primary model. Confidence
    # scores enable routing decisions and fallback logic.
    #
    # @!attribute [r] tool_call
    #   @return [ToolCall] The underlying tool call
    # @!attribute [r] confidence
    #   @return [Float] Confidence score 0.0-1.0
    # @!attribute [r] source
    #   @return [Symbol] Source model (:function_gemma, :primary, etc.)
    # @!attribute [r] speculative
    #   @return [Boolean] Whether this call needs validation
    #
    # @example Creating a speculative call from FunctionGemma
    #   call = SpeculativeToolCall.new(
    #     tool_call: ToolCall.new(name: "search", arguments: {}, id: "fg_1"),
    #     confidence: 0.85,
    #     source: :function_gemma,
    #     speculative: true
    #   )
    #   call.high_confidence?  # => true (above threshold)
    #   call.needs_validation? # => true (speculative)
    #
    SpeculativeToolCall = Data.define(:tool_call, :confidence, :source, :speculative) do
      include TypeSupport::Deconstructable

      # Default confidence threshold for "high confidence" decisions.
      HIGH_CONFIDENCE_THRESHOLD = 0.8

      # Default confidence threshold for "low confidence" (needs fallback).
      LOW_CONFIDENCE_THRESHOLD = 0.5

      # Creates a speculative call from FunctionGemma output.
      #
      # @param tool_call [ToolCall] Parsed tool call
      # @param confidence [Float] Model confidence (default 0.7)
      # @return [SpeculativeToolCall]
      def self.from_function_gemma(tool_call, confidence: 0.7)
        new(tool_call:, confidence:, source: :function_gemma, speculative: true)
      end

      # Creates a validated (non-speculative) call from primary model.
      #
      # @param tool_call [ToolCall] Primary model's tool call
      # @return [SpeculativeToolCall]
      def self.from_primary(tool_call)
        new(tool_call:, confidence: 1.0, source: :primary, speculative: false)
      end

      # Returns true if confidence exceeds high threshold.
      def high_confidence? = confidence >= HIGH_CONFIDENCE_THRESHOLD

      # Returns true if confidence is below low threshold.
      def low_confidence? = confidence < LOW_CONFIDENCE_THRESHOLD

      # Returns true if this call should be validated by primary model.
      def needs_validation? = speculative && !high_confidence?

      # Returns true if safe to execute without validation.
      def executable? = !speculative || high_confidence?

      # Delegates name to underlying tool_call.
      def name = tool_call.name

      # Delegates arguments to underlying tool_call.
      def arguments = tool_call.arguments

      # Delegates id to underlying tool_call.
      def id = tool_call.id

      # Converts to hash including metadata.
      def to_h
        {
          tool_call: tool_call.to_h,
          confidence:,
          source:,
          speculative:
        }
      end

      # Returns a validated copy (no longer speculative).
      def validate
        with(speculative: false, confidence: [confidence, 0.9].max)
      end
    end
  end
end
