# frozen_string_literal: true

module Smolagents
  module Models
    module FunctionGemma
      # Scores FunctionGemma tool calls based on semantic and syntactic validity.
      #
      # LLMs use token feature activation vectors to understand meaning in context.
      # They're excellent at semantic intent but may make syntax errors. This scorer:
      # - Validates semantic intent (does the tool exist? do args make sense?)
      # - Checks syntactic correctness (required args present? types valid?)
      # - Produces a confidence score for routing decisions
      #
      # @example Scoring a parsed call
      #   tools = { "search" => SearchTool.new }
      #   scorer = ConfidenceScorer.new(tools)
      #   score = scorer.score(speculative_call)
      #   score.confidence      # => 0.85
      #   score.valid_tool?     # => true
      #   score.missing_args    # => []
      #
      module ConfidenceScorer
        # Result of scoring a speculative tool call.
        ScoreResult = Data.define(
          :base_confidence,
          :tool_exists,
          :required_args_present,
          :unknown_args,
          :missing_args,
          :type_mismatches
        ) do
          # Final confidence after all adjustments.
          # Boosts for valid tool+args, penalizes for issues.
          def confidence
            score = base_confidence

            # Boost for valid semantics (tool exists, args valid)
            if tool_exists && missing_args.empty? && type_mismatches.empty?
              score += 0.15 # Reward valid tool selection
            end

            # Penalties for issues
            score -= 0.4 unless tool_exists
            score -= 0.15 * missing_args.size
            score -= 0.05 * unknown_args.size
            score -= 0.1 * type_mismatches.size
            score.clamp(0.0, 1.0)
          end

          def valid_tool? = tool_exists
          def args_valid? = missing_args.empty? && type_mismatches.empty?
          def high_confidence? = confidence >= 0.8
          def executable? = tool_exists && confidence >= 0.5
        end

        class << self
          # Scores a speculative tool call against known tools.
          #
          # @param call [SpeculativeToolCall] The call to score
          # @param tools [Hash<String, Tool>] Available tools by name
          # @return [ScoreResult] Detailed scoring result
          def score(call, tools)
            tool = tools[call.name]
            return no_tool_result(call) unless tool

            schema = tool.class.inputs || {}
            required = schema.select { |_, v| v[:required] != false }.keys.map(&:to_s)
            provided = call.arguments.keys.map(&:to_s)

            ScoreResult.new(
              base_confidence: call.confidence,
              tool_exists: true,
              required_args_present: (required - provided).empty?,
              unknown_args: provided - schema.keys.map(&:to_s),
              missing_args: required - provided,
              type_mismatches: find_type_mismatches(call.arguments, schema)
            )
          end

          # Adjusts a SpeculativeToolCall's confidence based on scoring.
          #
          # @param call [SpeculativeToolCall] The call to rescore
          # @param tools [Hash<String, Tool>] Available tools
          # @return [SpeculativeToolCall] New call with adjusted confidence
          def rescore(call, tools)
            result = score(call, tools)
            call.with(confidence: result.confidence)
          end

          private

          def no_tool_result(call)
            ScoreResult.new(
              base_confidence: call.confidence,
              tool_exists: false,
              required_args_present: false,
              unknown_args: call.arguments.keys.map(&:to_s),
              missing_args: [],
              type_mismatches: []
            )
          end

          def find_type_mismatches(arguments, schema)
            mismatches = []
            arguments.each do |key, value|
              expected_type = schema.dig(key.to_sym, :type)
              next unless expected_type

              mismatches << key unless type_compatible?(value, expected_type)
            end
            mismatches
          end

          def type_compatible?(value, expected_type)
            case expected_type
            when "integer" then value.to_s.match?(/\A-?\d+\z/)
            when "number" then value.to_s.match?(/\A-?\d+\.?\d*\z/)
            when "boolean" then %w[true false].include?(value.to_s.downcase)
            when "array" then value.is_a?(Array) || value.start_with?("[")
            when "object" then value.is_a?(Hash) || value.start_with?("{")
            else true # string and unknown types accept any value
            end
          end
        end
      end
    end
  end
end
