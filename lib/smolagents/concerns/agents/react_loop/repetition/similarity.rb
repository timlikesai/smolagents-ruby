module Smolagents
  module Concerns
    module ReActLoop
      module Repetition
        # Trigram-based string similarity for repetition detection.
        #
        # Delegates to Utilities::Similarity for core calculations.
        #
        # @example Calculate similarity
        #   similarity = string_similarity("hello world", "hello world!")
        #   # => 0.91 (high similarity)
        module Similarity
          def self.provided_methods
            {
              string_similarity: "Calculate Jaccard similarity between two strings using trigrams",
              trigrams: "Extract character trigrams from a string as a Set"
            }
          end

          private

          def string_similarity(first, second) = Utilities::Similarity.string(first, second)

          def trigrams(str) = Utilities::Similarity.trigrams(str)
        end
      end
    end
  end
end
