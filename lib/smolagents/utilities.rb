require_relative "utilities/prompts"
require_relative "utilities/pattern_matching"
require_relative "utilities/similarity"
require_relative "utilities/comparison"
require_relative "utilities/confidence"
require_relative "utilities/transform"

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
  #   response = "Here is the code:\n```ruby\nputs 'hello'\n```"
  #   Smolagents::Utilities::PatternMatching.extract_code(response)  #=> "puts 'hello'"
  #
  # @example Compare agent answers
  #   Smolagents::Utilities::Comparison.similarity("Ruby 4.0", "Ruby version 4.0") > 0.5  #=> true
  #
  # @example Estimate response confidence
  #   Smolagents::Utilities::Confidence.estimate("The answer is 42.", steps_taken: 2, max_steps: 10) > 0  #=> true
  #
  # @see Smolagents::Utilities::PatternMatching Response parsing
  # @see Smolagents::Utilities::Comparison Answer evaluation
  # @see Smolagents::Utilities::Confidence Response quality estimation
  # @see Smolagents::Utilities::Prompts Prompt building
  module Utilities
  end
end
