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
      def equivalent?(score, threshold: 0.7) = score >= threshold

      # Levenshtein edit distance between two strings.
      #
      # Returns the minimum number of single-character edits
      # (insertions, deletions, substitutions) to transform one string into another.
      #
      # @param str_a [String] First string
      # @param str_b [String] Second string
      # @return [Integer] Edit distance
      def levenshtein(str_a, str_b)
        a = str_a.to_s.downcase
        b = str_b.to_s.downcase
        return b.length if a.empty?
        return a.length if b.empty?
        return 0 if a == b

        levenshtein_compute(a, b)
      end

      # Wagner-Fischer algorithm with two-row optimization.
      # @api private
      def levenshtein_compute(str_a, str_b)
        prev_row = (0..str_b.length).to_a
        str_a.each_char.with_index(1) do |char_a, idx|
          prev_row = levenshtein_row(char_a, str_b, prev_row, idx)
        end
        prev_row.last
      end

      # Compute single row of Levenshtein matrix.
      # @api private
      def levenshtein_row(char_a, str_b, prev_row, row_idx)
        curr_row = [row_idx]
        str_b.each_char.with_index(1) do |char_b, col_idx|
          cost = char_a == char_b ? 0 : 1
          curr_row << [curr_row[col_idx - 1] + 1, prev_row[col_idx] + 1, prev_row[col_idx - 1] + cost].min
        end
        curr_row
      end

      # Find closest matches for a string from a list of candidates.
      #
      # @param target [String] String to find matches for
      # @param candidates [Array<String>] Possible matches
      # @param max_distance [Integer] Maximum edit distance to consider (default: 3)
      # @param limit [Integer] Maximum number of suggestions (default: 3)
      # @return [Array<String>] Closest matches, sorted by distance
      def did_you_mean(target, candidates, max_distance: 3, limit: 3)
        candidates
          .map { |c| [c, levenshtein(target, c)] }
          .select { |_, d| d <= max_distance }
          .sort_by(&:last)
          .take(limit)
          .map(&:first)
      end
    end
  end
end
