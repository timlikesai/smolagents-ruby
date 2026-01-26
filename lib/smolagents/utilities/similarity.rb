module Smolagents
  module Utilities
    # Unified similarity calculations using Jaccard index.
    #
    # Provides composable similarity methods for different input types:
    # - Sets (raw Jaccard)
    # - Strings (trigram-based)
    # - Terms (word-based with stop word filtering)
    #
    # All methods return Float between 0.0 and 1.0.
    #
    # @example Set similarity
    #   Similarity.jaccard(Set["a", "b"], Set["b", "c"]) # => 0.333
    #
    # @example String similarity
    #   Similarity.string("hello world", "hello world!") # => 0.91
    module Similarity
      module_function

      # Core Jaccard index: |intersection| / |union|
      #
      # @param set_a [Set, Array] First set
      # @param set_b [Set, Array] Second set
      # @return [Float] Similarity score (0.0-1.0)
      def jaccard(set_a, set_b)
        a = set_a.to_set
        b = set_b.to_set
        union = a | b
        return 1.0 if union.empty?

        (a & b).size.to_f / union.size
      end

      # Trigram-based string similarity.
      #
      # Uses Jaccard similarity on character trigrams for fuzzy matching.
      # Returns 0.0 if either string is too short for trigrams (<3 chars).
      #
      # @param first [String] First string
      # @param second [String] Second string
      # @return [Float] Similarity score (0.0-1.0)
      def string(first, second)
        return 1.0 if first == second
        return 0.0 if first.to_s.empty? || second.to_s.empty?

        trig_a = trigrams(first)
        trig_b = trigrams(second)
        return 0.0 if trig_a.empty? || trig_b.empty?

        jaccard(trig_a, trig_b)
      end

      # Extract character trigrams from a string.
      #
      # @param str [String] Input string
      # @param size [Integer] N-gram size (default: 3)
      # @return [Set<String>] Set of n-character substrings
      def trigrams(str, size: 3)
        s = str.to_s
        return Set.new if s.length < size

        Set.new((0..(s.length - size)).map { |i| s[i, size] })
      end

      # Term-based similarity for natural language.
      #
      # Extracts lowercase words, filters short terms, computes Jaccard.
      #
      # @param text_a [String] First text
      # @param text_b [String] Second text
      # @param min_length [Integer] Minimum word length (default: 3)
      # @return [Float] Similarity score (0.0-1.0)
      def terms(text_a, text_b, min_length: 3)
        a = extract_terms(text_a, min_length:)
        b = extract_terms(text_b, min_length:)
        return 1.0 if a.empty? && b.empty?

        jaccard(a, b)
      end

      # Extract terms from text.
      #
      # @param text [String] Input text
      # @param min_length [Integer] Minimum word length
      # @return [Set<String>] Set of lowercase terms
      def extract_terms(text, min_length: 3)
        text.to_s.downcase.scan(/\w+/).select { |w| w.length >= min_length }.to_set
      end

      # Check if two items are equivalent above threshold.
      #
      # @param score [Float] Similarity score
      # @param threshold [Float] Minimum similarity (default: 0.7)
      # @return [Boolean]
      def equivalent?(score, threshold: 0.7)
        score >= threshold
      end
    end
  end
end
