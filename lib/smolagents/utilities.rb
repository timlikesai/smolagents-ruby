require_relative "utilities/prompts"
require_relative "utilities/pattern_matching"
require_relative "utilities/comparison"
require_relative "utilities/confidence"

module Smolagents
  # General-purpose utilities for agent systems.
  #
  # This module provides helper utilities that support agent operations including:
  # - Pattern matching for extracting code and JSON from LLM responses
  # - Answer comparison for evaluating agent outputs
  # - Confidence estimation for agent responses
  # - Prompt building utilities
  #
  # @example Extract code from LLM response
  #   code = Smolagents::Utilities::PatternMatching.extract_code(response)
  #   executor.run(code)
  #
  # @example Compare agent answers
  #   similarity = Smolagents::Utilities::Comparison.similarity(expected, actual)
  #   puts "Match: #{(similarity * 100).round}%"
  #
  # @example Estimate response confidence
  #   confidence = Smolagents::Utilities::Confidence.estimate(
  #     answer, steps_taken: 3, max_steps: 10
  #   )
  #   puts "Confidence: #{confidence.level}"
  #
  # @see Smolagents::Utilities::PatternMatching Response parsing
  # @see Smolagents::Utilities::Comparison Answer evaluation
  # @see Smolagents::Utilities::Confidence Response quality estimation
  # @see Smolagents::Utilities::Prompts Prompt building
  module Utilities
  end
end
