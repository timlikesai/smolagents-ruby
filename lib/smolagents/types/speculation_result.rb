module Smolagents
  module Types
    # Result of pre-flight speculation analysis for a tool call.
    #
    # Encapsulates feasibility determination, cost estimation, and
    # recommendations for how to proceed with a speculative tool call.
    #
    # @example Checking feasibility
    #   result = SpeculativeExecutor.analyze(prediction)
    #   if result.executable?
    #     execute(result.prediction)
    #   elsif result.should_delegate?
    #     delegate_to_primary(result.prediction)
    #   end
    #
    # @example Using factory methods
    #   # Tool is valid and ready
    #   SpeculationResult.executable(prediction: prediction, cost: 100)
    #
    #   # Low confidence but might work
    #   SpeculationResult.uncertain(prediction: prediction, reasons: ["Low confidence"])
    #
    #   # Cannot execute - unknown tool or missing args
    #   SpeculationResult.infeasible(prediction: prediction, reasons: ["Unknown tool"])
    #
    SpeculationResult = Data.define(
      :prediction,          # SpeculativeToolCall
      :feasibility,         # :executable, :uncertain, :infeasible
      :feasibility_reasons, # Array[String]
      :estimated_cost,      # Integer (tokens) or nil
      :confidence,          # Float from prediction
      :recommendations      # Array[Symbol] - [:execute, :validate, :delegate]
    ) do
      include TypeSupport::Deconstructable

      # Creates an executable result - tool call is ready to run.
      #
      # @param prediction [SpeculativeToolCall] The analyzed prediction
      # @param cost [Integer, nil] Estimated token cost
      # @return [SpeculationResult]
      def self.executable(prediction:, cost: nil)
        new(
          prediction:,
          feasibility: :executable,
          feasibility_reasons: [],
          estimated_cost: cost,
          confidence: prediction.confidence,
          recommendations: [:execute]
        )
      end

      # Creates an uncertain result - needs validation or may fail.
      #
      # @param prediction [SpeculativeToolCall] The analyzed prediction
      # @param reasons [Array<String>] Why this is uncertain
      # @param cost [Integer, nil] Estimated token cost
      # @return [SpeculationResult]
      def self.uncertain(prediction:, reasons:, cost: nil)
        new(
          prediction:,
          feasibility: :uncertain,
          feasibility_reasons: reasons,
          estimated_cost: cost,
          confidence: prediction.confidence,
          recommendations: %i[validate delegate]
        )
      end

      # Creates an infeasible result - cannot execute.
      #
      # @param prediction [SpeculativeToolCall] The analyzed prediction
      # @param reasons [Array<String>] Why this cannot be executed
      # @return [SpeculationResult]
      def self.infeasible(prediction:, reasons:)
        new(
          prediction:,
          feasibility: :infeasible,
          feasibility_reasons: reasons,
          estimated_cost: nil,
          confidence: prediction.confidence,
          recommendations: [:delegate]
        )
      end

      # Feasibility predicates
      def executable? = feasibility == :executable
      def uncertain? = feasibility == :uncertain
      def infeasible? = feasibility == :infeasible

      # Recommendation predicates
      def should_execute? = recommendations.include?(:execute)
      def should_validate? = recommendations.include?(:validate)
      def should_delegate? = recommendations.include?(:delegate)
    end
  end
end
