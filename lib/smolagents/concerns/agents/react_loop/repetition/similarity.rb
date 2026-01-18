module Smolagents
  module Concerns
    module ReActLoop
      module Repetition
        # Trigram-based string similarity calculation for repetition detection.
        #
        # Provides fuzzy matching between strings using character trigrams.
        # This enables detection of "nearly identical" observations that may
        # differ only in punctuation or minor variations.
        #
        # @example Calculate similarity
        #   similarity = string_similarity("hello world", "hello world!")
        #   # => 0.91 (high similarity)
        module Similarity
          # === Self-Documentation ===
          def self.provided_methods
            {
              string_similarity: "Calculate Jaccard similarity between two strings using trigrams",
              trigrams: "Extract character trigrams from a string as a Set"
            }
          end

          private

          # Calculate trigram-based similarity between two strings.
          #
          # Uses Jaccard similarity: |intersection| / |union| of trigram sets.
          #
          # @param first [String] First string to compare
          # @param second [String] Second string to compare
          # @return [Float] Similarity score between 0.0 and 1.0
          def string_similarity(first, second)
            return 1.0 if first == second
            return 0.0 if first.empty? || second.empty?

            trigrams_first = trigrams(first)
            trigrams_second = trigrams(second)
            union_size = (trigrams_first | trigrams_second).size
            return 0.0 if union_size.zero? # Both strings too short for trigrams

            (trigrams_first & trigrams_second).size.to_f / union_size
          end

          # Extract character trigrams from a string.
          #
          # @param str [String] Input string
          # @return [Set<String>] Set of 3-character substrings
          def trigrams(str)
            return Set.new if str.length < 3

            Set.new((0..(str.length - 3)).map { |i| str[i, 3] })
          end
        end
      end
    end
  end
end
