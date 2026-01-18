require_relative "comparison/entity_extraction"
require_relative "comparison/similarity"
require_relative "comparison/normalization"
require_relative "comparison/key_answer"
require_relative "comparison/grouping"

module Smolagents
  module Utilities
    # Answer comparison and similarity utilities for evaluating agent outputs.
    #
    # Provides methods for extracting entities from text, computing similarity scores,
    # and grouping similar answers. Useful for evaluation harnesses and testing.
    #
    # @example Compare two answers for similarity
    #   similarity = Comparison.similarity(expected_answer, agent_output)
    #   puts "#{(similarity * 100).round}% match"
    #
    # @example Check equivalence with threshold
    #   if Comparison.equivalent?(expected, actual, threshold: 0.8)
    #     puts "Answers match!"
    #   end
    #
    # @example Extract key entities from text
    #   entities = Comparison.extract_entities("Ruby 3.2 was released on Dec 25, 2022")
    #   # => #<Set: {"ruby 3.2", "dec 25, 2022"}>
    #
    # @example Group similar answers for consensus
    #   answers = ["Ruby is great", "Ruby is awesome", "Python is good"]
    #   groups = Comparison.group_similar(answers)
    #   # => [["Ruby is great", "Ruby is awesome"], ["Python is good"]]
    #
    module Comparison
      # Legacy pattern constants for backwards compatibility
      NUMBERS = EntityExtraction::PATTERNS[:numbers]
      QUOTED_DOUBLE = EntityExtraction::PATTERNS[:quoted_double]
      QUOTED_SINGLE = EntityExtraction::PATTERNS[:quoted_single]
      PROPER_NOUNS = EntityExtraction::PATTERNS[:proper_nouns]
      URLS = EntityExtraction::PATTERNS[:urls]
      EMAILS = EntityExtraction::PATTERNS[:emails]
      TECHNICAL = EntityExtraction::PATTERNS[:technical]

      class << self
        # Delegates to EntityExtraction.extract
        def extract_entities(text) = EntityExtraction.extract(text)

        # Delegates to Similarity.score
        def similarity(text_a, text_b) = Similarity.score(text_a, text_b)

        # Delegates to Similarity.equivalent?
        def equivalent?(text_a, text_b, threshold: Similarity::DEFAULT_THRESHOLD)
          Similarity.equivalent?(text_a, text_b, threshold:)
        end

        # Delegates to Normalization.normalize
        def normalize(text) = Normalization.normalize(text)

        # Delegates to KeyAnswer.extract
        def extract_key_answer(text) = KeyAnswer.extract(text)

        # Delegates to Grouping.group
        def group_similar(answers, threshold: Similarity::DEFAULT_THRESHOLD)
          Grouping.group(answers, threshold:)
        end
      end
    end
  end
end
